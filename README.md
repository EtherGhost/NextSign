# NextSign

NextSign is a native Ubuntu Touch client for LibreSign, the electronic signature app for
Nextcloud. It does not prepare documents or place signature fields - that happens elsewhere (the
LibreSign web UI, or whoever sent you the request). NextSign's job is to show you what is waiting
for your signature and let you sign it with a tap, primarily through LibreSign's `clickToSign`
method (no password or code needed). There is deliberately no password-based signing fallback.

## Status

Early release. Bugs and rough edges are expected. What exists so far:

- Ubuntu Touch Online Accounts authentication (Nextcloud/ownCloud), with the guided
  allow-this-account flow.
- The shared app shell: hamburger navigation, settings, language selection, and about page.
- Two views, switchable from the header: documents waiting for your signature, and documents
  you've already signed.
- Lets you view a document (either view) before or after signing: downloads it and hands it to
  whichever app you pick via Ubuntu Touch's content-hub share flow, rather than an in-app PDF
  viewer.
- Signs a document with a tap, using LibreSign's `clickToSign` method, after a confirmation
  prompt. This is the app's core feature.
- Validates a signed document's signature and shows LibreSign's own verdict for it.
- Sort either list by date or name.
- Pull down to refresh either view. Reconnects safely if you switch Nextcloud accounts while a
  request is still in flight.
- Available in English, Swedish, Catalan, Danish, Dutch, Finnish, French, German, Italian,
  Norwegian Bokmal, Polish, Russian, Spanish, and Ukrainian.

## Disclaimer

This is a hobby project, built and maintained in spare time - not an official or supported
product.

- **No support is offered, and this is a solo project, not a collaborative one.** Bug reports are
  welcome, but there's no guaranteed response time and no promise any given one gets fixed.
- **Use it at your own risk**, especially anything involving actually signing a document. Verify
  independently (e.g. in the LibreSign web UI) that a signature was applied correctly before
  relying on it for anything that matters.
- **Not affiliated with, endorsed by, or supported by Nextcloud GmbH, the Nextcloud project, or
  the LibreSign project** in any way.
- Provided under the MIT license (see [`LICENSE`](LICENSE)): no warranty of any kind, used
  entirely at your own risk.

## Platforms

- **Ubuntu Touch** - the only target right now.
- **Android** - planned as a separate, independent app later (different UI toolkit and a
  different account/auth mechanism than Ubuntu Touch), not a port of this codebase.

## Technology

Built with Qt/QML and C++ for Ubuntu Touch, using the shared NextCommon and UTControls components,
talking to LibreSign's REST API on a self-hosted Nextcloud instance.

## License

MIT - see [`LICENSE`](LICENSE).
