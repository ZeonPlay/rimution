#pragma once

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QVariantMap>
#include <QUrl>

class MediaController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool exporting READ exporting NOTIFY exportingChanged)
    Q_PROPERTY(int exportProgress READ exportProgress NOTIFY exportProgressChanged)

public:
    explicit MediaController(QObject *parent = nullptr);

    bool exporting() const;
    int exportProgress() const;

    Q_INVOKABLE QVariantMap probeMedia(const QString &path) const;
    Q_INVOKABLE QUrl fileUrl(const QString &path) const;
    Q_INVOKABLE bool exportTimeline(const QVariantList &visualClips,
                                    const QVariantList &audioClips,
                                    const QString &outputPath,
                                    int width,
                                    int height,
                                    int fps);

signals:
    void exportingChanged();
    void exportProgressChanged(int progress);
    void exportFinished(bool success, const QString &message);
    void errorOccurred(const QString &message);

private:
    void handleStandardOutput();
    void finishExport(int exitCode, QProcess::ExitStatus exitStatus);
    void setExportProgress(int progress);

    QProcess *m_process = nullptr;
    bool m_exporting = false;
    int m_exportProgress = 0;
    double m_timelineDuration = 0.0;
    QString m_outputPath;
    QString m_errorOutput;
    QByteArray m_progressBuffer;
};
