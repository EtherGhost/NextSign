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
                filterActive: page.sortMode !== "date-desc"
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
        }
    }

    SignController {
        id: dataController
        onDocumentsChanged: page.updateSortedDocuments()
    }

    property string sortMode: "date-desc"
    property var sortedDocuments: []

    onSortModeChanged: updateSortedDocuments()

    function updateSortedDocuments() {
        var list = dataController.documents.slice()
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
    function statusLabel(fileStatus) {
        if (fileStatus === 1) {
            return i18n.tr("Ready to sign")
        }
        if (fileStatus === 2) {
            return i18n.tr("Partially signed")
        }
        if (fileStatus === 3) {
            return i18n.tr("Signed")
        }
        return ""
    }

    function statusColor(fileStatus) {
        return fileStatus === 3 ? "#5a8f3c" : "#b37a2a"
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
            text: page.detailDocument ? page.statusLabel(page.detailDocument.fileStatus) : ""

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
                        color: modelData.signed.length > 0 ? "#5a8f3c" : "#b37a2a"
                        textSize: Label.Small
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

    Flickable {
        id: listFlickable
        anchors { fill: parent; topMargin: page.header.height }
        contentWidth: width
        contentHeight: contentColumn.height + units.gu(3)
        clip: true
        visible: dataController.documents.length > 0
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
                delegate: ListItem {
                    height: units.gu(7)
                    onClicked: {
                        page.detailDocument = modelData
                        PopupUtils.open(detailDialog)
                    }
                    Rectangle {
                        anchors { fill: parent; margins: units.gu(0.35) }
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base
                    }
                    RowLayout {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(1) }
                        spacing: units.gu(1)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: units.gu(0.2)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: units.gu(1)
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name || i18n.tr("Untitled document")
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    radius: height / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: page.statusColor(modelData.fileStatus)
                                    implicitWidth: statusBadgeLabel.implicitWidth + units.gu(1.2)
                                    implicitHeight: statusBadgeLabel.implicitHeight + units.gu(0.4)
                                    Label {
                                        id: statusBadgeLabel
                                        anchors.centerIn: parent
                                        text: page.statusLabel(modelData.fileStatus)
                                        textSize: Label.XSmall
                                        color: page.statusColor(modelData.fileStatus)
                                    }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: modelData.requestedBy.length > 0
                                text: i18n.tr("Requested by %1").arg(modelData.requestedBy)
                                textSize: Label.Small
                                opacity: 0.72
                                elide: Text.ElideRight
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
            {"label": i18n.tr("Settings"), "page": "SettingsPage.qml"},
            {"label": i18n.tr("About"), "page": "AboutPage.qml"}
        ]
        onCloseClicked: page.drawerOpen = false
        onBottomItemClicked: page.openPage(pageUrl)
    }
}
