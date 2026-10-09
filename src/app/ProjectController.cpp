#include "ProjectController.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

ProjectController::ProjectController(QObject *parent)
    : QObject(parent)
{
}

bool ProjectController::saveProject(const QString &filePath, const QVariantMap &project)
{
    if (filePath.trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral("No project file was selected."));
        return false;
    }

    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit errorOccurred(QStringLiteral("Cannot write project: %1").arg(file.errorString()));
        return false;
    }

    QVariantMap data = project;
    data.insert(QStringLiteral("format"), QStringLiteral("rimution-project"));
    data.insert(QStringLiteral("formatVersion"), 1);

    const QJsonDocument document = QJsonDocument::fromVariant(data);
    const QByteArray bytes = document.toJson(QJsonDocument::Indented);
    if (file.write(bytes) != bytes.size()) {
        emit errorOccurred(QStringLiteral("Could not write the complete project file."));
        file.cancelWriting();
        return false;
    }

    if (!file.commit()) {
        emit errorOccurred(QStringLiteral("Could not finish saving: %1").arg(file.errorString()));
        return false;
    }

    emit projectSaved(QFileInfo(filePath).absoluteFilePath());
    return true;
}

QVariantMap ProjectController::loadProject(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred(QStringLiteral("Cannot open project: %1").arg(file.errorString()));
        return {};
    }

    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        emit errorOccurred(QStringLiteral("Invalid project file: %1").arg(parseError.errorString()));
        return {};
    }

    QVariantMap project = document.object().toVariantMap();
    if (project.value(QStringLiteral("format")).toString() != QStringLiteral("rimution-project") ||
        project.value(QStringLiteral("formatVersion")).toInt() != 1) {
        emit errorOccurred(QStringLiteral("This file is not a supported Rimution project."));
        return {};
    }

    emit projectLoaded(QFileInfo(filePath).absoluteFilePath());
    return project;
}
