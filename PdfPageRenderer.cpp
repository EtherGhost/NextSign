#include "PdfPageRenderer.h"

#include <QDir>
#include <QImage>
#include <QStandardPaths>
#include <poppler-qt5.h>

PdfPageRenderer::PdfPageRenderer(QObject *parent)
    : QObject(parent)
{
}

QVariantMap PdfPageRenderer::renderPage(const QString &localPath, int pageIndex, int targetWidthPx) const
{
    QVariantMap result;

    Poppler::Document *document = Poppler::Document::load(localPath);
    if (!document || document->isLocked()) {
        delete document;
        result["ok"] = false;
        result["error"] = QStringLiteral("could not open document");
        return result;
    }

    const int pageCount = document->numPages();
    if (pageIndex < 0 || pageIndex >= pageCount) {
        delete document;
        result["ok"] = false;
        result["error"] = QStringLiteral("page index out of range");
        return result;
    }

    Poppler::Page *page = document->page(pageIndex);
    if (!page) {
        delete document;
        result["ok"] = false;
        result["error"] = QStringLiteral("document has no pages");
        return result;
    }

    const QSizeF pageSizePt = page->pageSizeF();
    if (pageSizePt.width() <= 0 || pageSizePt.height() <= 0 || targetWidthPx <= 0) {
        delete page;
        delete document;
        result["ok"] = false;
        result["error"] = QStringLiteral("unknown page size");
        return result;
    }

    const double dpi = (targetWidthPx / pageSizePt.width()) * 72.0;
    const QImage image = page->renderToImage(dpi, dpi);
    delete page;
    delete document;

    if (image.isNull()) {
        result["ok"] = false;
        result["error"] = QStringLiteral("render failed");
        return result;
    }

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/PdfPreview");
    QDir().mkpath(cacheDir);
    // Indexed by page, not a fixed "current.png" - QML's Image only reloads
    // when its source *string* actually changes, so revisiting a page would
    // otherwise keep showing whatever page last overwrote the same filename.
    const QString imagePath = cacheDir + QStringLiteral("/page_") + QString::number(pageIndex) + QStringLiteral(".png");
    if (!image.save(imagePath, "PNG")) {
        result["ok"] = false;
        result["error"] = QStringLiteral("could not save rendered page");
        return result;
    }

    result["ok"] = true;
    result["imagePath"] = imagePath;
    result["pageWidthPt"] = pageSizePt.width();
    result["pageHeightPt"] = pageSizePt.height();
    result["pageCount"] = pageCount;
    return result;
}
