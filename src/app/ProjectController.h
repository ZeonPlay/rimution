#pragma once

#include <QObject>
#include <QVariantMap>
#include <QString>

class ProjectController final : public QObject
{
    Q_OBJECT

public:
    explicit ProjectController(QObject *parent = nullptr);

    Q_INVOKABLE bool saveProject(const QString &filePath, const QVariantMap &project);
    Q_INVOKABLE QVariantMap loadProject(const QString &filePath);

signals:
    void errorOccurred(const QString &message);
    void projectSaved(const QString &filePath);
    void projectLoaded(const QString &filePath);
};
