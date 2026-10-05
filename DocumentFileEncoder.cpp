#include "DocumentFileEncoder.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
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

QString DocumentFileEncoder::copyToCache(const QString &fileUrl, const QString &fileName) const
{
    const QString sourcePath = localPathFor(fileUrl);
    if (!QFile::exists(sourcePath)) {
        return QString();
    }

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/SharedDocuments");
    QDir().mkpath(cacheDir);
    // QFileInfo(...).fileName() strips any directory components - fileName
    // comes from content-hub's own item.name, an untrusted peer-supplied
    // string, and is used here as part of a filesystem path.
    const QString strippedName = QFileInfo(fileName).fileName();
    const QString safeName = strippedName.isEmpty() ? QStringLiteral("document.pdf") : strippedName;
    const QString destinationPath = cacheDir + QStringLiteral("/") + safeName;

    // Overwriting rather than uniquing by uuid - only one prepare-document flow
    // is ever in flight at a time, so there is nothing else to collide with.
    QFile::remove(destinationPath);
    if (!QFile::copy(sourcePath, destinationPath)) {
        return QString();
    }
    return QUrl::fromLocalFile(destinationPath).toString();
}
