#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QHash>
#include <QList>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QThread>

namespace {
QMutex &configMutex()
{
    static QMutex m;
    return m;
}

QHash<QThread *, QPointer<QObject>> &configByThread()
{
    static QHash<QThread *, QPointer<QObject>> map;
    return map;
}

QObject *currentThreadConfig()
{
    QMutexLocker locker(&configMutex());
    return configByThread().value(QThread::currentThread()).data();
}
}

class MockPlasmoidHarness : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *configuration READ configuration WRITE setConfiguration NOTIFY configurationChanged)

public:
    explicit MockPlasmoidHarness(QObject *parent = nullptr) : QObject(parent) {}

    QObject *configuration() const { return currentThreadConfig(); }

    Q_INVOKABLE void setConfiguration(QObject *cfg)
    {
        {
            QMutexLocker locker(&configMutex());
            if (configByThread().value(QThread::currentThread()) == cfg) return;
            configByThread().insert(QThread::currentThread(), cfg);
        }
        emit configurationChanged();
    }

signals:
    void configurationChanged();
};

class MockPlasmoidAttached : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int status READ status WRITE setStatus NOTIFY statusChanged)
    Q_PROPERTY(QQmlListProperty<QObject> contextualActions READ contextualActions CONSTANT)
    Q_PROPERTY(QObject *configuration READ configuration NOTIFY configurationChanged)

public:
    explicit MockPlasmoidAttached(QObject *parent = nullptr) : QObject(parent) {}

    int status() const { return m_status; }
    void setStatus(int status)
    {
        if (m_status == status) return;
        m_status = status;
        emit statusChanged();
    }

    QQmlListProperty<QObject> contextualActions()
    {
        return QQmlListProperty<QObject>(this, &m_contextualActions);
    }

    QObject *configuration() const { return currentThreadConfig(); }

signals:
    void statusChanged();
    void configurationChanged();

private:
    int m_status = 0;
    QList<QObject *> m_contextualActions;
};

class MockPlasmoid : public QObject
{
    Q_OBJECT
    QML_ATTACHED(MockPlasmoidAttached)

public:
    explicit MockPlasmoid(QObject *parent = nullptr) : QObject(parent) {}
    static MockPlasmoidAttached *qmlAttachedProperties(QObject *object)
    {
        return new MockPlasmoidAttached(object);
    }
};

class PlasmoidMockPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterUncreatableType<MockPlasmoid>(uri, 2, 0, "Plasmoid",
            QStringLiteral("Plasmoid is only available as an attached property"));
        qmlRegisterSingletonType<MockPlasmoidHarness>(uri, 2, 0, "PlasmoidHarness",
            [](QQmlEngine *engine, QJSEngine *) -> QObject * {
                return new MockPlasmoidHarness(engine);
            });
    }
};

#include "plasmoid_mock_plugin.moc"
