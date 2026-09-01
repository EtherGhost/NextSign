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

// Returns every document across the statuses loadFiles() asked for (1=ready to sign,
// 2=partially signed, 3=fully signed), each tagged with its own file-level status and
// full signer list - a single unified list mirroring LibreSign's own web UI, rather
// than a tab-filtered subset. A multi-signer document's file-level status advances to
// 2 the moment ANY signer finishes, not just the current one, so "can I sign this
// right now" is decided per-signer ("canSignNow": mySigner exists and hasn't signed
// yet), not by trusting the document's overall status.
function parseFileList(responseText) {
    try {
        var payload = JSON.parse(responseText)
        var data = payload && payload.ocs && payload.ocs.data ? payload.ocs.data : null
        if (!data || !Array.isArray(data.data)) {
            return null
        }

        var result = []
        for (var i = 0; i < data.data.length; ++i) {
            var item = data.data[i]
            if (!item) {
                continue
            }
            var mySigner = null
            var signers = []
            if (Array.isArray(item.signers)) {
                for (var s = 0; s < item.signers.length; ++s) {
                    var signer = item.signers[s]
                    if (!signer) {
                        continue
                    }
                    if (signer.me === true) {
                        mySigner = signer
                    }
                    signers.push({
                        "displayName": signer.displayName || "",
                        "signed": signer.signed || "",
                        "me": signer.me === true
                    })
                }
            }
            var firstFile = Array.isArray(item.files) && item.files.length > 0 ? item.files[0] : null
            var visibleElements = []
            if (mySigner && Array.isArray(mySigner.visibleElements)) {
                for (var v = 0; v < mySigner.visibleElements.length; ++v) {
                    var visibleElement = mySigner.visibleElements[v]
                    if (visibleElement && typeof visibleElement.elementId === "number") {
                        visibleElements.push({
                            "elementId": visibleElement.elementId,
                            "type": visibleElement.type || ""
                        })
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
                "filePath": firstFile && firstFile.file ? firstFile.file : "",
                // Raw file-level status (0=draft, 1=ready to sign, 2=partially signed,
                // 3=fully signed, 4=deleted) - only 1/2/3 are ever requested/shown.
                "fileStatus": typeof item.status === "number" ? item.status : -1,
                "canSignNow": !!mySigner && !mySigner.signed,
                "signers": signers,
                // Placeholder position(s) already defined on the document for this signer
                // (set up when the document was sent for signing). Without forwarding these
                // as "documentElementId" (plus a matching "profileNodeId" - see
                // parseSignatureElements) in the sign request, LibreSign records the
                // signature with no visible mark - see sign/uuid/{uuid} in LibreSignApiClient.qml.
                "visibleElements": visibleElements
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

// GET signature/elements returns the signer's own registered signature/initials
// images (set up via LibreSign's web UI, or elsewhere) - each one's Nextcloud file
// node id is the "profileNodeId" the sign request needs alongside a documentElementId
// to actually render that image, rather than just recording the signature.
function parseSignatureElements(responseText) {
    try {
        var payload = JSON.parse(responseText)
        var data = payload && payload.ocs && payload.ocs.data ? payload.ocs.data : null
        if (!data || !Array.isArray(data.elements)) {
            return null
        }

        var result = []
        for (var i = 0; i < data.elements.length; ++i) {
            var element = data.elements[i]
            if (!element || !element.file || typeof element.file.nodeId !== "number") {
                continue
            }
            result.push({
                "type": element.type || "",
                "nodeId": element.file.nodeId,
                "starred": element.starred === true
            })
        }
        return result
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
