#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QtQml/qqml.h>
#include <QDebug>

#include "app/ProjectController.h"
#include "app/MediaController.h"

static int runExportSelfTest(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName("Rimution");
    QCoreApplication::setApplicationVersion("0.2.0");

    if (app.arguments().size() < 5) {
        qCritical() << "Usage: rimution --self-test-export output.mp4 clip-a.mp4 clip-b.mp4";
        return 2;
    }

    MediaController media;
    const QString outputPath = app.arguments().at(2);
    const QString firstPath = app.arguments().at(3);
    const QString secondPath = app.arguments().at(4);
    const QVariantMap firstInfo = media.probeMedia(firstPath);
    const QVariantMap secondInfo = media.probeMedia(secondPath);
    if (firstInfo.contains("error") || secondInfo.contains("error")) {
        qCritical() << "Could not inspect export self-test clips:"
                    << firstInfo.value("error").toString()
                    << secondInfo.value("error").toString();
        return 2;
    }

    auto makeClip = [](const QVariantMap &info) {
        QVariantMap clip = info;
        clip.insert("sourceIn", 0.0);
        clip.insert("sourceOut", qMin(1.0, info.value("duration").toDouble()));
        clip.insert("duration", clip.value("sourceOut"));
        return clip;
    };

    const QVariantMap firstClip = makeClip(firstInfo);
    const QVariantMap secondClip = makeClip(secondInfo);
    const QVariantList clips = {firstClip, secondClip};
    QVariantMap overlayAudio = secondClip;
    overlayAudio.insert("start", 0.0);
    overlayAudio.insert("volume", 25.0);
    const QVariantList audioOverlays = {overlayAudio};
    QObject::connect(&media, &MediaController::exportFinished, &app,
        [&app, &media, outputPath](bool success, const QString &message) {
            if (!success) {
                qCritical().noquote() << message;
                app.exit(1);
                return;
            }
            const QVariantMap outputInfo = media.probeMedia(outputPath);
            if (outputInfo.contains("error") ||
                !outputInfo.value("hasVideo").toBool() ||
                outputInfo.value("duration").toDouble() < 1.5) {
                qCritical() << "Export output failed validation:" << outputInfo;
                app.exit(1);
                return;
            }
            qInfo().noquote() << "Export self-test passed:" << outputPath
                              << "duration:" << outputInfo.value("duration").toDouble();
            app.exit(0);
        });

    if (!media.exportTimeline(clips, audioOverlays, outputPath, 320, 180, 24))
        return 1;
    return app.exec();
}

int main(int argc, char *argv[])
{
    if (argc > 1 && QString::fromLocal8Bit(argv[1]) == QStringLiteral("--self-test-export"))
        return runExportSelfTest(argc, argv);

    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Rimution");
    QCoreApplication::setApplicationVersion("0.2.0");
    QCoreApplication::setOrganizationName("ZeonPlay");

    qmlRegisterType<ProjectController>("Rimution", 1, 0, "ProjectController");
    qmlRegisterType<MediaController>("Rimution", 1, 0, "MediaController");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Rimution/Main.qml")));
    return app.exec();
}
