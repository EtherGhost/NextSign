import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Content 1.3

Page {
    id: page
    title: i18n.tr("Open with")

    property url documentUrl
    property string documentName: ""
    property var currentTransfer: null
    property bool closed: false

    header: PageHeader {
        id: header
        title: page.title
    }

    ContentPeerPicker {
        anchors {
            fill: parent
            topMargin: header.height
        }
        visible: true
        showTitle: false
        contentType: ContentType.Documents
        // Destination, not Share: apps that just receive/open a document (a PDF
        // reader, e.g. docviewer.ubports) register under "destination", not
        // "share" - Share is for text/social-style sharing targets. This is the
        // same handler the Files app's "open with" flow uses.
        handler: ContentHandler.Destination

        onPeerSelected: {
            // Plain block, not function(peer) {...}: this signal's "peer" argument
            // only comes through via QML's implicit signal-handler injection, not
            // as a real function parameter - wrapping it in an explicit function
            // literal left "peer" undefined.
            page.currentTransfer = peer.request()
            if (page.currentTransfer.state === ContentTransfer.InProgress) {
                page.chargeTransfer()
            }
            // Do not pop here: the transfer is usually still asynchronous at this
            // point (state isn't InProgress yet), and popping destroys this page -
            // and with it the currentTransfer property and the Connections below -
            // before the transfer can ever be charged. The receiving app would
            // launch and then wait forever for content that never arrives. Only
            // close once the transfer actually finishes, below.
        }
        onCancelPressed: pageStack.pop()
    }

    Connections {
        target: page.currentTransfer
        onStateChanged: {
            if (page.currentTransfer.state === ContentTransfer.InProgress) {
                page.chargeTransfer()
            } else if (!page.closed
                    && (page.currentTransfer.state === ContentTransfer.Charged
                        || page.currentTransfer.state === ContentTransfer.Aborted)) {
                // The transfer can pass through more than one terminal-looking
                // state as it completes - only pop once, or the second pop has
                // nothing left to remove ("Trying to pop an empty PageStack").
                page.closed = true
                pageStack.pop()
            }
        }
    }

    function chargeTransfer() {
        var item = itemComponent.createObject(page)
        item.name = page.documentName.length > 0 ? page.documentName : i18n.tr("Document")
        item.url = page.documentUrl
        page.currentTransfer.items = [ item ]
        page.currentTransfer.state = ContentTransfer.Charged
    }

    Component {
        id: itemComponent
        ContentItem {
        }
    }
}
