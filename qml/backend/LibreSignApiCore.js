.pragma library

function normalizeServerUrl(value) {
    if (!value) {
        return ""
    }
    var url = String(value).trim()
    while (url.length > 0 && url.charAt(url.length - 1) === "/") {
        url = url.slice(0, -1)
    }
    if (url.length === 0) {
        return ""
    }
    if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
        return url
    }
    return "https://" + url
}

// status: 1 = able to sign ("Ready to sign"), 3 = signed. See LibreSign's
// file/list status[] parameter - other values (0=draft, 2=partial, 4=deleted)
// are not used by this app.
function parseFileList(responseText, status) {
    try {
        var payload = JSON.parse(responseText)
        var data = payload && payload.ocs && payload.ocs.data ? payload.ocs.data : null
        if (!data || !Array.isArray(data.data)) {
            return null
        }

        var result = []
        for (var i = 0; i < data.data.length; ++i) {
            var item = data.data[i]
            // canSign only exists on the lightweight (non-detailed) response shape - the
            // server-side status[]= filter already means the right thing here, so that's
            // the authoritative check, not a client-side canSign field that details=true
            // responses don't even include.
            if (!item || item.status !== status) {
                continue
            }
            var firstFile = Array.isArray(item.files) && item.files.length > 0 ? item.files[0] : null
            var mySigner = null
            if (Array.isArray(item.signers)) {
                for (var s = 0; s < item.signers.length; ++s) {
                    if (item.signers[s] && item.signers[s].me === true) {
                        mySigner = item.signers[s]
                        break
                    }
                }
            }
            result.push({
                "uuid": item.uuid || "",
                // sign/uuid/{uuid} does NOT take the file's own uuid, despite what
                // LibreSign's own API docs say ("UUID of LibreSign file") - confirmed
                // live against a real instance, the file uuid is rejected as invalid
                // and the signer's own sign_request_uuid is what's actually required.
                "signUuid": mySigner && mySigner.sign_request_uuid ? mySigner.sign_request_uuid : "",
                "name": item.name || "",
                "requestedBy": item.requested_by && item.requested_by.displayName ? item.requested_by.displayName : "",
                "createdAt": item.created_at || "",
                "signedAt": mySigner && mySigner.signed ? mySigner.signed : "",
                "filePath": firstFile && firstFile.file ? firstFile.file : ""
            })
        }
        return result
    } catch (e) {
        return null
    }
}

function parseValidation(responseText) {
    try {
        var payload = JSON.parse(responseText)
        var data = payload && payload.ocs && payload.ocs.data ? payload.ocs.data : null
        if (!data) {
            return null
        }

        var signers = []
        if (Array.isArray(data.signers)) {
            for (var i = 0; i < data.signers.length; ++i) {
                var signer = data.signers[i]
                if (!signer) {
                    continue
                }
                signers.push({
                    "displayName": signer.displayName || "",
                    "signed": signer.signed || "",
                    "signatureLabel": signer.signature_validation && signer.signature_validation.label ? signer.signature_validation.label : "",
                    "certificateLabel": signer.certificate_validation && signer.certificate_validation.label ? signer.certificate_validation.label : ""
                })
            }
        }

        return {
            "statusText": data.statusText || "",
            "signers": signers
        }
    } catch (e) {
        return null
    }
}

function extractErrorMessage(responseText) {
    try {
        var payload = JSON.parse(responseText)
        var data = payload && payload.ocs && payload.ocs.data ? payload.ocs.data : null
        if (data && typeof data.message === "string" && data.message.length > 0) {
            return data.message
        }
        if (Array.isArray(data && data.errors) && data.errors.length > 0 && data.errors[0].message) {
            return data.errors[0].message
        }
        var meta = payload && payload.ocs && payload.ocs.meta ? payload.ocs.meta : null
        if (meta && typeof meta.message === "string" && meta.message.length > 0) {
            return meta.message
        }
    } catch (e) {
        // fall through to null
    }
    return null
}
