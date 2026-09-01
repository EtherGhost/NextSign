#include "SignatureImageEncoder.h"

#include <QBuffer>
#include <QImage>
#include <QUrl>

namespace {
// A signature is stamped small onto a PDF page - a multi-megapixel camera photo is
// unnecessary and risks exceeding LibreSign's upload limit, so downscale before
// encoding rather than sending the source image as-is.
const int kMaxDimensionPx = 1200;
const qint64 kMaxUploadBytes = 5 * 1024 * 1024;
}

SignatureImageEncoder::SignatureImageEncoder(QObject *parent)
    : QObject(parent)
{
}

QString SignatureImageEncoder::toBase64DataUri(const QString &fileUrl) const
{
    const QUrl url(fileUrl);
    const QString localPath = url.isLocalFile() ? url.toLocalFile() : fileUrl;

    QImage image(localPath);
    if (image.isNull()) {
        return QString();
    }

    if (image.width() > kMaxDimensionPx || image.height() > kMaxDimensionPx) {
        image = image.scaled(kMaxDimensionPx, kMaxDimensionPx, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    // LibreSign expects a PNG regardless of the source format - it stores visible
    // signature/initials elements as .png server-side.
    if (!image.save(&buffer, "PNG")) {
        return QString();
    }
    buffer.close();

    if (bytes.size() > kMaxUploadBytes) {
        return QString();
    }

    return QStringLiteral("data:image/png;base64,%1").arg(QString::fromLatin1(bytes.toBase64()));
}
