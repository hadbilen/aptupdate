pragma Singleton
import QtQuick

QtObject {
    id: plasmoidSingleton
    property var configuration: ConfigDefaults {}
}
