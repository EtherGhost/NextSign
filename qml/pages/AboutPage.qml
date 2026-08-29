import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AboutPage {
    appName: i18n.tr("NextSign")
    appVersion: typeof nextsignAppVersion !== "undefined" ? nextsignAppVersion : "development"
    appDescription: "Sign documents by tapping - a native Ubuntu Touch client for LibreSign on Nextcloud."
    logoSource: "qrc:/assets/logo.svg"
    licenseText: "NextSign is licensed under the MIT License."
    copyrightText: "Copyright (c) 2026 Etherghost"
    disclaimerText: "NextSign is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH, the Nextcloud project, or the LibreSign project. Nextcloud and LibreSign are trademarks of their respective owners."
}
