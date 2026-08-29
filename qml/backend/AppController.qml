import QtQuick 2.7

QtObject {
    property string appName: ""
    property string appDescription: ""
    property string apiNote: ""

    signal accountChanged(int accountId, string displayName, string providerId, string serviceId, string serverUrl, string avatarUrl)
}
