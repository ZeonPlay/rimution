#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QtQml/qqml.h>

#include "app/ProjectController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Rimution");
    QCoreApplication::setApplicationVersion("0.1.0");
    QCoreApplication::setOrganizationName("ZeonPlay");

    qmlRegisterType<ProjectController>("Rimution", 1, 0, "ProjectController");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);

    // loadFromModule() requires Qt 6.5. Use the QML module resource URL
    // so the project also builds with the Qt 6.4.x shipped by Ubuntu 24.04.
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Rimution/Main.qml")));

    return app.exec();
}
