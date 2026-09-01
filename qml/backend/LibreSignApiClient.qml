import QtQuick 2.7
import "LibreSignApiCore.js" as LibreSignApiCore

Item {
    id: api
    property int requestGeneration: 0

    signal loaded(var files, int generation)
    signal failed(string message, int generation)
    signal signed(string uuid, int generation)
    signal signFailed(string uuid, string message, int generation)
    signal validated(string uuid, var summary, int generation)
    signal validateFailed(string uuid, string message, int generation)
    signal signatureElementsLoaded(var elements, int generation)
    signal signatureElementsFailed(string message, int generation)

    // Requests go through the native libreSignNetwork backend (an isolated
    // QNetworkAccessManager per request, with the account's username baked
    // into the request URL) rather than QML's XMLHttpRequest. Plain XHR
    // shares Qt's implicit global network stack across the whole app, which
    // can bleed session/auth state between two Ubuntu Touch Online Accounts
    // on the same Nextcloud server - the exact same bug class NextDeck and
    // NextTasks already hit and fixed the same way.
    Connections {
        target: typeof libreSignNetwork !== "undefined" ? libreSignNetwork : null
        onRequestFinished: function(requestId, status, responseText, generation) {
            api.handleFinished(requestId, status, responseText, generation)
        }
        onRequestFailed: function(requestId, message, generation) {
            api.handleFailed(requestId, message, generation)
        }
    }

    // One unified list, not a tab-filtered subset - requests every status a signer
    // might care about (1=ready to sign, 2=partially signed, 3=fully signed). See
    // parseFileList() in LibreSignApiCore.js for how each item then gets tagged with
    // its own status and "canSignNow" for display, mirroring LibreSign's own web UI.
    function loadFiles(serverUrl, userName, secret) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            failed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            failed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file/list?format=json&status[]=1&status[]=2&status[]=3&details=true"
        libreSignNetwork.sendRequest(generation, "loadFiles", "GET", url, userName, secret, "", "")
    }

    // profileNodeIdsByType: { "signature": nodeId, "initial": nodeId, ... } - the
    // signer's own registered signature/initials images, from loadSignatureElements().
    function signDocument(serverUrl, userName, secret, uuid, visibleElements, profileNodeIdsByType) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signFailed(uuid, i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            signFailed(uuid, i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        // Forward the placeholder position(s) already defined on the document for this
        // signer, together with the matching registered signature/initials image, so
        // LibreSign actually stamps a visible mark instead of only recording the
        // signature cryptographically. A placeholder without a registered image of the
        // same type is left out entirely - the server rejects the whole sign request if
        // it gets a documentElementId with no profileNodeId at all.
        var elements = []
        if (Array.isArray(visibleElements)) {
            for (var i = 0; i < visibleElements.length; ++i) {
                var visibleElement = visibleElements[i]
                var nodeId = profileNodeIdsByType && visibleElement ? profileNodeIdsByType[visibleElement.type] : undefined
                if (visibleElement && typeof visibleElement.elementId === "number" && typeof nodeId === "number") {
                    elements.push({ "documentElementId": visibleElement.elementId, "profileNodeId": nodeId })
                }
            }
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/sign/uuid/" + encodeURIComponent(uuid) + "?format=json"
        // clickToSign only, by design - no password/code fallback.
        libreSignNetwork.sendRequest(generation, "sign:" + uuid, "POST", url, userName, secret, JSON.stringify({ "method": "clickToSign", "elements": elements }), "application/json")
    }

    function loadSignatureElements(serverUrl, userName, secret) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signatureElementsFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            signatureElementsFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/signature/elements?format=json"
        libreSignNetwork.sendRequest(generation, "signatureElements", "GET", url, userName, secret, "", "")
    }

    function validateFile(serverUrl, userName, secret, uuid) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            validateFailed(uuid, i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            validateFailed(uuid, i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        // Unlike sign/uuid/{uuid}, validate/uuid/{uuid} really does take the file's
        // own uuid - confirmed live, not the signer's sign_request_uuid.
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file/validate/uuid/" + encodeURIComponent(uuid) + "?format=json&showMessages=true"
        libreSignNetwork.sendRequest(generation, "validate:" + uuid, "GET", url, userName, secret, "", "")
    }

    function handleFinished(requestId, status, responseText, generation) {
        console.log("NextSign LibreSignApi " + requestId + " httpStatus=" + status)
        if (requestId === "loadFiles") {
            if (status === 404) {
                failed(i18n.tr("LibreSign does not appear to be installed on this Nextcloud server."), generation)
                return
            }
            if (status < 200 || status >= 300) {
                failed(i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            var files = LibreSignApiCore.parseFileList(responseText)
            if (files === null) {
                console.log("NextSign LibreSignApi loadFiles unexpected response=" + responseText.substring(0, 300))
                failed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            console.log("NextSign LibreSignApi file/list success count=" + files.length)
            loaded(files, generation)
        } else if (requestId.indexOf("sign:") === 0) {
            var signUuid = requestId.substring("sign:".length)
            if (status < 200 || status >= 300) {
                var signMessage = LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("Signing failed with HTTP %1.").arg(status)
                signFailed(signUuid, signMessage, generation)
                return
            }
            signed(signUuid, generation)
        } else if (requestId.indexOf("validate:") === 0) {
            var validateUuid = requestId.substring("validate:".length)
            if (status < 200 || status >= 300) {
                var validateMessage = LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("Validation failed with HTTP %1.").arg(status)
                validateFailed(validateUuid, validateMessage, generation)
                return
            }
            var summary = LibreSignApiCore.parseValidation(responseText)
            if (summary === null) {
                validateFailed(validateUuid, i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            validated(validateUuid, summary, generation)
        } else if (requestId === "signatureElements") {
            if (status < 200 || status >= 300) {
                signatureElementsFailed(LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            var elements = LibreSignApiCore.parseSignatureElements(responseText)
            if (elements === null) {
                signatureElementsFailed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            signatureElementsLoaded(elements, generation)
        }
    }

    function handleFailed(requestId, message, generation) {
        console.log("NextSign LibreSignApi " + requestId + " network error: " + message)
        if (requestId === "loadFiles") {
            failed(message, generation)
        } else if (requestId.indexOf("sign:") === 0) {
            signFailed(requestId.substring("sign:".length), message, generation)
        } else if (requestId.indexOf("validate:") === 0) {
            validateFailed(requestId.substring("validate:".length), message, generation)
        } else if (requestId === "signatureElements") {
            signatureElementsFailed(message, generation)
        }
    }
}
