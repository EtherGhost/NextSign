import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import UTControls 1.0
import "../backend"

// Document preparation, ported from the Android app (see the feasibility doc):
// pick up a PDF shared in via content-hub (see DocumentShareImportHandlerUbuntu.qml
// and HomePage.qml), preview page 1, search for and select signers (generic
// search, no identify-method filter - same decision as Android), tap to place /
// drag to move / a slider to resize one signature field per signer, then submit.
// No multi-account picker needed here, unlike Android - this app only ever has
// one active account at a time (see SignController.qml).
Page {
    id: page
    title: i18n.tr("Prepare document")

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

    property var selectedSigners: []
    property var placedFields: ({})
    property string armedSignerIdentify: ""
    property string signerSearchQuery: ""
    property var signerSearchResults: []

    readonly property var effectiveArmedSigner: {
        for (var i = 0; i < selectedSigners.length; ++i) {
            if (selectedSigners[i].identify === armedSignerIdentify) {
                return selectedSigners[i]
            }
        }
        for (i = 0; i < selectedSigners.length; ++i) {
            if (!(selectedSigners[i].identify in placedFields)) {
                return selectedSigners[i]
            }
        }
        return selectedSigners.length > 0 ? selectedSigners[selectedSigners.length - 1] : null
    }

    readonly property bool canSubmit: !dataController.preparingDocument
        && selectedSigners.length > 0
        && selectedSigners.every(function(s) { return s.identify in placedFields })

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
            dataController.searchSigners(page.signerSearchQuery)
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

    // --- PDF preview, loaded defensively - see PopplerPdfPreview.qml for why. ---
    property var pdfPreview: null
    property bool pdfModuleUnavailable: false
    property string pdfErrorMessage: ""

    Component.onCompleted: {
        var component = Qt.createComponent(Qt.resolvedUrl("../components/PopplerPdfPreview.qml"))
        if (component.status === Component.Error) {
            console.log("NextSign PrepareDocumentPage poppler component error: " + component.errorString())
            page.pdfModuleUnavailable = true
            return
        }
        page.attachPreview(component)
    }

    function attachPreview(component) {
        var instance = component.createObject(previewHost, { "path": documentFileEncoder.localPath(page.documentUrl) })
        if (instance === null) {
            console.log("NextSign PrepareDocumentPage poppler createObject failed: " + component.errorString())
            page.pdfModuleUnavailable = true
            return
        }
        page.pdfPreview = instance
        instance.pdfError.connect(function(message) {
            page.pdfErrorMessage = message
        })
    }

    function placeOrMoveField(identify, leftPt, topPt) {
        var existing = page.placedFields[identify]
        var width = existing ? existing.width : page.fieldBaseWidth
        var height = existing ? existing.height : page.fieldBaseHeight
        var pageSize = page.pdfPreview && page.pdfPreview.pages.length > 0 ? page.pdfPreview.pages[0].size : null
        var maxLeft = pageSize ? Math.max(0, pageSize.width - width) : leftPt
        var maxTop = pageSize ? Math.max(0, pageSize.height - height) : topPt
        var clampedLeft = Math.min(Math.max(leftPt, 0), maxLeft)
        var clampedTop = Math.min(Math.max(topPt, 0), maxTop)
        var updated = {}
        for (var key in page.placedFields) updated[key] = page.placedFields[key]
        updated[identify] = { "left": clampedLeft, "top": clampedTop, "width": width, "height": height }
        page.placedFields = updated
        page.armedSignerIdentify = identify
    }

    function resizeArmedField(factor) {
        var identify = page.effectiveArmedSigner ? page.effectiveArmedSigner.identify : ""
        var existing = page.placedFields[identify]
        if (!existing) {
            return
        }
        var centerX = existing.left + existing.width / 2
        var centerY = existing.top + existing.height / 2
        var newWidth = page.fieldBaseWidth * factor
        var newHeight = page.fieldBaseHeight * factor
        var pageSize = page.pdfPreview && page.pdfPreview.pages.length > 0 ? page.pdfPreview.pages[0].size : null
        var maxLeft = pageSize ? Math.max(0, pageSize.width - newWidth) : centerX
        var maxTop = pageSize ? Math.max(0, pageSize.height - newHeight) : centerY
        var updated = {}
        for (var key in page.placedFields) updated[key] = page.placedFields[key]
        updated[identify] = {
            "left": Math.min(Math.max(centerX - newWidth / 2, 0), maxLeft),
            "top": Math.min(Math.max(centerY - newHeight / 2, 0), maxTop),
            "width": newWidth,
            "height": newHeight
        }
        page.placedFields = updated
    }

    function removeSigner(identify) {
        page.selectedSigners = page.selectedSigners.filter(function(s) { return s.identify !== identify })
        var updated = {}
        for (var key in page.placedFields) {
            if (key !== identify) updated[key] = page.placedFields[key]
        }
        page.placedFields = updated
        if (page.armedSignerIdentify === identify) {
            page.armedSignerIdentify = ""
        }
    }

    function addSigner(candidate) {
        var exists = page.selectedSigners.some(function(s) { return s.identify === candidate.identify })
        if (!exists) {
            page.selectedSigners = page.selectedSigners.concat([candidate])
        }
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
        dataController.prepareDocument(name, base64, page.selectedSigners, page.placedFields)
    }

    Flickable {
        anchors { fill: parent; topMargin: header.height }
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

            Item {
                id: previewHost
                Layout.fillWidth: true
                Layout.preferredHeight: pageContainer.visible ? pageContainer.height : units.gu(10)

                Label {
                    visible: page.pdfModuleUnavailable
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.negative
                    text: i18n.tr("This device cannot preview PDFs - the PDF viewer component isn't installed.")
                }

                Label {
                    visible: !page.pdfModuleUnavailable && page.pdfErrorMessage.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.negative
                    text: page.pdfErrorMessage.length > 0 ? i18n.tr("Could not preview this PDF: %1").arg(page.pdfErrorMessage) : ""
                }

                ActivityIndicator {
                    visible: !page.pdfModuleUnavailable && page.pdfErrorMessage.length === 0 && (!page.pdfPreview || !page.pdfPreview.pdfLoaded)
                    running: visible
                }

                Item {
                    id: pageContainer
                    visible: page.pdfPreview && page.pdfPreview.pdfLoaded && page.pdfPreview.pages.length > 0
                    width: parent.width
                    height: visible ? (page.pdfPreview.pages[0].size.height * displayScale) : 0

                    readonly property real displayScale: (page.pdfPreview && page.pdfPreview.pages.length > 0 && width > 0)
                        ? width / page.pdfPreview.pages[0].size.width
                        : 1

                    Image {
                        id: pageImage
                        anchors.fill: parent
                        fillMode: Image.Stretch
                        cache: false
                        source: pageContainer.visible ? page.pdfPreview.pages[0].image : ""
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
                                page.placeOrMoveField(page.effectiveArmedSigner.identify, ptX, ptY)
                            }
                        }
                    }

                    Repeater {
                        model: Object.keys(page.placedFields)
                        delegate: Item {
                            id: marker
                            property string identify: modelData
                            property var field: page.placedFields[identify]
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
                                        if (page.selectedSigners[i].identify === marker.identify) return page.selectedSigners[i].displayName
                                    }
                                    return marker.identify
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                drag.target: marker
                                drag.minimumX: 0
                                drag.minimumY: 0
                                onClicked: page.armedSignerIdentify = marker.identify
                                onReleased: {
                                    var newLeft = marker.x / pageContainer.displayScale
                                    var newTop = marker.y / pageContainer.displayScale
                                    page.placeOrMoveField(marker.identify, newLeft, newTop)
                                }
                            }
                        }
                    }
                }

                Component.onDestruction: if (page.pdfPreview) page.pdfPreview.destroy()
            }

            Label {
                Layout.fillWidth: true
                visible: page.effectiveArmedSigner !== null
                textSize: Label.Small
                opacity: 0.72
                wrapMode: Text.WordWrap
                text: page.effectiveArmedSigner ? i18n.tr("Tap the document above to place or move the signature field for %1").arg(page.effectiveArmedSigner.displayName) : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.effectiveArmedSigner !== null && (page.effectiveArmedSigner.identify in page.placedFields)
                spacing: units.gu(0.3)

                readonly property real currentFactor: {
                    var identify = page.effectiveArmedSigner ? page.effectiveArmedSigner.identify : ""
                    var field = page.placedFields[identify]
                    return field ? field.width / page.fieldBaseWidth : 1
                }

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
                    onValueChanged: if (Math.abs(value - parent.currentFactor) > 0.01) page.resizeArmedField(value)
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
                                    if (modelData.identify in page.placedFields) parts.push(i18n.tr("Field placed"))
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
                Layout.fillWidth: true
                Layout.topMargin: units.gu(0.5)
                placeholderText: i18n.tr("Search for a signer")
                text: page.signerSearchQuery
                onTextChanged: page.signerSearchQuery = text
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
