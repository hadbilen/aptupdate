import QtQuick

QtObject {
    property int updateInterval: 60
    property int updateIntervalUnit: 0
    property bool debugMode: false
    property bool retryMode: false
    property bool enableSnapUpdates: true
    property bool enableFlatpakUpdates: true
    property int startupCheckMode: 0
    property int startupDelaySeconds: 10
    property string updateCommandOne: "sudo apt install --only-upgrade"
    property string termCmd: "konsole -e"
    property string termNoCloseCmd: "konsole --noclose -e"
    property bool notCloseCommand: false
    property string termNoCloseSuffix: ""
    property bool silentUpdate: false
    property bool notifyOnSilentUpdate: true
    property bool includePhasedUpdates: false
    property bool useNala: false
    property bool notifyOnUpdates: true
    property int notificationThreshold: 1
    property bool notifyOnStartup: true
    property bool notifyOnRebootRequired: true
    property bool notifyOnReleaseUpgrade: true
    property bool hasSnap: false
    property bool hasFlatpak: false
    property bool hasNala: false
    property string icon: "software-update-available.svg"
    property string secondaryIcon: "view-refresh.svg"
    property bool iconUseCustomColor: false
    property string iconColor: "#ffffff"
    property bool separateResult: false
    property string separator: " | "
    property bool hideOnZero: false
    property bool mainDot: false
    property bool mainDotUseCustomColor: false
    property string mainDotColor: "#ff0000"
    property int mainDotPosition: 2
    property bool secondDot: false
    property bool secondDotUseCustomColor: false
    property string secondDotColor: "#00ff00"
    property int secondDotPosition: 3
    property bool invertMouseAction: false
    property bool mainIsRefresh: false
    property bool groupUpdates: true
    property bool adaptiveGrouping: true
    property int adaptiveGroupingThreshold: 5
    property bool nameUseCustomColor: false
    property string nameColor: "white"
    property bool sourceUseCustomColor: false
    property string sourceColor: "white"
    property bool separatorUseCustomColor: false
    property string separatorColor: "white"
    property string separatorText: ">"
    property bool fvUseCustomColor: false
    property string fvColor: "#ffffff"
    property bool tvUseCustomColor: false
    property string tvColor: "#ffffff"
    property string debugLog: ""
}
