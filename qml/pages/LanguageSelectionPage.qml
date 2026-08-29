import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.LanguagePage {
    id: page

    appName: "NextSign"
    // Override NextCommon's default notice, which invites outside contributions -
    // NextSign is a solo project, not a collaborative one (see README.md).
    translationNotice: i18n.tr("Some translations are AI-assisted and have not been fully reviewed.")
    languageOptions: [
        { "code": "", "label": i18n.tr("Follow system language"), "detail": i18n.tr("Default") },
        { "code": "en", "label": "English", "detail": i18n.tr("Built-in source language") },
        { "code": "sv", "label": "Svenska", "detail": "" },
        { "code": "ca", "label": "Català", "detail": i18n.tr("AI-assisted translation") },
        { "code": "de", "label": "Deutsch", "detail": i18n.tr("AI-assisted translation") },
        { "code": "fr", "label": "Francais", "detail": i18n.tr("AI-assisted translation") },
        { "code": "nl", "label": "Nederlands", "detail": i18n.tr("AI-assisted translation") },
        { "code": "da", "label": "Dansk", "detail": i18n.tr("AI-assisted translation") },
        { "code": "nb", "label": "Norsk bokmal", "detail": i18n.tr("AI-assisted translation") },
        { "code": "es", "label": "Espanol", "detail": i18n.tr("AI-assisted translation") },
        { "code": "fi", "label": "Suomi", "detail": i18n.tr("AI-assisted translation") },
        { "code": "it", "label": "Italiano", "detail": i18n.tr("AI-assisted translation") },
        { "code": "pl", "label": "Polski", "detail": i18n.tr("AI-assisted translation") },
        { "code": "ru", "label": "Русский", "detail": i18n.tr("AI-assisted translation") },
        { "code": "uk", "label": "Українська", "detail": i18n.tr("AI-assisted translation") }
    ]
}
