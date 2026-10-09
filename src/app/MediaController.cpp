#include "MediaController.h"

#include <QFileInfo>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QVector>
#include <QStringList>
#include <QRegularExpression>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

namespace {
QString number(double value)
{
    return QString::number(value, 'f', 6).remove(QRegularExpression(QStringLiteral("0+$")))
        .remove(QRegularExpression(QStringLiteral("\\.$")));
}

double clipNumber(const QVariantMap &clip, const QString &key, double fallback = 0.0)
{
    bool ok = false;
    const double value = clip.value(key).toDouble(&ok);
    return ok && std::isfinite(value) ? value : fallback;
}

QString ffmpegExecutable()
{
    return QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
}

QString ffprobeExecutable()
{
    return QStandardPaths::findExecutable(QStringLiteral("ffprobe"));
}
}

MediaController::MediaController(QObject *parent)
    : QObject(parent)
{
    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &MediaController::handleStandardOutput);
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        m_errorOutput += QString::fromUtf8(m_process->readAllStandardError());
        if (m_errorOutput.size() > 24000)
            m_errorOutput = m_errorOutput.right(24000);
    });
    connect(m_process,
            qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, &MediaController::finishExport);
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (!m_exporting || error != QProcess::FailedToStart)
            return;
        m_exporting = false;
        emit exportingChanged();
        const QString message = QStringLiteral("Could not start FFmpeg. Install FFmpeg or check the AppImage bundle.");
        emit errorOccurred(message);
        emit exportFinished(false, message);
    });
}

bool MediaController::exporting() const
{
    return m_exporting;
}

int MediaController::exportProgress() const
{
    return m_exportProgress;
}

QUrl MediaController::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path);
}

QVariantMap MediaController::probeMedia(const QString &path) const
{
    const QFileInfo fileInfo(path);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return {{QStringLiteral("error"), QStringLiteral("File does not exist.")}};
    }

    const QString executable = ffprobeExecutable();
    if (executable.isEmpty()) {
        return {{QStringLiteral("error"), QStringLiteral("FFprobe was not found. Install FFmpeg.")}};
    }

    QProcess process;
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start(executable, {
        QStringLiteral("-v"), QStringLiteral("error"),
        QStringLiteral("-show_entries"),
        QStringLiteral("format=duration:stream=codec_type,width,height,avg_frame_rate"),
        QStringLiteral("-of"), QStringLiteral("json"),
        fileInfo.absoluteFilePath()
    });

    if (!process.waitForStarted(3000) || !process.waitForFinished(12000)) {
        process.kill();
        process.waitForFinished(1000);
        return {{QStringLiteral("error"), QStringLiteral("Timed out while reading media information.")}};
    }

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        const QString error = QString::fromUtf8(process.readAllStandardError()).trimmed();
        return {{QStringLiteral("error"),
                 error.isEmpty() ? QStringLiteral("FFprobe could not read this media file.") : error}};
    }

    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(process.readAllStandardOutput(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        return {{QStringLiteral("error"), QStringLiteral("FFprobe returned invalid metadata.")}};
    }

    bool hasVideo = false;
    bool hasAudio = false;
    int width = 0;
    int height = 0;
    const QJsonArray streams = document.object().value(QStringLiteral("streams")).toArray();
    for (const QJsonValue &value : streams) {
        const QJsonObject stream = value.toObject();
        const QString codecType = stream.value(QStringLiteral("codec_type")).toString();
        if (codecType == QStringLiteral("video")) {
            hasVideo = true;
            width = qMax(width, stream.value(QStringLiteral("width")).toInt());
            height = qMax(height, stream.value(QStringLiteral("height")).toInt());
        } else if (codecType == QStringLiteral("audio")) {
            hasAudio = true;
        }
    }

    const QString suffix = fileInfo.suffix().toLower();
    const QStringList imageExtensions = {
        QStringLiteral("png"), QStringLiteral("jpg"), QStringLiteral("jpeg"),
        QStringLiteral("webp"), QStringLiteral("bmp"), QStringLiteral("gif"),
        QStringLiteral("tif"), QStringLiteral("tiff")
    };

    QString kind;
    if (imageExtensions.contains(suffix))
        kind = QStringLiteral("image");
    else if (hasVideo)
        kind = QStringLiteral("video");
    else if (hasAudio)
        kind = QStringLiteral("audio");
    else
        return {{QStringLiteral("error"), QStringLiteral("This file does not contain supported video, audio, or image media.")}};

    double duration = document.object().value(QStringLiteral("format"))
                          .toObject().value(QStringLiteral("duration")).toVariant().toDouble();
    if (!std::isfinite(duration) || duration < 0.0)
        duration = 0.0;
    if (kind == QStringLiteral("image") && duration < 0.1)
        duration = 3.0;

    return {
        {QStringLiteral("path"), fileInfo.absoluteFilePath()},
        {QStringLiteral("name"), fileInfo.fileName()},
        {QStringLiteral("kind"), kind},
        {QStringLiteral("duration"), duration},
        {QStringLiteral("width"), width},
        {QStringLiteral("height"), height},
        {QStringLiteral("hasVideo"), hasVideo},
        {QStringLiteral("hasAudio"), hasAudio},
        {QStringLiteral("size"), fileInfo.size()}
    };
}

bool MediaController::exportTimeline(const QVariantList &visualClips,
                                     const QVariantList &audioClips,
                                     const QString &requestedOutputPath,
                                     int width,
                                     int height,
                                     int fps)
{
    if (m_exporting) {
        emit errorOccurred(QStringLiteral("An export is already running."));
        return false;
    }
    if (visualClips.isEmpty()) {
        emit errorOccurred(QStringLiteral("Add at least one video or image clip before exporting."));
        return false;
    }

    const QString executable = ffmpegExecutable();
    if (executable.isEmpty()) {
        emit errorOccurred(QStringLiteral("FFmpeg was not found. Install FFmpeg or use the bundled AppImage."));
        return false;
    }

    QString outputPath = requestedOutputPath.trimmed();
    if (outputPath.isEmpty()) {
        emit errorOccurred(QStringLiteral("Choose an output file first."));
        return false;
    }
    if (!outputPath.toLower().endsWith(QStringLiteral(".mp4")))
        outputPath += QStringLiteral(".mp4");

    const QFileInfo outputInfo(outputPath);
    if (!QDir().mkpath(outputInfo.absolutePath())) {
        emit errorOccurred(QStringLiteral("Could not create the output folder."));
        return false;
    }

    width = qBound(160, width, 3840);
    height = qBound(90, height, 2160);
    fps = qBound(12, fps, 120);

    QStringList args = {
        QStringLiteral("-hide_banner"),
        QStringLiteral("-y"),
        QStringLiteral("-loglevel"), QStringLiteral("error"),
        QStringLiteral("-progress"), QStringLiteral("pipe:1"),
        QStringLiteral("-nostats")
    };

    QVector<QVariantMap> visuals;
    visuals.reserve(visualClips.size());
    m_timelineDuration = 0.0;

    for (const QVariant &value : visualClips) {
        QVariantMap clip = value.toMap();
        const QString path = clip.value(QStringLiteral("path")).toString();
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile()) {
            emit errorOccurred(QStringLiteral("A timeline source is missing: %1").arg(path));
            return false;
        }

        const double sourceIn = qMax(0.0, clipNumber(clip, QStringLiteral("sourceIn")));
        double sourceOut = clipNumber(clip, QStringLiteral("sourceOut"), clipNumber(clip, QStringLiteral("duration")));
        if (sourceOut <= sourceIn) {
            emit errorOccurred(QStringLiteral("A clip has an invalid In/Out range: %1").arg(info.fileName()));
            return false;
        }

        clip.insert(QStringLiteral("sourceIn"), sourceIn);
        clip.insert(QStringLiteral("sourceOut"), sourceOut);
        clip.insert(QStringLiteral("duration"), sourceOut - sourceIn);
        clip.insert(QStringLiteral("path"), info.absoluteFilePath());
        visuals.push_back(clip);
        m_timelineDuration += sourceOut - sourceIn;

        if (clip.value(QStringLiteral("kind")).toString() == QStringLiteral("image")) {
            args << QStringLiteral("-loop") << QStringLiteral("1")
                 << QStringLiteral("-framerate") << QString::number(fps)
                 << QStringLiteral("-t") << number(sourceOut - sourceIn)
                 << QStringLiteral("-i") << info.absoluteFilePath();
        } else {
            args << QStringLiteral("-i") << info.absoluteFilePath();
        }
    }

    QVector<QVariantMap> audio;
    audio.reserve(audioClips.size());
    for (const QVariant &value : audioClips) {
        QVariantMap clip = value.toMap();
        const QFileInfo info(clip.value(QStringLiteral("path")).toString());
        if (!info.exists() || !info.isFile())
            continue;

        const double sourceIn = qMax(0.0, clipNumber(clip, QStringLiteral("sourceIn")));
        const double sourceOut = clipNumber(clip, QStringLiteral("sourceOut"), clipNumber(clip, QStringLiteral("duration")));
        const double duration = sourceOut - sourceIn;
        if (duration <= 0.01)
            continue;

        clip.insert(QStringLiteral("path"), info.absoluteFilePath());
        clip.insert(QStringLiteral("sourceIn"), sourceIn);
        clip.insert(QStringLiteral("sourceOut"), sourceOut);
        clip.insert(QStringLiteral("duration"), duration);
        clip.insert(QStringLiteral("start"), qMax(0.0, clipNumber(clip, QStringLiteral("start"))));
        audio.push_back(clip);
        args << QStringLiteral("-i") << info.absoluteFilePath();
    }

    QStringList filters;
    const int visualCount = visuals.size();
    for (int i = 0; i < visualCount; ++i) {
        const QVariantMap clip = visuals.at(i);
        const double sourceIn = clip.value(QStringLiteral("sourceIn")).toDouble();
        const double duration = clip.value(QStringLiteral("duration")).toDouble();

        filters << QStringLiteral("[%1:v:0]trim=start=%2:duration=%3,setpts=PTS-STARTPTS,scale=%4:%5:force_original_aspect_ratio=decrease,pad=%4:%5:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=%6,format=yuv420p[v%1]")
                       .arg(i).arg(number(sourceIn), number(duration))
                       .arg(width).arg(height).arg(fps);

        if (clip.value(QStringLiteral("kind")).toString() == QStringLiteral("video") &&
            clip.value(QStringLiteral("hasAudio")).toBool()) {
            filters << QStringLiteral("[%1:a:0]atrim=start=%2:duration=%3,asetpts=PTS-STARTPTS,aresample=48000,aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a%1]")
                           .arg(i).arg(number(sourceIn), number(duration));
        } else {
            filters << QStringLiteral("anullsrc=r=48000:cl=stereo,atrim=duration=%1,asetpts=PTS-STARTPTS[a%2]")
                           .arg(number(duration)).arg(i);
        }
    }

    QString concatInputs;
    for (int i = 0; i < visualCount; ++i)
        concatInputs += QStringLiteral("[v%1][a%1]").arg(i);
    filters << QStringLiteral("%1concat=n=%2:v=1:a=1[sequenceVideo][sequenceAudio]")
                   .arg(concatInputs).arg(visualCount);

    QString finalAudio = QStringLiteral("sequenceAudio");
    if (!audio.isEmpty()) {
        QString mixInputs = QStringLiteral("[sequenceAudio]");
        for (int i = 0; i < audio.size(); ++i) {
            const int inputIndex = visualCount + i;
            const QVariantMap clip = audio.at(i);
            const double sourceIn = clip.value(QStringLiteral("sourceIn")).toDouble();
            const double duration = clip.value(QStringLiteral("duration")).toDouble();
            const double start = clip.value(QStringLiteral("start")).toDouble();
            const double volume = qBound(0.0, clipNumber(clip, QStringLiteral("volume"), 100.0) / 100.0, 2.0);
            const qint64 delayMs = qMax<qint64>(0, qRound64(start * 1000.0));

            filters << QStringLiteral("[%1:a:0]atrim=start=%2:duration=%3,asetpts=PTS-STARTPTS,aresample=48000,volume=%4,adelay=%5|%5,atrim=duration=%6[music%1]")
                           .arg(inputIndex).arg(number(sourceIn), number(duration), number(volume))
                           .arg(delayMs).arg(number(m_timelineDuration));
            mixInputs += QStringLiteral("[music%1]").arg(inputIndex);
        }

        finalAudio = QStringLiteral("mixedAudio");
        filters << QStringLiteral("%1amix=inputs=%2:duration=first:dropout_transition=0:normalize=0[%3]")
                       .arg(mixInputs).arg(audio.size() + 1).arg(finalAudio);
    }

    args << QStringLiteral("-filter_complex") << filters.join(QLatin1Char(';'))
         << QStringLiteral("-map") << QStringLiteral("[sequenceVideo]")
         << QStringLiteral("-map") << QStringLiteral("[%1]").arg(finalAudio)
         << QStringLiteral("-c:v") << QStringLiteral("libx264")
         << QStringLiteral("-preset") << QStringLiteral("veryfast")
         << QStringLiteral("-crf") << QStringLiteral("19")
         << QStringLiteral("-pix_fmt") << QStringLiteral("yuv420p")
         << QStringLiteral("-c:a") << QStringLiteral("aac")
         << QStringLiteral("-b:a") << QStringLiteral("192k")
         << QStringLiteral("-movflags") << QStringLiteral("+faststart")
         << QStringLiteral("-t") << number(m_timelineDuration)
         << outputInfo.absoluteFilePath();

    m_outputPath = outputInfo.absoluteFilePath();
    m_errorOutput.clear();
    m_progressBuffer.clear();
    setExportProgress(0);
    m_exporting = true;
    emit exportingChanged();
    m_process->start(executable, args);
    return true;
}

void MediaController::handleStandardOutput()
{
    m_progressBuffer += m_process->readAllStandardOutput();
    while (true) {
        const qsizetype newline = m_progressBuffer.indexOf('\n');
        if (newline < 0)
            break;
        const QByteArray line = m_progressBuffer.left(newline).trimmed();
        m_progressBuffer.remove(0, newline + 1);

        if (line.startsWith("out_time_ms=")) {
            bool ok = false;
            const qint64 micros = line.mid(12).toLongLong(&ok);
            if (ok && m_timelineDuration > 0.0) {
                const int percent = qBound(0, static_cast<int>((micros / (m_timelineDuration * 1000000.0)) * 100.0), 99);
                setExportProgress(percent);
            }
        } else if (line == "progress=end") {
            setExportProgress(100);
        }
    }
}

void MediaController::finishExport(int exitCode, QProcess::ExitStatus exitStatus)
{
    handleStandardOutput();
    const QString stderrText = QString::fromUtf8(m_process->readAllStandardError()).trimmed();
    if (!stderrText.isEmpty())
        m_errorOutput += stderrText;

    if (!m_exporting)
        return;

    m_exporting = false;
    emit exportingChanged();

    const bool success = exitStatus == QProcess::NormalExit && exitCode == 0 &&
                         QFileInfo::exists(m_outputPath) && QFileInfo(m_outputPath).size() > 0;
    if (success) {
        setExportProgress(100);
        emit exportFinished(true, QStringLiteral("Export complete: %1").arg(m_outputPath));
    } else {
        const QString details = m_errorOutput.trimmed();
        const QString message = details.isEmpty()
            ? QStringLiteral("FFmpeg export failed (exit code %1).").arg(exitCode)
            : QStringLiteral("FFmpeg export failed: %1").arg(details.right(4000));
        emit errorOccurred(message);
        emit exportFinished(false, message);
    }
}

void MediaController::setExportProgress(int progress)
{
    progress = qBound(0, progress, 100);
    if (m_exportProgress == progress)
        return;
    m_exportProgress = progress;
    emit exportProgressChanged(m_exportProgress);
}
