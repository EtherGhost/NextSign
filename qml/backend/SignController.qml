import QtQuick 2.7
import Qt.labs.settings 1.0
import "qrc:/NextCommon" as NextCommon

Item {
    id: controller
    property bool loading: false
    property string statusText: i18n.tr("Select an account to load your documents.")
    property string syncStateText: i18n.tr("No account")
    property string syncStateColor: "#b37a2a"
    property string accountAvatarUrl: accountSettings.avatarUrl || ""
    property string activeAccountKey: ""
    property bool applyingAccountSelection: false
    property var documents: []
    property int accountRequestGeneration: 0
    property string currentServerUrl: ""
    property string currentUserName: ""
    property string currentSecret: ""
    property bool downloadingPreview: false
    property string signingUuid: ""
    property string validatingUuid: ""
    property bool savingSignatureElement: false
    // { "signature": nodeId, "initial": nodeId, ... } - the account's own registered
    // signature/initials images, needed alongside a document's placeholder position to
    // render a visible mark when signing. Empty until loadSignatureElements() returns.
    property var signatureElementsByType: ({})
    // Local file:// URL of the fetched signature preview image, if any - see
    // loadSignaturePreview(). Empty until explicitly requested (the signature setup
    // page does this) rather than eagerly on every account load.
    property string signatureImagePreviewUrl: ""
    property bool loadingSignaturePreview: false

    signal previewReady(url fileUrl, string suggestedName)
    signal previewFailed(string message)
    signal signSucceeded(string uuid)
    signal signFailed(string message)
    signal validationReady(var summary)
    signal validationFailed(string message)
    signal signatureSetupSucceeded()
    signal signatureSetupFailed(string message)

    // Prefer the starred (default) element of a type over an earlier one.
    function buildSignatureElementsByType(elements) {
        var byType = {}
        for (var i = 0; i < elements.length; ++i) {
            var element = elements[i]
            if (!(element.type in byType) || element.starred) {
                byType[element.type] = element.nodeId
            }
        }
        return byType
    }

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
        property string avatarUrl: ""

        onAccountIdChanged: if (!controller.applyingAccountSelection) controller.refresh()
        onProviderIdChanged: if (!controller.applyingAccountSelection) controller.refresh()
        onServiceIdChanged: if (!controller.applyingAccountSelection) controller.refresh()
        onServerUrlChanged: if (!controller.applyingAccountSelection) controller.refresh()
    }

    NextCommon.AccountSessionAdapter {
        id: session
        onAuthenticated: function(userName, secret, serverUrl, accountId, serviceId) {
            if (!controller.isCurrentAccountResponse(accountId, serviceId, serverUrl)) {
                console.log("NextSign SignController ignored stale auth response accountId=" + accountId + " serviceId=" + serviceId)
                return
            }
            var generation = controller.accountRequestGeneration
            controller.currentServerUrl = serverUrl
            controller.currentUserName = userName
            controller.currentSecret = secret
            controller.accountAvatarUrl = avatarUrl(serverUrl, userName)
            if (controller.accountAvatarUrl.length > 0) {
                accountSettings.avatarUrl = controller.accountAvatarUrl
            }
            controller.activeAccountKey = controller.accountKey()
            controller.statusText = i18n.tr("Signed in. Loading documents...")
            controller.syncStateText = i18n.tr("Syncing")
            controller.syncStateColor = "#2c7fb8"
            controller.signatureElementsByType = ({})
            controller.signatureImagePreviewUrl = ""
            api.requestGeneration = generation
            // Tags subsequent "NextSign LibreSignApi ..." log lines with which account
            // they belong to, so a device log can tell two accounts' requests apart.
            console.log("NextSign SignController authenticated userName=" + userName + " accountId=" + accountId + " generation=" + generation)
            api.loadFiles(serverUrl, userName, secret)
            api.loadSignatureElements(serverUrl, userName, secret)
        }
        onFailed: function(message) {
            controller.loading = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Authentication failed")
            controller.syncStateColor = "#b37a2a"
        }
    }

    LibreSignApiClient {
        id: api
        onLoaded: function(files, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.loading = false
            controller.documents = files
            controller.statusText = files.length > 0
                ? i18n.tr("%1 document(s).").arg(files.length)
                : i18n.tr("No documents yet.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
        }
        onFailed: function(message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.loading = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Sync failed")
            controller.syncStateColor = "#b37a2a"
        }
        onSigned: function(uuid, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.signingUuid = ""
            controller.signSucceeded(uuid)
            controller.refresh()
        }
        onSignFailed: function(uuid, message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.signingUuid = ""
            controller.signFailed(message)
        }
        onValidated: function(uuid, summary, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.validatingUuid = ""
            controller.validationReady(summary)
        }
        onValidateFailed: function(uuid, message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.validatingUuid = ""
            controller.validationFailed(message)
        }
        onSignatureElementsLoaded: function(elements, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.signatureElementsByType = controller.buildSignatureElementsByType(elements)
        }
        onSignatureElementsFailed: function(message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            console.log("NextSign SignController could not load signature elements: " + message)
        }
        onSignatureElementCreated: function(elements, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.savingSignatureElement = false
            controller.signatureElementsByType = controller.buildSignatureElementsByType(elements)
            controller.signatureSetupSucceeded()
        }
        onSignatureElementCreateFailed: function(message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.savingSignatureElement = false
            controller.signatureSetupFailed(message)
        }
    }

    Connections {
        target: typeof documentDownloader !== "undefined" ? documentDownloader : null
        onDownloaded: function(fileUrl, fileName, mimeType, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.downloadingPreview = false
            controller.previewReady(fileUrl, fileName)
        }
        onDownloadFailed: function(message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.downloadingPreview = false
            controller.previewFailed(message)
        }
        onImageDownloaded: function(fileUrl, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.loadingSignaturePreview = false
            controller.signatureImagePreviewUrl = fileUrl
        }
        onImageDownloadFailed: function(message, generation) {
            if (!controller.isCurrentGeneration(generation)) {
                return
            }
            controller.loadingSignaturePreview = false
            console.log("NextSign SignController could not load signature preview: " + message)
        }
    }

    function loadSignaturePreview() {
        if (!("signature" in controller.signatureElementsByType)) {
            return
        }
        if (controller.currentServerUrl.length === 0 || controller.currentUserName.length === 0 || controller.currentSecret.length === 0) {
            return
        }
        if (typeof documentDownloader === "undefined") {
            return
        }

        controller.loadingSignaturePreview = true
        var nodeId = controller.signatureElementsByType["signature"]
        var url = controller.currentServerUrl + "/ocs/v2.php/apps/libresign/api/v1/signature/elements/preview/" + nodeId
        documentDownloader.downloadImageToCache(controller.accountRequestGeneration, url, controller.currentUserName, controller.currentSecret)
    }

    function previewDocument(uuid) {
        var target = null
        for (var i = 0; i < documents.length; ++i) {
            if (documents[i].uuid === uuid) {
                target = documents[i]
                break
            }
        }
        if (!target || !target.filePath) {
            controller.previewFailed(i18n.tr("This document's location is unknown."))
            return
        }
        if (controller.currentServerUrl.length === 0 || controller.currentUserName.length === 0 || controller.currentSecret.length === 0) {
            controller.previewFailed(i18n.tr("Sign in again before viewing this document."))
            return
        }
        if (typeof documentDownloader === "undefined") {
            controller.previewFailed(i18n.tr("Document preview requires the native network backend."))
            return
        }

        controller.downloadingPreview = true
        documentDownloader.downloadToCache(
            controller.accountRequestGeneration,
            controller.currentServerUrl + target.filePath,
            controller.currentUserName,
            controller.currentSecret,
            target.name)
    }

    function signDocument(uuid) {
        var target = null
        for (var i = 0; i < documents.length; ++i) {
            if (documents[i].uuid === uuid) {
                target = documents[i]
                break
            }
        }
        if (!target || !target.signUuid) {
            controller.signFailed(i18n.tr("Could not determine your signature request for this document."))
            return
        }
        if (controller.currentServerUrl.length === 0 || controller.currentUserName.length === 0 || controller.currentSecret.length === 0) {
            controller.signFailed(i18n.tr("Sign in again before signing this document."))
            return
        }

        controller.signingUuid = uuid
        api.requestGeneration = controller.accountRequestGeneration
        api.signDocument(controller.currentServerUrl, controller.currentUserName, controller.currentSecret, target.signUuid, target.visibleElements, controller.signatureElementsByType)
    }

    function validateDocument(uuid) {
        var target = null
        for (var i = 0; i < documents.length; ++i) {
            if (documents[i].uuid === uuid) {
                target = documents[i]
                break
            }
        }
        if (!target) {
            controller.validationFailed(i18n.tr("This document's location is unknown."))
            return
        }
        if (controller.currentServerUrl.length === 0 || controller.currentUserName.length === 0 || controller.currentSecret.length === 0) {
            controller.validationFailed(i18n.tr("Sign in again before validating this document."))
            return
        }

        controller.validatingUuid = uuid
        api.requestGeneration = controller.accountRequestGeneration
        // validate/uuid/{uuid} takes the file's own uuid, not signUuid.
        api.validateFile(controller.currentServerUrl, controller.currentUserName, controller.currentSecret, uuid)
    }

    function createSignatureElement(elementType, base64DataUri) {
        if (controller.currentServerUrl.length === 0 || controller.currentUserName.length === 0 || controller.currentSecret.length === 0) {
            controller.signatureSetupFailed(i18n.tr("Sign in again before setting up your signature."))
            return
        }

        controller.savingSignatureElement = true
        api.requestGeneration = controller.accountRequestGeneration
        // Replace the existing image of this type in place rather than creating
        // another one - otherwise every pick just piles up a new duplicate element
        // server-side, none of them marked as the account's actual signature.
        if (elementType in controller.signatureElementsByType) {
            api.updateSignatureElement(controller.currentServerUrl, controller.currentUserName, controller.currentSecret,
                controller.signatureElementsByType[elementType], base64DataUri)
        } else {
            api.createSignatureElement(controller.currentServerUrl, controller.currentUserName, controller.currentSecret, elementType, base64DataUri)
        }
    }

    function refresh() {
        if (!hasCompleteAccountSettings()) {
            controller.statusText = i18n.tr("Select an account to load your documents.")
            controller.syncStateText = i18n.tr("No account")
            controller.syncStateColor = "#b37a2a"
            controller.documents = []
            return
        }

        controller.accountRequestGeneration += 1
        session.setAccount(effectiveAccountId(), effectiveProviderId(), effectiveServiceId(), effectiveServerUrl())
        controller.loading = true
        controller.statusText = i18n.tr("Verifying account...")
        controller.syncStateText = i18n.tr("Verifying")
        controller.syncStateColor = "#2c7fb8"
        session.authenticate()
    }

    function isCurrentGeneration(generation) {
        return Number(generation || 0) === Number(controller.accountRequestGeneration || 0)
    }

    function desktopTestAuthActive() {
        return typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
            && typeof desktopTestServerUrl !== "undefined" && String(desktopTestServerUrl || "").length > 0
    }

    function hasCompleteAccountSettings() {
        return desktopTestAuthActive() || accountSettings.accountId > 0
    }

    function effectiveAccountId() {
        return desktopTestAuthActive() ? -1 : accountSettings.accountId
    }

    function effectiveProviderId() {
        return desktopTestAuthActive() ? "desktop-test" : accountSettings.providerId
    }

    function effectiveServiceId() {
        return desktopTestAuthActive() ? "desktop-test-env" : accountSettings.serviceId
    }

    function effectiveServerUrl() {
        return desktopTestAuthActive() ? String(desktopTestServerUrl || "").replace(/\/+$/, "") : accountSettings.serverUrl
    }

    Component.onCompleted: {
        if (hasCompleteAccountSettings()) {
            controller.refresh()
        }
    }

    function applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        controller.applyingAccountSelection = true
        accountSettings.accountId = accountId
        accountSettings.displayName = displayName
        accountSettings.providerId = providerId
        accountSettings.serviceId = serviceId
        accountSettings.serverUrl = serverUrl
        accountSettings.avatarUrl = avatarUrl
        controller.applyingAccountSelection = false
        controller.refresh()
    }

    function accountKey() {
        return effectiveAccountId() + ":" + effectiveServiceId()
    }

    function isCurrentAccountResponse(accountId, serviceId, serverUrl) {
        if (desktopTestAuthActive() && Number(accountId || 0) === -1 && String(serviceId || "") === "desktop-test-env") {
            return true
        }
        return Number(accountId || 0) === Number(accountSettings.accountId || 0)
            && String(serviceId || "") === String(accountSettings.serviceId || "")
            && String(serverUrl || "").replace(/\/+$/, "") === String(accountSettings.serverUrl || "").replace(/\/+$/, "")
    }

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) {
            return ""
        }
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
    }
}
