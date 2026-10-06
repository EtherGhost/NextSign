# NextSign

NextSign is a native Ubuntu Touch client for LibreSign, the electronic signature app for
Nextcloud. NextSign's job is to show you what is waiting for your signature and let you sign it
with a tap, primarily through LibreSign's `clickToSign` method (no password or code needed) -
there is deliberately no password-based signing fallback. You can also prepare a document for
signing by sharing a PDF to NextSign from another app.

## Status

Published on [OpenStore](https://open-store.io/app/nextsign.cloudsite/).

- Ubuntu Touch Online Accounts authentication (Nextcloud/ownCloud), with the guided
  allow-this-account flow.
- The shared app shell: hamburger navigation, settings, language selection, and about page.
- One document list showing every document you're involved in, each with its own status (ready
  to sign, partially signed, signed) - tap a document to see every signer's status.
- Lets you view a document before or after signing: downloads it and hands it to whichever app
  you pick via Ubuntu Touch's content-hub share flow, rather than an in-app PDF viewer.
- Signs a document with a tap, using LibreSign's `clickToSign` method, after a confirmation
  prompt. This is the app's core feature.
- Set up a signature by picking an image or drawing it with a finger or stylus, used
  automatically when a document needs a visible signature.
- Validates a signed document's signature and shows LibreSign's own verdict for it.
- Prepares a document for signing: share a PDF in from another app (e.g. the Files app), preview
  it, search for and select signers, then place as many signature fields as needed per signer
  across any page, then send it.
- Lets you choose which account should prepare a document, if more than one Nextcloud/ownCloud
  account is set up.
- Deletes a sign request you created, before anyone has signed.
- Filters the document list to show only what needs your attention.
- Sort the list by date or name.
- Pull down to refresh. Reconnects safely if you switch Nextcloud accounts while a request is
  still in flight.
- Available in English, Swedish, Catalan, Danish, Dutch, Finnish, French, German, Italian,
  Norwegian Bokmal, Polish, Russian, Spanish, and Ukrainian.

## Disclaimer

This is a hobby project, built and maintained in spare time - not an official or supported
product.

- **No support is offered, and this is a solo project, not a collaborative one.** Bug reports are
  welcome, but there's no guaranteed response time and no promise any given one gets fixed. The
  source is here to be read and forked, not to gather contributors.
- **Use it at your own risk**, especially anything involving actually signing a document. Verify
  independently (e.g. in the LibreSign web UI) that a signature was applied correctly before
  relying on it for anything that matters.
- **Not affiliated with, endorsed by, or supported by Nextcloud GmbH, the Nextcloud project, or
  the LibreSign project** in any way.
- Provided under the MIT license (see [`LICENSE`](LICENSE)): no warranty of any kind, used
  entirely at your own risk.

## Platforms

- **Ubuntu Touch** - this app.
- **Android** - a separate, independent app (different UI toolkit and a different account/auth
  mechanism than Ubuntu Touch, not a port of this codebase), published on
  [Google Play](https://play.google.com/store/apps/details?id=se.cloudsite.nextsign).

## Technology

Built with Qt/QML and C++ for Ubuntu Touch, using the shared NextCommon and UTControls components,
talking to LibreSign's REST API on a self-hosted Nextcloud instance.

## License

MIT - see [`LICENSE`](LICENSE).
