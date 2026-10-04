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
    signal signatureElementCreated(var elements, int generation)
    signal signatureElementCreateFailed(string message, int generation)
    signal signersFound(var candidates, int generation)
    signal signersSearchFailed(string message, int generation)
    signal documentPrepared(var result, int generation)
    signal documentPrepareFailed(string message, int generation)
    // signRequestId/fileId echoed back (not just "it finished") so two of these
    // calls in flight at once - e.g. a rollback delete racing an unrelated
    // user-triggered delete - can be told apart, matching the sign:/validate:
    // requestId-suffix convention already used above.
    signal fileElementCreated(int signRequestId, int generation)
    signal fileElementCreateFailed(int signRequestId, string message, int generation)
    signal documentDeleted(int fileId, int generation)
    signal documentDeleteFailed(int fileId, string message, int generation)

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

    // base64DataUri: a "data:image/png;base64,..." string - see SignatureImageEncoder.
    function createSignatureElement(serverUrl, userName, secret, elementType, base64DataUri) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signatureElementCreateFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            signatureElementCreateFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }
        if (base64DataUri.length === 0) {
            signatureElementCreateFailed(i18n.tr("Could not read the selected image."), generation)
            return
        }

        var body = JSON.stringify({
            "elements": [
                { "type": elementType, "file": { "base64": base64DataUri } }
            ]
        })
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/signature/elements?format=json"
        libreSignNetwork.sendRequest(generation, "createSignatureElement:" + elementType, "POST", url, userName, secret, body, "application/json")
    }

    // Replaces an already-registered element's image in place (PATCH), rather than
    // creating another one of the same type - see updateSignatureElementNodeId in
    // SignController.qml for why this exists.
    function updateSignatureElement(serverUrl, userName, secret, nodeId, elementType, base64DataUri) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signatureElementCreateFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            signatureElementCreateFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }
        if (base64DataUri.length === 0) {
            signatureElementCreateFailed(i18n.tr("Could not read the selected image."), generation)
            return
        }

        // The server validates the element's "type" before it resolves elementId
        // from the nodeId in the URL, so type must be sent here even though the
        // update endpoint's own parameter documents it as optional - omitting it
        // fails with "Element needs a type" regardless.
        var body = JSON.stringify({ "type": elementType, "file": { "base64": base64DataUri } })
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/signature/elements/" + encodeURIComponent(nodeId) + "?format=json"
        libreSignNetwork.sendRequest(generation, "createSignatureElement:update", "PATCH", url, userName, secret, body, "application/json")
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

    function searchSigners(serverUrl, userName, secret, query) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signersSearchFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            signersSearchFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/identify-account/search?format=json&search=" + encodeURIComponent(query)
        libreSignNetwork.sendRequest(generation, "searchSigners", "GET", url, userName, secret, "", "")
    }

    // signers: [{ identify, displayName, method }] - selected via searchSigners().
    // fileName/base64: the shared PDF itself - uploaded in this same call, since a
    // PDF received via content-hub import has no Nextcloud node id to reuse.
    function requestSignature(serverUrl, userName, secret, fileName, base64, signers) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            documentPrepareFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            documentPrepareFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var requestSigners = []
        for (var i = 0; i < signers.length; ++i) {
            var signer = signers[i]
            requestSigners.push({
                "identifyMethods": [
                    { "method": signer.method, "value": signer.identify, "requirement": "required" }
                ],
                "displayName": signer.displayName
            })
        }
        var body = JSON.stringify({
            "file": { "base64": base64, "name": fileName },
            "name": fileName,
            "signers": requestSigners
        })
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/request-signature?format=json"
        libreSignNetwork.sendRequest(generation, "requestSignature", "POST", url, userName, secret, body, "application/json")
    }

    // coordinates: {page, left, top, width, height} - top/left/width/height
    // (screen-like, top-down), all Int - the server rejects a Float value outright
    // even for a whole number (e.g. "150.0"), confirmed live porting the Android app.
    function createFileElement(serverUrl, userName, secret, fileUuid, signRequestId, fileId, coordinates) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            fileElementCreateFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            fileElementCreateFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var body = JSON.stringify({
            "signRequestId": signRequestId,
            "fileId": fileId,
            "type": "signature",
            "coordinates": coordinates
        })
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file-element/" + encodeURIComponent(fileUuid) + "?format=json"
        libreSignNetwork.sendRequest(generation, "createFileElement:" + signRequestId, "POST", url, userName, secret, body, "application/json")
    }

    // Removes the sign request/preparation only - the underlying Nextcloud file
    // this app itself uploaded (via requestSignature's base64) isn't otherwise
    // touched by this call beyond that, confirmed live porting the Android app.
    function deleteFile(serverUrl, userName, secret, fileId) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            documentDeleteFailed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof libreSignNetwork === "undefined") {
            documentDeleteFailed(i18n.tr("LibreSign requires the native network backend."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file/file_id/" + encodeURIComponent(fileId) + "?format=json"
        libreSignNetwork.sendRequest(generation, "deleteFile:" + fileId, "DELETE", url, userName, secret, "", "")
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
                // Confirmed live (not guessed): when a LibreSign admin requires a
                // signature method other than clickToSign for Account signers (Email
                // token, Certificate with password), signing fails with exactly this
                // status - both alternatives tested, identical result either way. A
                // specific, honest (not overconfident) message beats the raw server
                // error text for this one common case.
                var signMessage = status === 422
                    ? i18n.tr("Your account may require a sign-in method (like an email code or certificate) that NextSign doesn't support yet. Try signing this document from the Nextcloud web interface instead.")
                    : (LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("Signing failed with HTTP %1.").arg(status))
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
        } else if (requestId.indexOf("createSignatureElement:") === 0) {
            if (status < 200 || status >= 300) {
                signatureElementCreateFailed(LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            var createdElements = LibreSignApiCore.parseSignatureElements(responseText)
            if (createdElements === null) {
                signatureElementCreateFailed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            console.log("NextSign LibreSignApi createSignatureElement parsed count=" + createdElements.length)
            signatureElementCreated(createdElements, generation)
        } else if (requestId === "searchSigners") {
            if (status < 200 || status >= 300) {
                signersSearchFailed(LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            var candidates = LibreSignApiCore.parseIdentifyAccountSearch(responseText)
            if (candidates === null) {
                signersSearchFailed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            signersFound(candidates, generation)
        } else if (requestId === "requestSignature") {
            if (status < 200 || status >= 300) {
                documentPrepareFailed(LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            var prepared = LibreSignApiCore.parseRequestSignatureResponse(responseText)
            if (prepared === null) {
                documentPrepareFailed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            documentPrepared(prepared, generation)
        } else if (requestId.indexOf("createFileElement:") === 0) {
            var elementSignRequestId = parseInt(requestId.substring("createFileElement:".length), 10)
            if (status < 200 || status >= 300) {
                fileElementCreateFailed(elementSignRequestId, LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            fileElementCreated(elementSignRequestId, generation)
        } else if (requestId.indexOf("deleteFile:") === 0) {
            var deletedFileId = parseInt(requestId.substring("deleteFile:".length), 10)
            if (status < 200 || status >= 300) {
                documentDeleteFailed(deletedFileId, LibreSignApiCore.extractErrorMessage(responseText) || i18n.tr("LibreSign request failed with HTTP %1.").arg(status), generation)
                return
            }
            documentDeleted(deletedFileId, generation)
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
        } else if (requestId.indexOf("createSignatureElement:") === 0) {
            signatureElementCreateFailed(message, generation)
        } else if (requestId === "searchSigners") {
            signersSearchFailed(message, generation)
        } else if (requestId === "requestSignature") {
            documentPrepareFailed(message, generation)
        } else if (requestId.indexOf("createFileElement:") === 0) {
            fileElementCreateFailed(parseInt(requestId.substring("createFileElement:".length), 10), message, generation)
        } else if (requestId.indexOf("deleteFile:") === 0) {
            documentDeleteFailed(parseInt(requestId.substring("deleteFile:".length), 10), message, generation)
        }
    }
}
