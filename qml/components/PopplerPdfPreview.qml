import QtQuick 2.7
import org.docviewer.poppler 1.0

// Isolated in its own file specifically so a missing qtdeclarative5-poppler1.0
// module on a real device fails this ONE Qt.createComponent() call in
// PrepareDocumentPage.qml (caught as Component.Error) rather than breaking the
// whole page - a top-level "import org.docviewer.poppler 1.0" in the page itself
// would fail at parse time, uncatchable. See clickable.yaml for why this isn't
// bundled into the click package.
Item {
    id: root
    property alias path: poppler.path
    // poppler.loaded can be undefined momentarily (e.g. while a bad path is
    // still failing to load) - confirmed live, QML can't assign that to a
    // plain bool, so coerce explicitly rather than aliasing it directly.
    property bool pdfLoaded: poppler.loaded === true
    property var pages: poppler.loaded === true ? poppler.pages : []
    signal pdfError(string message)

    Poppler {
        id: poppler
        onError: root.pdfError(errorMessage)
    }
}
