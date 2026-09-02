import json
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "qml/backend/LibreSignApiCore.js"


def run_js(expression):
    expression_source = json.dumps(f"JSON.stringify({expression})")
    script = textwrap.dedent(
        f"""
        const fs = require("fs");
        const vm = require("vm");
        const path = "{MODULE.as_posix()}";
        const source = fs.readFileSync(path, "utf8").replace(/^\\.pragma library\\s*/, "");
        const context = {{}};
        vm.createContext(context);
        vm.runInContext(source, context, {{ filename: path }});
        const result = vm.runInContext({expression_source}, context);
        console.log(result);
        """
    )
    completed = subprocess.run(
        ["node", "-e", script],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return json.loads(completed.stdout)


class NormalizeServerUrlTests(unittest.TestCase):
    def test_adds_scheme_strips_trailing_slashes_keeps_existing_scheme(self):
        result = run_js(
            """({
                bare: normalizeServerUrl("cloudsite.se///"),
                httpsAlready: normalizeServerUrl("https://cloudsite.se/"),
                empty: normalizeServerUrl(""),
                nullish: normalizeServerUrl(null)
            })"""
        )

        self.assertEqual(result["bare"], "https://cloudsite.se")
        self.assertEqual(result["httpsAlready"], "https://cloudsite.se")
        self.assertEqual(result["empty"], "")
        self.assertEqual(result["nullish"], "")


class ParseFileListTests(unittest.TestCase):
    def test_extracts_fields_including_full_signer_list(self):
        # Real shape confirmed live against cloudsite.se, trimmed to what parseFileList reads.
        response = json.dumps({
            "ocs": {
                "data": {
                    "data": [
                        {
                            "uuid": "9bf681c2-285c-4f8f-aaea-e12688f708d9",
                            "name": "Itinerary",
                            "status": 1,
                            "requested_by": {"displayName": "Tobias Johansson"},
                            "created_at": "2026-08-29T20:15:34+00:00",
                            "files": [{"file": "/apps/libresign/p/pdf/9bf681c2-285c-4f8f-aaea-e12688f708d9"}],
                            "signers": [
                                {
                                    "me": True,
                                    "displayName": "Tobias Johansson",
                                    "sign_request_uuid": "7854ce90-0ea6-4525-b0a9-687bc7ab463b",
                                    "signed": None,
                                    "description": "Please sign before Friday",
                                    "visibleElements": [
                                        {
                                            "elementId": 42,
                                            "signRequestId": 7,
                                            "fileId": 3,
                                            "type": "signature",
                                            "coordinates": {"page": 1, "left": 10, "top": 20, "width": 200, "height": 50},
                                        },
                                    ],
                                },
                                {"me": False, "displayName": "Other Signer", "sign_request_uuid": "other-signer-uuid", "signed": "2026-08-30T09:00:00+00:00"},
                            ],
                        },
                    ]
                }
            }
        })

        result = run_js(f'parseFileList({json.dumps(response)})')

        self.assertEqual(len(result), 1)
        entry = result[0]
        self.assertEqual(entry["uuid"], "9bf681c2-285c-4f8f-aaea-e12688f708d9")
        # This is the field the sign action actually needs - see the comment in
        # LibreSignApiCore.js about LibreSign's own (wrong) API docs for this param.
        self.assertEqual(entry["signUuid"], "7854ce90-0ea6-4525-b0a9-687bc7ab463b")
        self.assertEqual(entry["requestedBy"], "Tobias Johansson")
        self.assertEqual(entry["filePath"], "/apps/libresign/p/pdf/9bf681c2-285c-4f8f-aaea-e12688f708d9")
        self.assertEqual(entry["signedAt"], "")
        self.assertEqual(entry["fileStatus"], 1)
        self.assertTrue(entry["canSignNow"])
        self.assertEqual(entry["messageForMe"], "Please sign before Friday")
        # The placeholder position(s) already defined for this signer - forwarded as
        # "documentElementId" when signing so LibreSign renders a visible mark.
        self.assertEqual(entry["visibleElements"], [{"elementId": 42, "type": "signature"}])
        # Full signer list, for the row-tap detail view - not just my own entry.
        self.assertEqual(entry["signers"], [
            {"displayName": "Tobias Johansson", "signed": "", "me": True},
            {"displayName": "Other Signer", "signed": "2026-08-30T09:00:00+00:00", "me": False},
        ])

    def test_returns_none_for_malformed_response(self):
        result = run_js('parseFileList("not json")')
        self.assertIsNone(result)

        result = run_js('parseFileList(JSON.stringify({"ocs": {}}))')
        self.assertIsNone(result)

    def test_visible_elements_default_to_empty_when_none_defined(self):
        response = json.dumps({
            "ocs": {
                "data": {
                    "data": [
                        {
                            "uuid": "no-elements",
                            "status": 1,
                            "files": [],
                            "signers": [{"me": True, "sign_request_uuid": "x"}],
                        },
                    ]
                }
            }
        })

        result = run_js(f'parseFileList({json.dumps(response)})')

        self.assertEqual(result[0]["visibleElements"], [])
        self.assertEqual(result[0]["messageForMe"], "")

    def test_can_sign_now_reflects_whether_i_have_signed_my_part(self):
        # Confirmed live: a multi-signer document's file-level status advances to 2
        # ("partial") the moment ANY signer finishes - not just when the current signer
        # does. So "can I sign this right now" must be decided per-signer, not by
        # trusting the document's overall status.
        response = json.dumps({
            "ocs": {
                "data": {
                    "data": [
                        {
                            "uuid": "partial-not-me-yet",
                            "status": 2,
                            "files": [],
                            "signers": [
                                {"me": True, "sign_request_uuid": "mine", "signed": None},
                                {"me": False, "sign_request_uuid": "other", "signed": "2026-08-30T10:00:00+00:00"},
                            ],
                        },
                        {
                            "uuid": "partial-already-signed-by-me",
                            "status": 2,
                            "files": [],
                            "signers": [
                                {"me": True, "sign_request_uuid": "mine2", "signed": "2026-08-30T10:05:00+00:00"},
                                {"me": False, "sign_request_uuid": "other2", "signed": None},
                            ],
                        },
                    ]
                }
            }
        })

        result = run_js(f'parseFileList({json.dumps(response)})')

        self.assertEqual(len(result), 2)
        by_uuid = {entry["uuid"]: entry for entry in result}
        self.assertTrue(by_uuid["partial-not-me-yet"]["canSignNow"])
        self.assertFalse(by_uuid["partial-already-signed-by-me"]["canSignNow"])


class ParseSignatureElementsTests(unittest.TestCase):
    def test_extracts_type_and_node_id_skipping_entries_without_a_file_node(self):
        # Real shape from GET signature/elements - only the fields parseSignatureElements reads.
        response = json.dumps({
            "ocs": {
                "data": {
                    "elements": [
                        {
                            "id": 1,
                            "type": "signature",
                            "file": {"url": "/index.php/f/123", "nodeId": 123},
                            "userId": "tobbe",
                            "starred": True,
                            "createdAt": "2026-06-01T10:00:00+00:00",
                        },
                        {
                            "id": 2,
                            "type": "initial",
                            "file": {"url": "/index.php/f/124", "nodeId": 124},
                            "userId": "tobbe",
                            "starred": False,
                            "createdAt": "2026-06-01T10:01:00+00:00",
                        },
                        # Malformed entry - must be skipped, not crash the whole parse.
                        {"id": 3, "type": "signature"},
                    ]
                }
            }
        })

        result = run_js(f'parseSignatureElements({json.dumps(response)})')

        self.assertEqual(result, [
            {"type": "signature", "nodeId": 123, "starred": True},
            {"type": "initial", "nodeId": 124, "starred": False},
        ])

    def test_returns_none_for_malformed_response(self):
        result = run_js('parseSignatureElements("not json")')
        self.assertIsNone(result)

        result = run_js('parseSignatureElements(JSON.stringify({"ocs": {}}))')
        self.assertIsNone(result)


class ParseValidationTests(unittest.TestCase):
    def test_extracts_status_and_per_signer_verdict_labels(self):
        # Trimmed from the real (much larger) validate/uuid/{uuid} response - only the
        # fields parseValidation actually reads.
        response = json.dumps({
            "ocs": {
                "data": {
                    "statusText": "Signerad",
                    "signers": [
                        {
                            "displayName": "NextNotesTestAccount",
                            "signed": "2026-08-29T21:12:09+00:00",
                            "signature_validation": {"id": 1, "label": "Signaturen är giltig."},
                            "certificate_validation": {"id": 1, "label": "Certifikatet är pålitligt."},
                        }
                    ],
                }
            }
        })

        result = run_js(f'parseValidation({json.dumps(response)})')

        self.assertEqual(result["statusText"], "Signerad")
        self.assertEqual(len(result["signers"]), 1)
        signer = result["signers"][0]
        self.assertEqual(signer["displayName"], "NextNotesTestAccount")
        self.assertEqual(signer["signatureLabel"], "Signaturen är giltig.")
        self.assertEqual(signer["certificateLabel"], "Certifikatet är pålitligt.")

    def test_returns_none_for_malformed_response(self):
        result = run_js('parseValidation("not json")')
        self.assertIsNone(result)


class ExtractErrorMessageTests(unittest.TestCase):
    def test_prefers_data_message_then_first_error_then_meta_message(self):
        data_message = json.dumps({"ocs": {"data": {"message": "Ogiltigt UUID"}}})
        errors_only = json.dumps({"ocs": {"data": {"errors": [{"message": "First error"}, {"message": "Second"}]}}})
        meta_only = json.dumps({"ocs": {"meta": {"message": "Meta level failure"}}})

        self.assertEqual(run_js(f'extractErrorMessage({json.dumps(data_message)})'), "Ogiltigt UUID")
        self.assertEqual(run_js(f'extractErrorMessage({json.dumps(errors_only)})'), "First error")
        self.assertEqual(run_js(f'extractErrorMessage({json.dumps(meta_only)})'), "Meta level failure")

    def test_returns_null_when_nothing_usable_is_present(self):
        self.assertIsNone(run_js('extractErrorMessage("not json")'))
        self.assertIsNone(run_js(f'extractErrorMessage({json.dumps(json.dumps({"ocs": {}}))})'))


if __name__ == "__main__":
    unittest.main()
