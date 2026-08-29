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

    // status: 1 = able to sign ("Ready to sign"), 3 = signed. See LibreSign's
    // file/list status[] parameter - other values (0=draft, 2=partial, 4=deleted)
    // are not used by this app.
    function loadFiles(serverUrl, userName, secret, status) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            failed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file/list?format=json&status[]=" + encodeURIComponent(status) + "&details=true"
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = 15000
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        xhr.setRequestHeader("OCS-APIRequest", "true")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            console.log("NextSign LibreSignApi file/list httpStatus=" + xhr.status)
            if (xhr.status === 404) {
                failed(i18n.tr("LibreSign does not appear to be installed on this Nextcloud server."), generation)
                return
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                failed(i18n.tr("LibreSign request failed with HTTP %1.").arg(xhr.status), generation)
                return
            }
            var files = LibreSignApiCore.parseFileList(xhr.responseText, status)
            if (files === null) {
                console.log("NextSign LibreSignApi file/list unexpected response=" + xhr.responseText.substring(0, 300))
                failed(i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            console.log("NextSign LibreSignApi file/list success count=" + files.length)
            loaded(files, generation)
        }
        xhr.onerror = function() {
            console.log("NextSign LibreSignApi file/list network error")
            failed(i18n.tr("LibreSign request failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            console.log("NextSign LibreSignApi file/list timeout")
            failed(i18n.tr("LibreSign request timed out."), generation)
        }
        xhr.send()
    }

    function signDocument(serverUrl, userName, secret, uuid) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            signFailed(uuid, i18n.tr("Account credentials are incomplete."), generation)
            return
        }

        var url = base + "/ocs/v2.php/apps/libresign/api/v1/sign/uuid/" + encodeURIComponent(uuid) + "?format=json"
        var xhr = new XMLHttpRequest()
        xhr.open("POST", url)
        xhr.timeout = 30000
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        xhr.setRequestHeader("OCS-APIRequest", "true")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            console.log("NextSign LibreSignApi sign httpStatus=" + xhr.status)
            if (xhr.status < 200 || xhr.status >= 300) {
                var message = LibreSignApiCore.extractErrorMessage(xhr.responseText) || i18n.tr("Signing failed with HTTP %1.").arg(xhr.status)
                signFailed(uuid, message, generation)
                return
            }
            console.log("NextSign LibreSignApi sign success")
            signed(uuid, generation)
        }
        xhr.onerror = function() {
            console.log("NextSign LibreSignApi sign network error")
            signFailed(uuid, i18n.tr("Signing failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            console.log("NextSign LibreSignApi sign timeout")
            signFailed(uuid, i18n.tr("Signing timed out."), generation)
        }
        // clickToSign only, by design - no password/code fallback.
        xhr.send(JSON.stringify({ "method": "clickToSign" }))
    }

    function validateFile(serverUrl, userName, secret, uuid) {
        var generation = requestGeneration
        var base = LibreSignApiCore.normalizeServerUrl(serverUrl)
        if (base.length === 0 || userName.length === 0 || secret.length === 0) {
            validateFailed(uuid, i18n.tr("Account credentials are incomplete."), generation)
            return
        }

        // Unlike sign/uuid/{uuid}, validate/uuid/{uuid} really does take the file's
        // own uuid - confirmed live, not the signer's sign_request_uuid.
        var url = base + "/ocs/v2.php/apps/libresign/api/v1/file/validate/uuid/" + encodeURIComponent(uuid) + "?format=json&showMessages=true"
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = 20000
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        xhr.setRequestHeader("OCS-APIRequest", "true")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            console.log("NextSign LibreSignApi validate httpStatus=" + xhr.status)
            if (xhr.status < 200 || xhr.status >= 300) {
                var message = LibreSignApiCore.extractErrorMessage(xhr.responseText) || i18n.tr("Validation failed with HTTP %1.").arg(xhr.status)
                validateFailed(uuid, message, generation)
                return
            }
            var summary = LibreSignApiCore.parseValidation(xhr.responseText)
            if (summary === null) {
                validateFailed(uuid, i18n.tr("LibreSign returned an unexpected response."), generation)
                return
            }
            validated(uuid, summary, generation)
        }
        xhr.onerror = function() {
            validateFailed(uuid, i18n.tr("Validation failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            validateFailed(uuid, i18n.tr("Validation timed out."), generation)
        }
        xhr.send()
    }
}
