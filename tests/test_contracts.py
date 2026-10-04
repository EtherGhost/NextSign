import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


class ProjectMetadataTests(unittest.TestCase):
    def test_manifest_identity_and_version_are_consistent(self):
        manifest = json.loads(read_text("manifest.json.in"))
        cmake = read_text("CMakeLists.txt")

        self.assertEqual(manifest["name"], "nextsign.cloudsite")
        self.assertIn('set(NEXTSIGN_VERSION "0.4.0")', cmake)
        self.assertIn("vendor/NextCommon/qml/NextCommon/*.qml", cmake)
        self.assertIn("vendor/UTControls/qml/UTControls/*.qml", cmake)
        self.assertEqual(manifest["version"], "@NEXTSIGN_VERSION@")
        self.assertIn("nextsign", manifest["hooks"])
        self.assertEqual(manifest["hooks"]["nextsign"]["apparmor"], "nextsign.apparmor")
        self.assertEqual(manifest["hooks"]["nextsign"]["accounts"], "nextsign.accounts")
        self.assertEqual(manifest["hooks"]["nextsign"]["content-hub"], "nextsign-contenthub.json")
        self.assertEqual(manifest["hooks"]["nextsign"]["desktop"], "nextsign.desktop")

    def test_apparmor_keeps_minimal_permissions_and_no_unconfined_mode(self):
        apparmor = json.loads(read_text("nextsign.apparmor"))

        self.assertNotIn("template", apparmor)
        self.assertNotIn("unconfined", json.dumps(apparmor).lower())
        self.assertEqual(
            sorted(apparmor.get("policy_groups", [])),
            ["accounts", "content_exchange", "content_exchange_source", "networking"],
        )

    def test_content_hub_declares_only_documents_and_pictures(self):
        content_hub = json.loads(read_text("nextsign-contenthub.json"))

        self.assertEqual(content_hub.get("destination"), ["documents"])
        self.assertEqual(content_hub.get("share"), ["documents"])
        # "pictures" lets the user pick a signature image from the Gallery/Files app.
        self.assertEqual(content_hub.get("source"), ["documents", "pictures"])

    def test_accounts_file_declares_nextcloud_and_owncloud_services(self):
        accounts = json.loads(read_text("nextsign.accounts"))
        providers = sorted(service["provider"] for service in accounts["services"])

        self.assertEqual(providers, ["nextcloud", "owncloud"])
        for service in accounts["services"]:
            self.assertEqual(service["name"], "NextSign")

    def test_qml_qrc_files_exist(self):
        qrc = read_text("qml/qml.qrc")
        files = re.findall(r"<file(?:\s+alias=\"[^\"]*\")?>([^<]+)</file>", qrc)

        self.assertGreater(len(files), 0)
        for relative_file in files:
            self.assertTrue((ROOT / "qml" / relative_file).is_file(), relative_file)

    def test_no_password_based_signing_fallback(self):
        # NextSign is click-to-sign only by design - no signing password fallback.
        qml_dir = ROOT / "qml"
        for qml_file in qml_dir.rglob("*.qml"):
            content = qml_file.read_text(encoding="utf-8")
            self.assertNotIn("signPassword", content, qml_file)
            self.assertNotIn('"method": "password"', content, qml_file)

    def test_every_new_string_is_translated_into_swedish(self):
        # Own source only (not vendor/) - shared-component strings are a
        # suite-wide concern, not something a single app's test should gate.
        pattern = re.compile(r'i18n\.tr\("((?:[^"\\]|\\.)*)"\)|(?<!\w)tr\("((?:[^"\\]|\\.)*)"\)')
        found_msgids = set()
        for source_file in list((ROOT / "qml").rglob("*.qml")) + list(ROOT.glob("*.cpp")) + list(ROOT.glob("*.h")):
            if "vendor" in source_file.parts:
                continue
            content = source_file.read_text(encoding="utf-8")
            for match in pattern.finditer(content):
                found_msgids.add((match.group(1) or match.group(2)).encode().decode("unicode_escape"))

        sv_po = read_text("po/sv.po")
        translated = {
            msgid.encode().decode("unicode_escape"): msgstr.encode().decode("unicode_escape")
            for msgid, msgstr in re.findall(r'msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', sv_po)
        }

        missing = sorted(m for m in found_msgids if m not in translated or not translated[m].strip())
        self.assertEqual(missing, [], "Untranslated strings found in Swedish: " + ", ".join(missing))


if __name__ == "__main__":
    unittest.main()
