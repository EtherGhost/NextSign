#ifndef PDFPAGERENDERER_H
#define PDFPAGERENDERER_H

#include <QObject>
#include <QString>
#include <QVariantMap>

class PdfPageRenderer : public QObject
{
    Q_OBJECT

public:
    explicit PdfPageRenderer(QObject *parent = nullptr);

    // Renders one page (0-indexed) of the PDF at localPath to a PNG roughly
    // targetWidthPx wide, written to the cache directory (overwriting any
    // previous render - only one prepare-document page is ever shown at a time,
    // so nothing else needs it). On success: {"ok": true, "imagePath": ...,
    // "pageWidthPt": ..., "pageHeightPt": ..., "pageCount": ...} (point size, not
    // pixels - needed to convert a tap position back to the PDF's own coordinate
    // space for field placement). On failure: {"ok": false, "error": <technical,
    // not user-facing - same role the old Poppler QML plugin's own errorMessage
    // played>}.
    Q_INVOKABLE QVariantMap renderPage(const QString &localPath, int pageIndex, int targetWidthPx) const;
};

#endif
