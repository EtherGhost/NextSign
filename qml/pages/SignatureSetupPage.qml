import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import UTControls 1.0
import "qrc:/NextCommon" as NextCommon

NextCommon.SettingsShell {
    id: page
    property var appController
    property var dataController

    title: i18n.tr("Signature")

    property bool hasSignature: "signature" in dataController.signatureElementsByType
    property string previewDataUri: ""
    property string errorMessage: ""

    Component.onCompleted: {
        if (page.hasSignature && dataController.signatureImagePreviewUrl.length === 0) {
            dataController.loadSignaturePreview()
        }
    }

    Connections {
        target: dataController
        onSignatureSetupSucceeded: {
            page.errorMessage = ""
        }
        onSignatureSetupFailed: function(message) {
            page.errorMessage = message
        }
    }

    NextCommon.SettingsCard {
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: page.hasSignature
                ? i18n.tr("You have a signature image set up. Documents with a visible signature field will use it when you sign.")
                : i18n.tr("Pick an image of your signature. Documents with a visible signature field will use it when you sign.")
        }

        // A signature image is transparent-background ink (see SignatureDrawPage.qml) -
        // without an opaque backdrop it's nearly invisible against this app's dark
        // theme. A fixed Layout.preferredWidth/Height (not plain width/height, which
        // Qt Quick Layouts can silently override on relayout - this broke visibly
        // across an orientation change) keeps the box stable; PreserveAspectFit scales
        // the image inside it without any manual size math.
        Rectangle {
            id: previewBackdrop
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: units.gu(30)
            Layout.preferredHeight: units.gu(18)
            visible: preview.status === Image.Ready
            color: "white"
            radius: units.gu(0.5)
            border.width: 1
            border.color: theme.palette.normal.base

            Image {
                id: preview
                anchors { fill: parent; margins: units.gu(1) }
                property string effectiveSource: page.previewDataUri.length > 0 ? page.previewDataUri : dataController.signatureImagePreviewUrl
                source: effectiveSource
                fillMode: Image.PreserveAspectFit
            }
        }

        ActivityIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: dataController.loadingSignaturePreview && preview.effectiveSource.length === 0
            visible: running
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: page.errorMessage.length > 0
            text: page.errorMessage
            color: "#b37a2a"
        }

        AppButton {
            Layout.fillWidth: true
            text: dataController.savingSignatureElement ? i18n.tr("Saving...") : i18n.tr("Draw signature")
            variant: "primary"
            enabled: !dataController.savingSignatureElement
            onClicked: page.openDrawPage()
        }

        AppButton {
            Layout.fillWidth: true
            text: dataController.savingSignatureElement ? i18n.tr("Saving...") : i18n.tr("Pick an image")
            variant: "normal"
            enabled: !dataController.savingSignatureElement
            onClicked: page.openPicker()
        }
    }

    function openPicker() {
        page.errorMessage = ""
        var picker = pageStack.push(Qt.resolvedUrl("SignatureImportPage.qml"))
        picker.fileSelected.connect(function(fileUrl, fileName) {
            pageStack.pop()
            page.handlePickedImage(fileUrl)
        })
        picker.importCanceled.connect(function() {
            pageStack.pop()
        })
        picker.importFailed.connect(function(message) {
            pageStack.pop()
            page.errorMessage = message
        })
    }

    function handlePickedImage(fileUrl) {
        if (typeof signatureImageEncoder === "undefined") {
            page.errorMessage = i18n.tr("Picking a signature image requires the native network backend.")
            return
        }

        var dataUri = signatureImageEncoder.toBase64DataUri(fileUrl.toString())
        if (dataUri.length === 0) {
            page.errorMessage = i18n.tr("Could not use the selected image. Try a smaller picture.")
            return
        }

        page.previewDataUri = dataUri
        dataController.createSignatureElement("signature", dataUri)
    }

    function openDrawPage() {
        page.errorMessage = ""
        var drawPage = pageStack.push(Qt.resolvedUrl("SignatureDrawPage.qml"))
        drawPage.drawingSaved.connect(function(dataUri) {
            pageStack.pop()
            page.previewDataUri = dataUri
            dataController.createSignatureElement("signature", dataUri)
        })
        drawPage.drawingCanceled.connect(function() {
            pageStack.pop()
        })
    }
}
