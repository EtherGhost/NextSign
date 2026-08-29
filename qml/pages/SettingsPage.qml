import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "qrc:/NextCommon" as NextCommon

NextCommon.SettingsShell {
    id: page

    title: i18n.tr("Settings")

    NextCommon.SettingsCard {
        Label {
            Layout.fillWidth: true
            text: i18n.tr("Nothing to configure yet.")
            wrapMode: Text.WordWrap
            opacity: 0.72
        }
    }
}
