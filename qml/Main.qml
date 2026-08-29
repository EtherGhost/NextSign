import QtQuick 2.7
import Lomiri.Components 1.3
import "backend"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "nextsign.cloudsite"
    automaticOrientation: true

    width: desktopLarge ? units.gu(45) : units.gu(45)
    height: desktopLarge ? units.gu(80) : units.gu(75)

    Component.onCompleted: {
        if (desktopDarkMode) {
            theme.name = "Ubuntu.Components.Themes.SuruDark"
        }
    }

    AppController {
        id: appController
        appName: "NextSign"
        appDescription: "Sign documents by tapping - a native Ubuntu Touch client for LibreSign on Nextcloud."
        apiNote: "Loads documents waiting for your signature. Signing them is not implemented yet."
    }

    PageStack {
        id: pageStack
        anchors.fill: parent

        Component.onCompleted: push(Qt.resolvedUrl("pages/HomePage.qml"), {
            "appController": appController
        })
    }
}
