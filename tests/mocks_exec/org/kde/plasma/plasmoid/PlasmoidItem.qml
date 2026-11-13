import QtQuick
import org.kde.plasma.plasmoid as PlasmoidMod

Item {
    id: mockPlasmoidRoot
    property string id: "test-plasmoid"
    property bool expanded: false
    property int formFactor: 2
    property int status: 0
    property var compactRepresentation: null
    property var fullRepresentation: null
    property var contextualActions: []
    property var toolTipItem: null
    property QtObject plasmoid: QtObject {
        property string id: mockPlasmoidRoot.id
        property bool expanded: mockPlasmoidRoot.expanded
        property int formFactor: mockPlasmoidRoot.formFactor
        property var configuration: PlasmoidMod.PlasmoidHarness.configuration
        property var rootItem: mockPlasmoidRoot
    }
    property var configuration: PlasmoidMod.PlasmoidHarness.configuration
}
