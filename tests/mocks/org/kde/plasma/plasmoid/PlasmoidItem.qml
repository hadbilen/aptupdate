import QtQuick

Item {
    property string id: "test-plasmoid"
    property bool expanded: false
    property int formFactor: 2
    property int status: 0
    property var compactRepresentation: null
    property var fullRepresentation: null
    property var contextualActions: []
    property var toolTipItem: null
    property var configuration: Plasmoid.configuration
}
