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

        Image {
            id: preview
            Layout.alignment: Qt.AlignHCenter
            property string effectiveSource: page.previewDataUri.length > 0 ? page.previewDataUri : dataController.signatureImagePreviewUrl
            visible: effectiveSource.length > 0
            source: effectiveSource
            fillMode: Image.PreserveAspectFit
            width: Math.min(implicitWidth, units.gu(30))
            height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
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
            text: dataController.savingSignatureElement
                ? i18n.tr("Saving...")
                : (page.hasSignature ? i18n.tr("Change signature image") : i18n.tr("Pick signature image"))
            variant: "primary"
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
}
