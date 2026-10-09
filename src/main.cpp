#include <QGuiApplication>
#include <QQmlApplicationEngine>
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
    engine.loadFromModule("Rimution", "Main");

    return app.exec();
}
