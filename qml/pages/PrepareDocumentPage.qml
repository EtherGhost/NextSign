import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.OnlineAccounts 2.0
import UTControls 1.0
import "../backend"
import "../backend/LibreSignApiCore.js" as LibreSignApiCore
import "qrc:/NextCommon/TextHelpers.js" as TextHelpers

// Document preparation, ported from the Android app (see the feasibility doc):
// pick up a PDF shared in via content-hub (see DocumentShareImportHandlerUbuntu.qml
// and HomePage.qml), preview page 1, choose which account should prepare it (only
// asked when more than one is known - see the account picker below, added after
// the single-account assumption turned out wrong for a user with multiple
// Nextcloud/ownCloud accounts configured), search for and select signers (generic
// search, no identify-method filter - same decision as Android), tap to place /
// drag to move / a slider to resize one signature field per signer, then submit.
Page {
    id: page
    title: i18n.tr("Prepare document")

    // Same safe-area pattern NextCommon.AccountPage already uses for its own
    // server-url field - shrinks the Flickable's bottom so the on-screen
    // keyboard can't cover the signer search field while typing.
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0

    property url documentUrl
    property string documentName: ""
    // Passed in from HomePage rather than instantiating a second SignController
    // here - a separate instance would hold its own, separately-authenticated
    // copy of the account session and document list, so a successful submission
    // wouldn't be reflected back on the document list the user returns to.
    property var dataController

    // Fixed base field size in PDF points - matches the Android app's own
    // FIELD_BASE_WIDTH/HEIGHT and the earlier live API spike.
    readonly property real fieldBaseWidth: 150
    readonly property real fieldBaseHeight: 50

    // --- Account picker: only shown when more than one Nextcloud/ownCloud
    // account is authorized for this app (Lomiri Online Accounts, same
    // applicationId/serviceIds AccountSelectionPage.qml uses) - matches the
    // Android app's own equivalent, which asks the same question since a
    // content-hub share (like Android's ACTION_SEND) carries no account info.
    readonly property string nextcloudServiceId: "nextsign.cloudsite_nextsign_nextcloud"
    readonly property string owncloudServiceId: "nextsign.cloudsite_nextsign_owncloud"
    property var knownAccounts: []
    property var chosenAccountEntry: null
    property bool accountChosen: false
    property bool accountAuthorizing: false
    property bool accountAuthorizeFailed: false
    // The credentials actually used for this document - the chosen account's,
    // once resolved. Passed explicitly to every API call below rather than
    // relying on dataController's own current* (the app's main session),
    // since the two can differ once a non-default account is chosen here.
    property string prepareServerUrl: ""
    property string prepareUserName: ""
    property string prepareSecret: ""

    AccountModel {
        id: prepareAccountModel
        applicationId: "nextsign.cloudsite_nextsign"
        onReadyChanged: page.refreshKnownAccounts()
        onCountChanged: page.refreshKnownAccounts()
    }

    function refreshKnownAccounts() {
        if (!prepareAccountModel.ready) {
            return
        }
        var matches = []
        for (var i = 0; i < prepareAccountModel.count; ++i) {
            var serviceId = prepareAccountModel.get(i, "serviceId")
            if (serviceId === page.nextcloudServiceId || serviceId === page.owncloudServiceId) {
                matches.push({
                    "accountId": prepareAccountModel.get(i, "accountId"),
                    "displayName": prepareAccountModel.get(i, "displayName"),
                    "serviceId": serviceId,
                    "account": prepareAccountModel.get(i, "account"),
                    "settings": prepareAccountModel.get(i, "settings")
                })
            }
        }
        page.knownAccounts = matches
        page.maybeAutoChooseAccount()
    }

    function maybeAutoChooseAccount() {
        if (page.accountChosen) {
            return
        }
        if (page.knownAccounts.length === 1) {
            page.chooseAccount(page.knownAccounts[0])
        } else if (page.knownAccounts.length === 0) {
            // Shouldn't normally happen - reaching this page at all requires an
            // already-authorized account - but falls back to the app's own main
            // session rather than leaving the page stuck with no way forward.
            page.accountChosen = true
            page.prepareServerUrl = dataController.currentServerUrl
            page.prepareUserName = dataController.currentUserName
            page.prepareSecret = dataController.currentSecret
        }
    }

    function chooseAccount(entry) {
        page.chosenAccountEntry = entry
        page.accountChosen = true
        page.accountAuthorizing = true
        page.accountAuthorizeFailed = false
        accountAuthConnections.target = entry.account
        entry.account.authenticate({})
    }

    Connections {
        id: accountAuthConnections
        target: null
        ignoreUnknownSignals: true
        onAuthenticationReply: function(authenticationData) {
            page.accountAuthorizing = false
            if (authenticationData && authenticationData.errorCode !== undefined) {
                page.accountAuthorizeFailed = true
                return
            }
            var userName = TextHelpers.firstValue(authenticationData, ["UserName", "Username", "userName", "username"])
            var secret = TextHelpers.firstValue(authenticationData, ["Secret", "Password", "password", "secret"])
            var entry = page.chosenAccountEntry
            var serverUrl = page.serverUrlFromAccountSettings(entry ? entry.settings : null)
            if (serverUrl.length === 0) {
                serverUrl = page.inferServerUrlFromDisplayName(entry ? entry.displayName : "")
            }
            if (!userName || !secret || serverUrl.length === 0) {
                page.accountAuthorizeFailed = true
                return
            }
            page.prepareServerUrl = LibreSignApiCore.normalizeServerUrl(serverUrl)
            page.prepareUserName = userName
            page.prepareSecret = secret
        }
    }

    function serverUrlFromAccountSettings(settings) {
        var values = [
            settings ? settings.host : "",
            settings ? settings.Host : "",
            settings ? settings.server : "",
            settings ? settings.serverUrl : "",
            settings ? settings.url : "",
            settings ? settings.Url : ""
        ]
        for (var i = 0; i < values.length; ++i) {
            if (values[i] && String(values[i]).length > 0) {
                return String(values[i])
            }
        }
        return ""
    }

    function inferServerUrlFromDisplayName(displayName) {
        var value = String(displayName || "").trim()
        var atIndex = value.lastIndexOf("@")
        if (atIndex < 0 || atIndex === value.length - 1) {
            return ""
        }
        return value.slice(atIndex + 1).replace(/[<>()\[\],;]/g, "").trim()
    }

    // Four mutually exclusive states covering the whole account-resolution
    // flow, each driving exactly one of the Items below.
    readonly property bool showAccountPicker: page.knownAccounts.length > 1 && !page.accountChosen
    readonly property bool showAccountError: page.accountChosen && page.accountAuthorizeFailed
    readonly property bool showMainContent: page.accountChosen && !page.accountAuthorizing && !page.accountAuthorizeFailed
    readonly property bool showAccountSpinner: !page.showAccountPicker && !page.showAccountError && !page.showMainContent

    // placedFields is a flat array now, not one entry per signer - a signer
    // can need more than one field (e.g. initials on several pages plus a
    // signature on the last one), confirmed as the actual real-world
    // requirement after the earlier one-field-per-signer design kept
    // producing "the box just moves instead of adding a new one" reports
    // that turned out to be the model itself being wrong, not a bug in it.
    // Each entry: {id, identify, left, top, width, height, page}.
    property var selectedSigners: []
    property var placedFields: []
    property int nextFieldId: 1
    // Who gets a brand new field when tapping empty space on the page -
    // deliberately NOT cleared on page navigation (see goToPreviousPage/
    // goToNextPage) - staying armed across pages is the whole point now,
    // e.g. arm someone once and tap every page to place their initials on
    // each one.
    property string armedSignerIdentify: ""
    // Which specific field the resize slider and long-press-to-remove act
    // on - set by tapping an existing marker, distinct from
    // armedSignerIdentify since one signer can now have several fields.
    property string selectedFieldId: ""
    property string signerSearchQuery: ""
    property var signerSearchResults: []

    // Explicit named property, not an inline filter() in the Repeater's model
    // expression - see that Repeater's own comment for why.
    readonly property var currentPageFields: {
        var result = []
        for (var i = 0; i < page.placedFields.length; ++i) {
            if (page.placedFields[i].page === page.pdfPage) {
                result.push(page.placedFields[i])
            }
        }
        return result
    }

    readonly property var selectedField: {
        for (var i = 0; i < page.placedFields.length; ++i) {
            if (page.placedFields[i].id === page.selectedFieldId) {
                return page.placedFields[i]
            }
        }
        return null
    }

    readonly property var effectiveArmedSigner: {
        for (var i = 0; i < selectedSigners.length; ++i) {
            if (selectedSigners[i].identify === armedSignerIdentify) {
                return selectedSigners[i]
            }
        }
        return null
    }

    readonly property bool canSubmit: page.accountChosen
        && !page.accountAuthorizing
        && !dataController.preparingDocument
        && selectedSigners.length > 0
        && selectedSigners.every(function(s) {
            return page.placedFields.some(function(f) { return f.identify === s.identify })
        })

    header: PageHeader {
        id: header
        title: page.title
    }

    Connections {
        target: page.dataController

        onSignersFound: function(candidates) {
            page.signerSearchResults = candidates
        }
        onSignersSearchFailed: function(message) {
            page.signerSearchResults = []
            page.signerSearchErrorMessage = message
        }
        onDocumentPrepared: {
            page.submitSucceeded = true
        }
        onDocumentPrepareFailed: function(message) {
            page.submitErrorMessage = message
        }
    }

    property string signerSearchErrorMessage: ""
    property bool submitSucceeded: false
    property string submitErrorMessage: ""

    Timer {
        id: searchDebounce
        interval: 400
        repeat: false
        onTriggered: {
            if (page.signerSearchQuery.length === 0) {
                page.signerSearchResults = []
                return
            }
            page.signerSearchErrorMessage = ""
            dataController.searchSigners(page.signerSearchQuery, page.prepareServerUrl, page.prepareUserName, page.prepareSecret)
        }
    }

    onSignerSearchQueryChanged: searchDebounce.restart()

    onSubmitSucceededChanged: if (submitSucceeded) PopupUtils.open(submitSucceededDialog)
    onSubmitErrorMessageChanged: if (submitErrorMessage.length > 0) PopupUtils.open(submitErrorDialog)

    Component {
        id: submitSucceededDialog
        Dialog {
            id: dialog
            title: i18n.tr("Sent")
            text: i18n.tr("\"%1\" has been sent for signing.").arg(page.documentName.length > 0 ? page.documentName : i18n.tr("Untitled document"))
            Button {
                text: i18n.tr("Close")
                onClicked: {
                    PopupUtils.close(dialog)
                    pageStack.pop()
                }
            }
        }
    }

    Component {
        id: submitErrorDialog
        Dialog {
            id: dialog
            title: i18n.tr("Could not send document")
            text: page.submitErrorMessage
            Button {
                text: i18n.tr("Close")
                onClicked: {
                    page.submitErrorMessage = ""
                    PopupUtils.close(dialog)
                }
            }
        }
    }

    // Long-press on a placed field marker - removes just that one field, not
    // every field this signer might have elsewhere, and keeps the signer
    // themselves in selectedSigners either way.
    property string pendingFieldRemovalId: ""

    Component {
        id: removeFieldConfirmDialog
        Dialog {
            id: dialog
            title: i18n.tr("Remove field placement?")
            text: {
                var field = null
                for (var i = 0; i < page.placedFields.length; ++i) {
                    if (page.placedFields[i].id === page.pendingFieldRemovalId) {
                        field = page.placedFields[i]
                        break
                    }
                }
                if (!field) return ""
                for (i = 0; i < page.selectedSigners.length; ++i) {
                    if (page.selectedSigners[i].identify === field.identify) {
                        return i18n.tr("This removes this signature field for %1 - any other fields placed for them are kept.").arg(page.selectedSigners[i].displayName)
                    }
                }
                return ""
            }
            Button {
                text: i18n.tr("Delete")
                color: theme.palette.normal.negative
                onClicked: {
                    var fieldId = page.pendingFieldRemovalId
                    page.pendingFieldRemovalId = ""
                    PopupUtils.close(dialog)
                    var removedField = null
                    for (var i = 0; i < page.placedFields.length; ++i) {
                        if (page.placedFields[i].id === fieldId) {
                            removedField = page.placedFields[i]
                            break
                        }
                    }
                    page.placedFields = page.placedFields.filter(function(f) { return f.id !== fieldId })
                    if (page.selectedFieldId === fieldId) {
                        page.selectedFieldId = ""
                    }
                    // Arms the signer whose field was just removed - without
                    // this, whoever was armed before (if anyone) stays armed
                    // and the just-cleared signer isn't offered for placement
                    // again until the user explicitly taps their row, which
                    // read as "the send button stays disabled forever" since
                    // nothing made it obvious how to place their field again.
                    if (removedField) {
                        page.armedSignerIdentify = removedField.identify
                    }
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    page.pendingFieldRemovalId = ""
                    PopupUtils.close(dialog)
                }
            }
        }
    }

    // --- PDF preview: rendered natively (PdfPageRenderer, backed by the
    // system's own libpoppler-qt5) to a cached PNG, rather than relying on
    // docviewer.ubports' own QML plugin - that plugin lives inside docviewer's
    // own confined click directory and isn't importable by another app, so
    // reusing it never actually worked on a real device (confirmed live).
    property bool pdfLoaded: false
    property string pdfImagePath: ""
    property real pdfPageWidthPt: 0
    property real pdfPageHeightPt: 0
    property string pdfErrorMessage: ""
    // 0-indexed, matches PdfFieldPlacement-equivalent field.page and
    // PdfPageRenderer. pdfPageCount starts at 1 so the page indicator has
    // something sane to show before the first render finishes.
    property int pdfPage: 0
    property int pdfPageCount: 1

    // Belt-and-suspenders alongside previewHost's own onWidthChanged below -
    // renderPage() itself is a no-op until previewHost has a real width either
    // way, so calling both is harmless.
    Component.onCompleted: page.renderPage(0)

    function renderPage(pageIndex) {
        if (previewHost.width <= 0) {
            return
        }
        page.pdfLoaded = false
        page.pdfErrorMessage = ""
        var localPath = documentFileEncoder.localPath(page.documentUrl)
        var result = pdfPageRenderer.renderPage(localPath, pageIndex, Math.round(previewHost.width))
        if (!result.ok) {
            console.log("NextSign PrepareDocumentPage render failed: " + result.error)
            page.pdfErrorMessage = result.error
            return
        }
        page.pdfImagePath = result.imagePath
        page.pdfPageWidthPt = result.pageWidthPt
        page.pdfPageHeightPt = result.pageHeightPt
        page.pdfPageCount = result.pageCount
        page.pdfLoaded = true
    }

    function goToPreviousPage() {
        if (page.pdfPage > 0) {
            page.pdfPage -= 1
            page.renderPage(page.pdfPage)
        }
    }

    function goToNextPage() {
        if (page.pdfPage < page.pdfPageCount - 1) {
            page.pdfPage += 1
            page.renderPage(page.pdfPage)
        }
    }

    // Always adds a brand new field for identify - never moves/overwrites an
    // existing one (see moveField for that, triggered by dragging a marker).
    // Tagged with whichever page is currently on screen, so arming someone
    // once and tapping each page in turn places one field per page for them.
    function addField(identify, leftPt, topPt) {
        var pageSize = page.pdfLoaded ? { "width": page.pdfPageWidthPt, "height": page.pdfPageHeightPt } : null
        var width = page.fieldBaseWidth
        var height = page.fieldBaseHeight
        var maxLeft = pageSize ? Math.max(0, pageSize.width - width) : leftPt
        var maxTop = pageSize ? Math.max(0, pageSize.height - height) : topPt
        var clampedLeft = Math.min(Math.max(leftPt, 0), maxLeft)
        var clampedTop = Math.min(Math.max(topPt, 0), maxTop)
        var id = "field_" + page.nextFieldId
        page.nextFieldId += 1
        var newField = { "id": id, "identify": identify, "left": clampedLeft, "top": clampedTop, "width": width, "height": height, "page": page.pdfPage }
        page.placedFields = page.placedFields.concat([newField])
        page.selectedFieldId = id
    }

    function moveField(fieldId, newLeftPt, newTopPt) {
        var updated = []
        for (var i = 0; i < page.placedFields.length; ++i) {
            var f = page.placedFields[i]
            if (f.id !== fieldId) {
                updated.push(f)
                continue
            }
            var pageSize = page.pdfLoaded ? { "width": page.pdfPageWidthPt, "height": page.pdfPageHeightPt } : null
            var maxLeft = pageSize ? Math.max(0, pageSize.width - f.width) : newLeftPt
            var maxTop = pageSize ? Math.max(0, pageSize.height - f.height) : newTopPt
            updated.push({
                "id": f.id,
                "identify": f.identify,
                "left": Math.min(Math.max(newLeftPt, 0), maxLeft),
                "top": Math.min(Math.max(newTopPt, 0), maxTop),
                "width": f.width,
                "height": f.height,
                "page": f.page
            })
        }
        page.placedFields = updated
    }

    function resizeField(fieldId, factor) {
        var updated = []
        for (var i = 0; i < page.placedFields.length; ++i) {
            var f = page.placedFields[i]
            if (f.id !== fieldId) {
                updated.push(f)
                continue
            }
            var centerX = f.left + f.width / 2
            var centerY = f.top + f.height / 2
            var newWidth = page.fieldBaseWidth * factor
            var newHeight = page.fieldBaseHeight * factor
            var pageSize = page.pdfLoaded ? { "width": page.pdfPageWidthPt, "height": page.pdfPageHeightPt } : null
            var maxLeft = pageSize ? Math.max(0, pageSize.width - newWidth) : centerX
            var maxTop = pageSize ? Math.max(0, pageSize.height - newHeight) : centerY
            updated.push({
                "id": f.id,
                "identify": f.identify,
                "left": Math.min(Math.max(centerX - newWidth / 2, 0), maxLeft),
                "top": Math.min(Math.max(centerY - newHeight / 2, 0), maxTop),
                "width": newWidth,
                "height": newHeight,
                "page": f.page
            })
        }
        page.placedFields = updated
    }

    function removeSigner(identify) {
        page.selectedSigners = page.selectedSigners.filter(function(s) { return s.identify !== identify })
        page.placedFields = page.placedFields.filter(function(f) { return f.identify !== identify })
        if (page.armedSignerIdentify === identify) {
            page.armedSignerIdentify = ""
        }
    }

    function addSigner(candidate) {
        var exists = page.selectedSigners.some(function(s) { return s.identify === candidate.identify })
        if (!exists) {
            page.selectedSigners = page.selectedSigners.concat([candidate])
        }
        page.armedSignerIdentify = candidate.identify
        page.signerSearchQuery = ""
        page.signerSearchResults = []
    }

    function submit() {
        var base64 = documentFileEncoder.fileToBase64(page.documentUrl)
        if (base64.length === 0) {
            page.submitErrorMessage = i18n.tr("Could not read the shared document.")
            return
        }
        var name = page.documentName.length > 0 ? page.documentName : i18n.tr("Untitled document")
        dataController.prepareDocument(name, base64, page.selectedSigners, page.placedFields, page.prepareServerUrl, page.prepareUserName, page.prepareSecret)
    }

    Item {
        anchors { fill: parent; topMargin: header.height }
        visible: page.showAccountSpinner

        ActivityIndicator {
            anchors.centerIn: parent
            running: parent.visible
        }
    }

    Item {
        anchors { fill: parent; topMargin: header.height }
        visible: page.showAccountPicker

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(2) }
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                font.bold: true
                wrapMode: Text.WordWrap
                text: i18n.tr("Which account should prepare this document?")
            }

            Repeater {
                model: page.knownAccounts
                delegate: Item {
                    Layout.fillWidth: true
                    implicitHeight: accountRowLabel.implicitHeight + units.gu(1.6)

                    Label {
                        id: accountRowLabel
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        text: modelData.displayName
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.chooseAccount(modelData)
                    }
                }
            }
        }
    }

    Item {
        anchors { fill: parent; topMargin: header.height }
        visible: page.showAccountError

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(2) }
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: theme.palette.normal.negative
                text: i18n.tr("Could not authorize this account. Try again.")
            }
            AppButton {
                text: i18n.tr("Try again")
                onClicked: {
                    page.accountAuthorizeFailed = false
                    if (page.chosenAccountEntry) {
                        page.chooseAccount(page.chosenAccountEntry)
                    }
                }
            }
        }
    }

    Flickable {
        anchors { fill: parent; topMargin: header.height; bottomMargin: page.oskOverlap }
        visible: page.showMainContent
        contentWidth: width
        contentHeight: mainColumn.height + units.gu(3)
        clip: true

        ColumnLayout {
            id: mainColumn
            width: parent.width
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(2) }
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Received \"%1\"").arg(page.documentName.length > 0 ? page.documentName : i18n.tr("Untitled document"))
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                visible: page.chosenAccountEntry !== null
                opacity: 0.72
                textSize: Label.Small
                text: page.chosenAccountEntry ? i18n.tr("Account: %1").arg(page.chosenAccountEntry.displayName) : ""
            }

            RowLayout {
                Layout.fillWidth: true
                visible: page.pdfPageCount > 1
                spacing: units.gu(2)

                Item { Layout.fillWidth: true }
                Icon {
                    name: "go-previous"
                    width: units.gu(2.5)
                    height: units.gu(2.5)
                    opacity: page.pdfPage > 0 ? 1.0 : 0.3
                    MouseArea {
                        anchors.fill: parent
                        enabled: page.pdfPage > 0
                        onClicked: page.goToPreviousPage()
                    }
                }
                Label {
                    text: i18n.tr("Page %1 of %2").arg(page.pdfPage + 1).arg(page.pdfPageCount)
                }
                Icon {
                    name: "go-next"
                    width: units.gu(2.5)
                    height: units.gu(2.5)
                    opacity: page.pdfPage < page.pdfPageCount - 1 ? 1.0 : 0.3
                    MouseArea {
                        anchors.fill: parent
                        enabled: page.pdfPage < page.pdfPageCount - 1
                        onClicked: page.goToNextPage()
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Item {
                id: previewHost
                Layout.fillWidth: true
                Layout.preferredHeight: pageContainer.visible ? pageContainer.height : units.gu(10)
                onWidthChanged: page.renderPage(page.pdfPage)

                Label {
                    width: previewHost.width
                    visible: page.pdfErrorMessage.length > 0
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.negative
                    text: page.pdfErrorMessage.length > 0 ? i18n.tr("Could not preview this PDF: %1").arg(page.pdfErrorMessage) : ""
                }

                ActivityIndicator {
                    visible: page.pdfErrorMessage.length === 0 && !page.pdfLoaded
                    running: visible
                }

                Item {
                    id: pageContainer
                    visible: page.pdfLoaded
                    width: parent.width
                    height: visible ? (page.pdfPageHeightPt * displayScale) : 0

                    readonly property real displayScale: (page.pdfLoaded && page.pdfPageWidthPt > 0 && width > 0)
                        ? width / page.pdfPageWidthPt
                        : 1

                    Image {
                        id: pageImage
                        anchors.fill: parent
                        fillMode: Image.Stretch
                        cache: false
                        source: pageContainer.visible ? "file://" + page.pdfImagePath : ""
                        sourceSize.width: Math.round(width)
                        sourceSize.height: Math.round(height)

                        MouseArea {
                            anchors.fill: parent
                            enabled: page.effectiveArmedSigner !== null
                            onClicked: {
                                if (!page.effectiveArmedSigner) {
                                    return
                                }
                                var ptX = mouse.x / pageContainer.displayScale - page.fieldBaseWidth / 2
                                var ptY = mouse.y / pageContainer.displayScale - page.fieldBaseHeight / 2
                                page.addField(page.effectiveArmedSigner.identify, ptX, ptY)
                            }
                        }
                    }

                    Repeater {
                        // Only the fields on the page currently shown - fields on
                        // other pages stay in page.placedFields untouched, they
                        // just aren't drawn/interactive here. Uses an explicit
                        // named property (page.currentPageFields) rather than an
                        // inline filter() here - a marker left behind on the
                        // wrong page after switching pages (this inline form's
                        // dependency tracking through the filter() callback was
                        // suspect) stayed interactive, and a single tap on it
                        // fired both onClicked (re-arms it) and onReleased
                        // (re-saves its position) together, firing a "move" the
                        // user never actually asked for - confirmed live.
                        model: page.currentPageFields
                        delegate: Item {
                            id: marker
                            property var field: modelData
                            x: field.left * pageContainer.displayScale
                            y: field.top * pageContainer.displayScale
                            width: field.width * pageContainer.displayScale
                            height: field.height * pageContainer.displayScale

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.12, 0.44, 0.91, 0.25)
                                border.width: units.dp(2)
                                border.color: "#1f6feb"
                            }
                            Label {
                                anchors { left: parent.left; top: parent.top; margins: units.gu(0.2) }
                                textSize: Label.XSmall
                                color: "#1f6feb"
                                elide: Text.ElideRight
                                width: parent.width - units.gu(0.4)
                                text: {
                                    for (var i = 0; i < page.selectedSigners.length; ++i) {
                                        if (page.selectedSigners[i].identify === marker.field.identify) return page.selectedSigners[i].displayName
                                    }
                                    return marker.field.identify
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                drag.target: marker
                                drag.minimumX: 0
                                drag.minimumY: 0
                                onClicked: {
                                    page.armedSignerIdentify = marker.field.identify
                                    page.selectedFieldId = marker.field.id
                                }
                                onReleased: {
                                    // Defensive guard, belt-and-suspenders alongside
                                    // currentPageFields above - a marker whose own
                                    // field.page no longer matches the displayed
                                    // page (a stale delegate from a page switch
                                    // landing between frames) must not re-save its
                                    // position onto the wrong page.
                                    if (marker.field.page !== page.pdfPage) {
                                        return
                                    }
                                    var newLeft = marker.x / pageContainer.displayScale
                                    var newTop = marker.y / pageContainer.displayScale
                                    page.moveField(marker.field.id, newLeft, newTop)
                                }
                                onPressAndHold: {
                                    page.pendingFieldRemovalId = marker.field.id
                                    PopupUtils.open(removeFieldConfirmDialog)
                                }
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: page.effectiveArmedSigner !== null
                textSize: Label.Small
                opacity: 0.72
                wrapMode: Text.WordWrap
                text: page.effectiveArmedSigner ? i18n.tr("Tap the document above to add a signature field for %1 - drag an existing field to move it, or long-press to remove it").arg(page.effectiveArmedSigner.displayName) : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Gated on the selected field actually being on the page shown
                // right now - otherwise this slider would float above a field
                // the user can't even see, which reads as the app being broken.
                visible: page.selectedField !== null && page.selectedField.page === page.pdfPage
                spacing: units.gu(0.3)

                readonly property real currentFactor: page.selectedField ? page.selectedField.width / page.fieldBaseWidth : 1

                Label {
                    textSize: Label.Small
                    opacity: 0.72
                    text: i18n.tr("Size: %1%").arg(Math.round(parent.currentFactor * 100))
                }
                Slider {
                    Layout.fillWidth: true
                    minimumValue: 0.5
                    maximumValue: 2.0
                    value: parent.currentFactor
                    onValueChanged: if (Math.abs(value - parent.currentFactor) > 0.01) page.resizeField(page.selectedFieldId, value)
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: units.gu(1)
                font.bold: true
                text: i18n.tr("Signers")
            }

            Repeater {
                model: page.selectedSigners
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)

                    MouseArea {
                        Layout.fillWidth: true
                        implicitHeight: signerColumn.implicitHeight
                        onClicked: page.armedSignerIdentify = modelData.identify

                        ColumnLayout {
                            id: signerColumn
                            width: parent.width
                            spacing: units.gu(0.1)
                            Label {
                                Layout.fillWidth: true
                                text: modelData.displayName
                                elide: Text.ElideRight
                                font.bold: modelData.identify === page.armedSignerIdentify
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                textSize: Label.Small
                                opacity: 0.72
                                elide: Text.ElideRight
                                text: {
                                    var parts = []
                                    if (modelData.subname && modelData.subname.length > 0) parts.push(modelData.subname)
                                    var fieldCount = page.placedFields.filter(function(f) { return f.identify === modelData.identify }).length
                                    if (fieldCount === 1) parts.push(i18n.tr("Field placed"))
                                    else if (fieldCount > 1) parts.push(i18n.tr("%1 fields placed").arg(fieldCount))
                                    return parts.join(" · ")
                                }
                            }
                        }
                    }
                    Icon {
                        name: "close"
                        Layout.preferredWidth: units.gu(2)
                        Layout.preferredHeight: units.gu(2)
                        color: theme.palette.normal.backgroundText
                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.removeSigner(modelData.identify)
                        }
                    }
                }
            }

            TextField {
                id: signerSearchField
                Layout.fillWidth: true
                Layout.topMargin: units.gu(0.5)
                placeholderText: i18n.tr("Search for a signer")
                // Predictive/composing text on the on-screen keyboard can delay
                // onTextChanged until a word is committed (space/enter/losing
                // focus) rather than firing per keystroke - turning it off makes
                // every keystroke commit immediately, so the debounced search
                // below actually runs while typing, not just after.
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: page.signerSearchQuery = text

                // text: page.signerSearchQuery further up would look simpler,
                // but QML silently drops that binding the first time the user
                // types a character (typing writes `text` imperatively) - so a
                // later `page.signerSearchQuery = ""` (after picking a signer)
                // would stop reaching this field. Clearing it explicitly here
                // works regardless of whether that binding is still alive.
                Connections {
                    target: page
                    onSignerSearchQueryChanged: {
                        if (page.signerSearchQuery.length === 0 && signerSearchField.text.length > 0) {
                            signerSearchField.text = ""
                        }
                    }
                }
            }

            ActivityIndicator {
                visible: dataController.searchingSigners
                running: visible
            }

            Label {
                Layout.fillWidth: true
                visible: !dataController.searchingSigners && page.signerSearchErrorMessage.length > 0
                color: theme.palette.normal.negative
                textSize: Label.Small
                wrapMode: Text.WordWrap
                text: page.signerSearchErrorMessage
            }

            Repeater {
                model: page.signerSearchResults
                delegate: MouseArea {
                    Layout.fillWidth: true
                    implicitHeight: resultColumn.implicitHeight + units.gu(1)
                    onClicked: page.addSigner(modelData)

                    ColumnLayout {
                        id: resultColumn
                        width: parent.width
                        spacing: units.gu(0.1)
                        Label { Layout.fillWidth: true; text: modelData.displayName; elide: Text.ElideRight }
                        Label {
                            Layout.fillWidth: true
                            visible: modelData.subname.length > 0
                            textSize: Label.Small
                            opacity: 0.72
                            elide: Text.ElideRight
                            text: modelData.subname
                        }
                    }
                }
            }

            AppButton {
                Layout.fillWidth: true
                Layout.topMargin: units.gu(2)
                Layout.bottomMargin: units.gu(2)
                variant: "primary"
                enabled: page.canSubmit
                text: dataController.preparingDocument ? i18n.tr("Sending...") : i18n.tr("Send for signing")
                onClicked: page.submit()
            }
        }
    }
}
