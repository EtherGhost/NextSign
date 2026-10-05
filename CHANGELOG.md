# Changelog

## 0.4.0 - 2026-10-05

- Prepare a document for signing: share a PDF in from another app (e.g. the
  Files app), preview it, search for and select signers, then place as many
  signature fields as needed per signer across any page - ported from the
  Android app.
- Choose which account should prepare a document, if more than one
  Nextcloud/ownCloud account is set up.
- Delete a sign request you created, before anyone has signed - removes the
  signing request/bookkeeping only, not the underlying file.
- A "needs attention" filter on the document list, hiding fully-signed and
  waiting-on-others documents.
- A "Prepare a document" entry in the drawer explaining the share-in flow,
  since nothing previously said it existed.

## 0.3.0 - 2026-10-04

- Shows a signer's custom message, if the requester left one.
- Moved each document's status badge to its own row, so it lines up the same
  way regardless of the document's name length.

## 0.2.0 - 2026-09-01

- Set up a signature image, by picking one or drawing it with a finger or
  stylus, from the menu or automatically the first time you need one.
- Documents now show in a single list with a status (ready to sign,
  partially signed, signed) instead of two tabs, matching the web UI. Tap a
  document to see all its signers and their status.
- Fixed a signature sometimes not rendering visibly on the signed document.
- Fixed documents and signatures occasionally appearing to belong to the
  wrong account when switching between two accounts on the same server.
- Fixed a document still needing your signature sometimes not showing up as
  pending once someone else had already signed their part.

## 0.1.0 - 2026-08-30

First public release. This is an early version - bugs and rough edges are expected.

- Sign in with an existing Ubuntu Touch Online Accounts Nextcloud/ownCloud account.
- List documents waiting for your signature, and documents you have already signed.
- View a document before or after signing, handed off to another app through content-hub.
- Sign a document with a tap, using LibreSign's click-to-sign method.
- Validate a signed document's signature.
- Sort either list by date or name, and pull to refresh.
- Available in English, Swedish, and several AI-assisted languages.
