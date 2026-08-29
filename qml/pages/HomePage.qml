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
        pageStack.push(Qt.resolvedUrl(url), {"appController": appController})
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

        extension: Sections {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
                bottom: parent.bottom
            }
            model: [i18n.tr("To sign"), i18n.tr("Signed")]
            selectedIndex: dataController.viewStatus === 3 ? 1 : 0
            onSelectedIndexChanged: dataController.switchView(selectedIndex === 1 ? 3 : 1)
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
        var dateField = dataController.viewStatus === 3 ? "signedAt" : "createdAt"
        if (page.sortMode === "name-asc") {
            list.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
        } else {
            list.sort(function(a, b) {
                var da = Date.parse(a[dateField]) || 0
                var db = Date.parse(b[dateField]) || 0
                return page.sortMode === "date-asc" ? da - db : db - da
            })
        }
        sortedDocuments = list
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
        title: dataController.viewStatus === 3 ? i18n.tr("No signed documents yet") : i18n.tr("No documents to sign")
        message: dataController.viewStatus === 3
            ? i18n.tr("Documents you have signed will appear here.")
            : i18n.tr("Documents waiting for your signature will appear here.")
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
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name || i18n.tr("Untitled document")
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: dataController.viewStatus === 3 ? modelData.signedAt.length > 0 : modelData.requestedBy.length > 0
                                text: dataController.viewStatus === 3
                                    ? i18n.tr("Signed %1").arg(Qt.formatDate(new Date(modelData.signedAt), "yyyy-MM-dd"))
                                    : i18n.tr("Requested by %1").arg(modelData.requestedBy)
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
                            visible: dataController.viewStatus === 1
                            text: dataController.signingUuid === modelData.uuid ? i18n.tr("Signing...") : i18n.tr("Sign")
                            variant: "primary"
                            enabled: dataController.signingUuid.length === 0 && !dataController.downloadingPreview
                            onClicked: {
                                page.signRequestedUuid = modelData.uuid
                                page.lastSignRequestedName = modelData.name
                                PopupUtils.open(signConfirmDialog)
                            }
                        }
                        AppButton {
                            visible: dataController.viewStatus === 3
                            text: dataController.validatingUuid === modelData.uuid ? i18n.tr("Validating...") : i18n.tr("Validate")
                            variant: "primary"
                            enabled: dataController.validatingUuid.length === 0 && !dataController.downloadingPreview
                            onClicked: dataController.validateDocument(modelData.uuid)
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
            {"label": i18n.tr("Settings"), "page": "SettingsPage.qml"},
            {"label": i18n.tr("About"), "page": "AboutPage.qml"}
        ]
        onCloseClicked: page.drawerOpen = false
        onBottomItemClicked: page.openPage(pageUrl)
    }
}
