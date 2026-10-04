import QtQuick 2.7
import Ubuntu.Content 1.3

// Receives a PDF shared in from another app (e.g. the Files app's "Share"
// action) via Ubuntu's content-hub - the reverse direction of
// DocumentExportPage.qml's own ContentPeerPicker. Pattern (restorePendingImports/
// processFinishedImports/dedup-by-transfer-ref) matches NextNotes' own
// ShareImportHandlerUbuntu.qml, proven working there - adapted here to keep the
// file itself (its local url), not decode it as text.
Item {
    id: handler
    visible: false

    signal documentImported(url fileUrl, string fileName)
    signal importFailed(string message)

    property var processedTransferRefs: []

    Component.onCompleted: {
        console.log("NextSign ContentHub import handler ready hasPending=" + ContentHub.hasPending
                    + " finishedImports=" + finishedImportCount())
        Qt.callLater(restorePendingImports)
    }

    Connections {
        target: ContentHub

        onImportRequested: {
            handler.handleImportRequested(transfer)
        }

        onFinishedImportsChanged: {
            handler.processFinishedImports()
        }
    }

    Timer {
        id: pendingImportTimer
        interval: 250
        repeat: false
        onTriggered: handler.processFinishedImports()
    }

    function restorePendingImports() {
        if (ContentHub.hasPending) {
            ContentHub.restoreImports()
        }
        pendingImportTimer.restart()
    }

    function finishedImportCount() {
        return ContentHub.finishedImports ? ContentHub.finishedImports.length : 0
    }

    function processFinishedImports() {
        var count = finishedImportCount()
        for (var i = 0; i < count; ++i) {
            handleImportRequested(ContentHub.finishedImports[i])
        }
    }

    function handleImportRequested(transfer) {
        if (wasTransferProcessed(transfer)) {
            return
        }
        markTransferProcessed(transfer)

        if (!transfer || !transfer.items || transfer.items.length === 0 || !transfer.items[0].url) {
            markTransferCollected(transfer)
            importFailed(i18n.tr("No shared document was received."))
            return
        }

        var item = transfer.items[0]
        var fileUrl = item.url
        var fileName = item.name || ""
        markTransferCollected(transfer)
        console.log("NextSign ContentHub import received fileName=" + fileName)
        documentImported(fileUrl, fileName)
    }

    function markTransferCollected(transfer) {
        if (!transfer) {
            return
        }
        try {
            transfer.state = ContentTransfer.Collected
            if (transfer.finalize) {
                transfer.finalize()
            }
        } catch (error) {
            console.log("NextSign ContentHub import finalize failed: " + error)
        }
    }

    function wasTransferProcessed(transfer) {
        return transfer && processedTransferRefs.indexOf(transfer) >= 0
    }

    function markTransferProcessed(transfer) {
        if (transfer && processedTransferRefs.indexOf(transfer) < 0) {
            processedTransferRefs.push(transfer)
            if (processedTransferRefs.length > 20) {
                processedTransferRefs.shift()
            }
        }
    }
}
