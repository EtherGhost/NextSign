#include "DocumentFileEncoder.h"

#include <QFile>
#include <QFileInfo>
#include <QUrl>

namespace {
QString localPathFor(const QString &fileUrl)
{
    const QUrl url(fileUrl);
    return url.isLocalFile() ? url.toLocalFile() : fileUrl;
}
}

DocumentFileEncoder::DocumentFileEncoder(QObject *parent)
    : QObject(parent)
{
}

QString DocumentFileEncoder::fileToBase64(const QString &fileUrl) const
{
    QFile file(localPathFor(fileUrl));
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromLatin1(file.readAll().toBase64());
}

qint64 DocumentFileEncoder::fileSize(const QString &fileUrl) const
{
    const QFileInfo info(localPathFor(fileUrl));
    return info.exists() ? info.size() : -1;
}

QString DocumentFileEncoder::localPath(const QString &fileUrl) const
{
    return localPathFor(fileUrl);
}
