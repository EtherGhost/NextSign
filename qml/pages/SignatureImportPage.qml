import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Content 1.3

Page {
    id: page
    title: i18n.tr("Pick an image")

    signal fileSelected(url fileUrl, string fileName)
    signal importCanceled()
    signal importFailed(string message)

    property var activeTransfer: null
    property bool closed: false

    header: PageHeader {
        id: header
        title: page.title
    }

    ContentPeerPicker {
        anchors {
            fill: parent
            topMargin: header.height
        }
        visible: true
        showTitle: false
        contentType: ContentType.Pictures
        handler: ContentHandler.Source

        onPeerSelected: {
            // Plain block, not function(peer) {...} - see the same note in
            // DocumentExportPage.qml about QML's implicit signal-handler injection.
            page.activeTransfer = peer.request()
            if (!page.activeTransfer) {
                page.importFailed(i18n.tr("The picture provider did not start a transfer."))
            }
        }
        onCancelPressed: page.importCanceled()
    }

    Connections {
        target: page.activeTransfer
        onStateChanged: {
            if (page.closed || !page.activeTransfer) {
                return
            }
            if (page.activeTransfer.state === ContentTransfer.Charged) {
                page.closed = true
                page.collectTransfer()
            } else if (page.activeTransfer.state === ContentTransfer.Aborted) {
                page.closed = true
                page.importCanceled()
            }
        }
    }

    function collectTransfer() {
        var items = page.activeTransfer.items || []
        if (items.length === 0 || !items[0].url) {
            page.importFailed(i18n.tr("No picture was selected."))
            return
        }
        page.fileSelected(items[0].url, items[0].name || "")
    }
}
