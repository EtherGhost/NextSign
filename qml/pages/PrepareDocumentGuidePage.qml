import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

// There's no in-app document picker - preparing a document only starts by
// sharing a PDF to NextSign from another app (e.g. the Files app's "Share"
// action), via content-hub (see DocumentShareImportHandlerUbuntu.qml). This
// page exists purely so that entry point is discoverable from the drawer at
// all, rather than only by accident - it doesn't start a flow itself, just
// explains the real one. Matches the Android app's own equivalent guide screen,
// added there for the same reason.
Page {
    id: page
    title: i18n.tr("Prepare a document")

    header: PageHeader {
        id: header
        title: page.title
    }

    ColumnLayout {
        anchors { fill: parent; topMargin: header.height; margins: units.gu(2) }
        spacing: units.gu(1)

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n.tr("Open the file manager or another app, find the PDF you want to prepare, share it, then choose NextSign.")
        }
    }
}
