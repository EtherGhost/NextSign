import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Qt.labs.settings 1.0
import UTControls 1.0
import "qrc:/NextCommon" as NextCommon
import "../backend"

Page {
    id: page
    property var appController
    property bool drawerOpen: false

    function openPage(url) {
        drawerOpen = false
        var initialProps = {"appController": appController}
        if (url === "SignatureSetupPage.qml") {
            initialProps.dataController = dataController
        }
        pageStack.push(Qt.resolvedUrl(url), initialProps)
    }

    // Only checks the "signature" image type, not "initial" - clickToSign documents
    // set up so far only ever place a signature field, and this app doesn't offer
    // setting up an initials image (yet).
    function needsSignatureSetup(doc) {
        if ("signature" in dataController.signatureElementsByType) {
            return false
        }
        var elements = doc.visibleElements || []
        for (var i = 0; i < elements.length; ++i) {
            if (elements[i].type === "signature") {
                return true
            }
        }
        return false
    }

    function attemptSign(doc) {
        if (!doc) {
            return
        }
        if (page.needsSignatureSetup(doc)) {
            page.openPage("SignatureSetupPage.qml")
            return
        }
        page.signRequestedUuid = doc.uuid
        page.lastSignRequestedName = doc.name
        PopupUtils.open(signConfirmDialog)
    }

    function statusIconKind() {
        if (dataController.loading) {
            return "syncing"
        }
        if (dataController.syncStateColor === "#5a8f3c") {
            return "synced"
        }
        return "warning"
    }

    header: PageHeader {
        id: header
        title: ""

        contents: Item {
            anchors.fill: parent

            NextCommon.MainTopBar {
                searchText: ""
                searchPlaceholder: ""
                filterIconKind: "sort"
                filterActive: page.sortMode !== "date-desc" || page.showOnlyNeedsAttention
                statusKind: page.statusIconKind()
                statusColor: dataController.syncStateColor
                statusAnimating: dataController.loading
                avatarUrl: dataController.accountAvatarUrl
                accountInitial: page.accountInitial
                onMenuClicked: page.drawerOpen = true
                onFilterClicked: PopupUtils.open(sortDialog)
                onStatusClicked: PopupUtils.open(statusDetailsDialog)
                onAccountClicked: page.openPage("AccountSelectionPage.qml")
            }
        }

    }

    readonly property string accountInitial: accountSettings.displayName.length > 0
        ? accountSettings.displayName.charAt(0).toUpperCase()
        : "?"

    Settings {
        id: accountSettings
        category: "account"
        property string displayName: ""
    }

    Component {
        id: statusDetailsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Status")
            text: dataController.statusText

            Button {
                text: i18n.tr("Refresh")
                enabled: !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.refresh()
                }
            }

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: sortDialog

        Dialog {
            id: dialog
            title: i18n.tr("Sort")

            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Newest first")
                variant: page.sortMode === "date-desc" ? "primary" : "normal"
                onClicked: { page.sortMode = "date-desc"; PopupUtils.close(dialog) }
            }
            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Oldest first")
                variant: page.sortMode === "date-asc" ? "primary" : "normal"
                onClicked: { page.sortMode = "date-asc"; PopupUtils.close(dialog) }
            }
            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Name (A-Z)")
                variant: page.sortMode === "name-asc" ? "primary" : "normal"
                onClicked: { page.sortMode = "name-asc"; PopupUtils.close(dialog) }
            }
            AppButton {
                Layout.fillWidth: true
                Layout.topMargin: units.gu(1)
                text: page.showOnlyNeedsAttention ? i18n.tr("Showing only what needs your attention") : i18n.tr("Show only what needs your attention")
                variant: page.showOnlyNeedsAttention ? "primary" : "normal"
                onClicked: page.showOnlyNeedsAttention = !page.showOnlyNeedsAttention
            }
        }
    }

    SignController {
        id: dataController
        onDocumentsChanged: page.updateSortedDocuments()
        onDocumentDeleted: page.updateSortedDocuments()
        onDocumentDeleteFailed: function(message) {
            page.deleteErrorMessage = message
            PopupUtils.open(deleteErrorDialog)
        }
    }

    DocumentShareImportHandlerUbuntu {
        id: shareImportHandler
        onDocumentImported: function(fileUrl, fileName) {
            pageStack.push(Qt.resolvedUrl("PrepareDocumentPage.qml"), {
                "documentUrl": fileUrl,
                "documentName": fileName,
                "dataController": dataController
            })
        }
        onImportFailed: function(message) {
            page.shareImportErrorMessage = message
            PopupUtils.open(shareImportErrorDialog)
        }
    }

    property string shareImportErrorMessage: ""
    property string deleteErrorMessage: ""
    property var pendingDeleteDocument: null

    Component {
        id: shareImportErrorDialog
        Dialog {
            id: dialog
            title: i18n.tr("Could not receive document")
            text: page.shareImportErrorMessage
            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteErrorDialog
        Dialog {
            id: dialog
            title: i18n.tr("Could not delete sign request")
            text: page.deleteErrorMessage
            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteConfirmDialog
        Dialog {
            id: dialog
            title: i18n.tr("Delete sign request?")
            text: i18n.tr("This removes the signing request for \"%1\" - the file itself won't be deleted. This can't be undone.")
                .arg(page.pendingDeleteDocument ? (page.pendingDeleteDocument.name || i18n.tr("Untitled document")) : "")

            Button {
                text: i18n.tr("Delete")
                color: theme.palette.normal.negative
                onClicked: {
                    var target = page.pendingDeleteDocument
                    page.pendingDeleteDocument = null
                    PopupUtils.close(dialog)
                    if (target) {
                        dataController.deleteDocument(target.fileId)
                    }
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    page.pendingDeleteDocument = null
                    PopupUtils.close(dialog)
                }
            }
        }
    }

    // Only while nobody has signed yet (status 1) - once any signature exists
    // (partially or fully signed), that's real data; cancelling instead of
    // deleting isn't offered for those. Matches the Android app's own gating,
    // narrowed down after the user twice called a broader version "weird".
    function canDeleteDocument(doc) {
        return doc.fileId !== -1
            && doc.requestedByUserId.length > 0
            && doc.requestedByUserId === dataController.currentUserName
            && doc.fileStatus === 1
    }

    property string sortMode: "date-desc"
    property bool showOnlyNeedsAttention: false
    property var sortedDocuments: []

    // Distinct from "no documents at all" - the filter hid everything, not an
    // actually-empty list. Matches the Android app's own equivalent distinction.
    readonly property bool filterHidAllDocuments: showOnlyNeedsAttention
        && dataController.documents.length > 0
        && sortedDocuments.length === 0

    onSortModeChanged: updateSortedDocuments()
    onShowOnlyNeedsAttentionChanged: updateSortedDocuments()

    function updateSortedDocuments() {
        var list = dataController.documents.slice()
        if (page.showOnlyNeedsAttention) {
            list = list.filter(function(doc) { return doc.canSignNow })
        }
        if (page.sortMode === "name-asc") {
            list.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
        } else {
            list.sort(function(a, b) {
                var da = Date.parse(a["createdAt"]) || 0
                var db = Date.parse(b["createdAt"]) || 0
                return page.sortMode === "date-asc" ? da - db : db - da
            })
        }
        sortedDocuments = list
    }

    // Mirrors LibreSign's own web UI status labels/colors for a file's overall progress.
    // canSignNow distinguishes "nobody has signed yet and it's your turn" from "nobody
    // has signed yet but you're not actually a signer on this document" - both have
    // fileStatus===1, but only the first one should say "Ready to sign". Matches the
    // Android app's own statusLabel() wording exactly, after the same bug was found and
    // fixed there first.
    function statusLabel(fileStatus, canSignNow) {
        if (fileStatus === 1) {
            return canSignNow ? i18n.tr("Ready to sign") : i18n.tr("Waiting on others")
        }
        if (fileStatus === 2) {
            return canSignNow ? i18n.tr("Partially signed") : i18n.tr("Waiting on others")
        }
        if (fileStatus === 3) {
            return i18n.tr("Signed")
        }
        return ""
    }

    // Blue: a signature is still owed by this signer. Green: nothing left for THIS
    // signer to do, but they were genuinely part of it (fully signed, or their own part
    // of a partially-signed doc). Grey: this signer isn't part of the document at all -
    // distinct from green so it never reads as "you signed this" when you never had a
    // part to play. Matches the Android app's own statusColor() exactly, including the
    // hex values, for consistency across both apps.
    function statusColor(fileStatus, canSignNow) {
        if (fileStatus === 1 && !canSignNow) return "#757575"
        if (fileStatus === 3 || (fileStatus === 2 && !canSignNow)) return "#5a8f3c"
        return "#1f6feb"
    }

    Connections {
        target: appController
        onAccountChanged: dataController.applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
    }

    Connections {
        target: dataController
        onPreviewReady: function(fileUrl, suggestedName) {
            pageStack.push(Qt.resolvedUrl("DocumentExportPage.qml"), {
                "documentUrl": fileUrl,
                "documentName": suggestedName
            })
        }
        onPreviewFailed: function(message) {
            page.previewErrorMessage = message
            PopupUtils.open(previewErrorDialog)
        }
        onSignSucceeded: function(uuid) {
            page.signedDocumentName = page.lastSignRequestedName
            PopupUtils.open(signSucceededDialog)
        }
        onSignFailed: function(message) {
            page.signErrorMessage = message
            PopupUtils.open(signErrorDialog)
        }
        onValidationReady: function(summary) {
            page.validationSummaryText = page.formatValidationSummary(summary)
            PopupUtils.open(validationResultDialog)
        }
        onValidationFailed: function(message) {
            page.validationErrorMessage = message
            PopupUtils.open(validationErrorDialog)
        }
    }

    property string previewErrorMessage: ""
    property string signErrorMessage: ""
    property string signRequestedUuid: ""
    property string lastSignRequestedName: ""
    property string signedDocumentName: ""
    property string validationSummaryText: ""
    property string validationErrorMessage: ""
    property var detailDocument: null

    function formatValidationSummary(summary) {
        var lines = []
        lines.push(summary.statusText && summary.statusText.length > 0
            ? summary.statusText
            : i18n.tr("Signed"))
        var signers = summary.signers || []
        for (var i = 0; i < signers.length; ++i) {
            var signer = signers[i]
            lines.push("")
            lines.push(signer.displayName || i18n.tr("Unknown signer"))
            if (signer.signatureLabel.length > 0) {
                lines.push(signer.signatureLabel)
            }
            if (signer.certificateLabel.length > 0) {
                lines.push(signer.certificateLabel)
            }
        }
        return lines.join("\n")
    }

    Component {
        id: previewErrorDialog

        Dialog {
            id: dialog
            title: i18n.tr("Could not open document")
            text: page.previewErrorMessage

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: detailDialog

        Dialog {
            id: dialog
            title: page.detailDocument ? (page.detailDocument.name || i18n.tr("Untitled document")) : ""
            text: page.detailDocument ? page.statusLabel(page.detailDocument.fileStatus, page.detailDocument.canSignNow) : ""

            Repeater {
                model: page.detailDocument ? page.detailDocument.signers : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)
                    Label {
                        Layout.fillWidth: true
                        text: modelData.displayName || i18n.tr("Unknown signer")
                        elide: Text.ElideRight
                    }
                    Label {
                        text: modelData.signed.length > 0 ? i18n.tr("Signed") : i18n.tr("Ready to sign")
                        color: modelData.signed.length > 0 ? "#5a8f3c" : "#757575"
                        textSize: Label.Small
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: page.detailDocument ? page.detailDocument.messageForMe.length > 0 : false
                color: theme.palette.normal.background
                border.width: 1
                border.color: theme.palette.normal.base
                radius: units.gu(0.5)
                implicitHeight: messageColumn.implicitHeight + units.gu(1.6)
                ColumnLayout {
                    id: messageColumn
                    anchors { fill: parent; margins: units.gu(0.8) }
                    spacing: units.gu(0.2)
                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Message from the requester")
                        textSize: Label.XSmall
                        opacity: 0.72
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.detailDocument ? page.detailDocument.messageForMe : ""
                        wrapMode: Text.WordWrap
                    }
                }
            }

            AppButton {
                Layout.fillWidth: true
                visible: page.detailDocument ? page.detailDocument.canSignNow : false
                text: dataController.signingUuid === (page.detailDocument ? page.detailDocument.uuid : "") ? i18n.tr("Signing...") : i18n.tr("Sign document")
                variant: "primary"
                enabled: dataController.signingUuid.length === 0 && !dataController.downloadingPreview
                onClicked: {
                    PopupUtils.close(dialog)
                    page.attemptSign(page.detailDocument)
                }
            }

            AppButton {
                Layout.fillWidth: true
                text: dataController.validatingUuid === (page.detailDocument ? page.detailDocument.uuid : "") ? i18n.tr("Validating...") : i18n.tr("Validation info")
                variant: "normal"
                enabled: dataController.validatingUuid.length === 0 && !dataController.downloadingPreview
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.validateDocument(page.detailDocument.uuid)
                }
            }

            AppButton {
                Layout.fillWidth: true
                text: dataController.downloadingPreview ? i18n.tr("Opening...") : i18n.tr("Open file")
                variant: "normal"
                enabled: !dataController.downloadingPreview && dataController.signingUuid.length === 0 && dataController.validatingUuid.length === 0
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.previewDocument(page.detailDocument.uuid)
                }
            }

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: signConfirmDialog

        ConfirmDialog {
            id: dialog
            title: i18n.tr("Sign this document?")
            message: i18n.tr("This will sign \"%1\" using LibreSign's click-to-sign method. This cannot be undone.")
                .arg(page.lastSignRequestedName.length > 0 ? page.lastSignRequestedName : i18n.tr("Untitled document"))
            confirmText: i18n.tr("Sign")
            onConfirmed: dataController.signDocument(page.signRequestedUuid)
        }
    }

    Component {
        id: signSucceededDialog

        Dialog {
            id: dialog
            title: i18n.tr("Signed")
            text: i18n.tr("\"%1\" has been signed.")
                .arg(page.signedDocumentName.length > 0 ? page.signedDocumentName : i18n.tr("Untitled document"))

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: signErrorDialog

        Dialog {
            id: dialog
            title: i18n.tr("Could not sign document")
            text: page.signErrorMessage

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: validationResultDialog

        Dialog {
            id: dialog
            title: i18n.tr("Signature validation")
            text: page.validationSummaryText

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: validationErrorDialog

        Dialog {
            id: dialog
            title: i18n.tr("Could not validate document")
            text: page.validationErrorMessage

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        width: parent.width - units.gu(4)
        visible: !dataController.loading && dataController.documents.length === 0
        symbol: "✍"
        title: i18n.tr("No documents yet")
        message: i18n.tr("Documents you're requested to sign, or have already signed, will appear here.")
    }

    EmptyState {
        anchors.centerIn: parent
        width: parent.width - units.gu(4)
        visible: !dataController.loading && page.filterHidAllDocuments
        symbol: "✍"
        title: i18n.tr("Nothing needs your attention right now")
        message: ""
    }

    Flickable {
        id: listFlickable
        anchors { fill: parent; topMargin: page.header.height }
        contentWidth: width
        contentHeight: contentColumn.height + units.gu(3)
        clip: true
        visible: page.sortedDocuments.length > 0
        boundsBehavior: Flickable.DragOverBounds

        property real pullRefreshThreshold: units.gu(7)
        property bool pullRefreshArmed: false

        onContentYChanged: {
            if (contentY < -pullRefreshThreshold && !dataController.loading) {
                pullRefreshArmed = true
            }
        }
        onDraggingChanged: {
            if (!dragging && pullRefreshArmed && !dataController.loading) {
                dataController.refresh()
            }
            if (!dragging) {
                pullRefreshArmed = false
            }
        }

        Item {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: contentColumn.top; bottomMargin: units.gu(1) }
            width: pullRefreshLabel.implicitWidth
            height: pullRefreshLabel.implicitHeight
            opacity: (listFlickable.contentY < -units.gu(2) || dataController.loading) ? 0.72 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Label {
                id: pullRefreshLabel
                text: dataController.loading
                    ? i18n.tr("Refreshing...")
                    : (listFlickable.pullRefreshArmed ? i18n.tr("Release to refresh") : i18n.tr("Pull to refresh"))
                textSize: Label.Small
            }
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(2) }
            spacing: units.gu(1)

            Repeater {
                model: page.sortedDocuments
                delegate: Item {
                    id: cardItem
                    // Status badge lives in its own row at the bottom, always
                    // left-aligned at the same position - putting it inline next to
                    // the name landed it at a different horizontal spot on every card
                    // depending on how long the name was.
                    //
                    // Plain Item, not ListItem - ListItem turned out to fight us on two
                    // fronts, confirmed by logging real numbers rather than guessing:
                    // (1) its own built-in bottom divider drew a second line under our
                    // own card border, and (2) it silently overrode our height binding
                    // with its own internal default (logged cardRow.implicitHeight=158
                    // while cardItem.height stayed at 50 regardless), which is what was
                    // actually clipping the badge - not a cache or timing issue. A plain
                    // Item has neither problem: no default styling, and height set here
                    // is just a normal property, honored as declared.
                    //
                    // Height is derived from the content itself (cardRow.implicitHeight)
                    // plus the same units.gu(1) gap on every side, top/bottom included -
                    // not a hand-picked guess, so it never drifts out of sync with
                    // whatever the content actually needs (e.g. the optional "Requested
                    // by" line).
                    width: parent.width
                    height: cardRow.implicitHeight + units.gu(2)
                    Rectangle {
                        anchors { fill: parent; margins: units.gu(0.35) }
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            page.detailDocument = modelData
                            PopupUtils.open(detailDialog)
                        }
                    }
                    RowLayout {
                        id: cardRow
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(1) }
                        spacing: units.gu(1)
                        ColumnLayout {
                            id: cardColumn
                            Layout.fillWidth: true
                            spacing: units.gu(0.2)
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name || i18n.tr("Untitled document")
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: modelData.requestedBy.length > 0
                                text: i18n.tr("Requested by %1").arg(modelData.requestedBy)
                                textSize: Label.Small
                                opacity: 0.72
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: badgeRect
                                Layout.topMargin: units.gu(0.3)
                                radius: height / 2
                                color: "transparent"
                                border.width: 1
                                border.color: page.statusColor(modelData.fileStatus, modelData.canSignNow)
                                implicitWidth: statusBadgeLabel.implicitWidth + units.gu(1.2)
                                implicitHeight: statusBadgeLabel.implicitHeight + units.gu(0.4)
                                Label {
                                    id: statusBadgeLabel
                                    anchors.centerIn: parent
                                    text: page.statusLabel(modelData.fileStatus, modelData.canSignNow)
                                    textSize: Label.XSmall
                                    color: page.statusColor(modelData.fileStatus, modelData.canSignNow)
                                }
                            }
                        }
                        AppButton {
                            text: dataController.downloadingPreview ? i18n.tr("Opening...") : i18n.tr("View")
                            variant: "normal"
                            enabled: !dataController.downloadingPreview && dataController.signingUuid.length === 0 && dataController.validatingUuid.length === 0
                            onClicked: dataController.previewDocument(modelData.uuid)
                        }
                        AppButton {
                            visible: modelData.canSignNow
                            text: dataController.signingUuid === modelData.uuid ? i18n.tr("Signing...") : i18n.tr("Sign")
                            variant: "primary"
                            enabled: dataController.signingUuid.length === 0 && !dataController.downloadingPreview
                            onClicked: page.attemptSign(modelData)
                        }
                        Icon {
                            visible: page.canDeleteDocument(modelData)
                            name: "delete"
                            Layout.preferredWidth: units.gu(2.5)
                            Layout.preferredHeight: units.gu(2.5)
                            color: theme.palette.normal.backgroundText
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    page.pendingDeleteDocument = modelData
                                    PopupUtils.open(deleteConfirmDialog)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: page.drawerOpen ? 0.36 : 0; visible: page.drawerOpen; z: 8; MouseArea { anchors.fill: parent; onClicked: page.drawerOpen = false } }

    NextCommon.DrawerShell {
        id: drawer
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        visible: page.drawerOpen
        z: 9
        appName: appController.appName
        bottomItems: [
            {"label": i18n.tr("Language"), "page": "LanguageSelectionPage.qml"},
            {"label": i18n.tr("Account"), "page": "AccountSelectionPage.qml"},
            {"label": i18n.tr("Signature"), "page": "SignatureSetupPage.qml"},
            {"label": i18n.tr("Prepare a document"), "page": "PrepareDocumentGuidePage.qml"},
            {"label": i18n.tr("Settings"), "page": "SettingsPage.qml"},
            {"label": i18n.tr("About"), "page": "AboutPage.qml"}
        ]
        onCloseClicked: page.drawerOpen = false
        onBottomItemClicked: page.openPage(pageUrl)
    }
}
