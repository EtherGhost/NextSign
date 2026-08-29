#include "DocumentDownloader.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QNetworkAccessManager>
#include <QFile>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {

const int kRequestTimeoutMs = 60000;

// Qt 5.12 has no QNetworkRequest transfer timeout, so a stalled reply (e.g. a
// mobile connection that drops mid-request) never finishes on its own. Aborting
// after a timeout makes the reply's finished handler run with an error status,
// which existing failure handling already covers.
void armTimeout(QNetworkReply *reply, int timeoutMs = kRequestTimeoutMs)
{
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    QObject::connect(timer, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(reply, &QNetworkReply::finished, timer, &QTimer::stop);
    timer->start(timeoutMs);
}

QString safeCacheFileName(const QString &value)
{
    QString result = value.trimmed();
    result.replace(QRegularExpression(QStringLiteral("[\\\\/\\r\\n]+")), QStringLiteral("-"));
    result.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9._ -]+")), QStringLiteral("-"));
    result = result.left(96).trimmed();
    if (result.isEmpty() || result == QStringLiteral(".") || result == QStringLiteral("..")) {
        result = QStringLiteral("document");
    }
    return result;
}

QString contentDispositionFileName(const QByteArray &header)
{
    const QString value = QString::fromUtf8(header);
    const QRegularExpression fileNameStar(QStringLiteral("filename\\*=UTF-8''([^;]+)"), QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch match = fileNameStar.match(value);
    if (match.hasMatch()) {
        return QUrl::fromPercentEncoding(match.captured(1).trimmed().toUtf8());
    }
    const QRegularExpression fileNameQuoted(QStringLiteral("filename=\"([^\"]+)\""), QRegularExpression::CaseInsensitiveOption);
    match = fileNameQuoted.match(value);
    if (match.hasMatch()) {
        return match.captured(1).trimmed();
    }
    return QString();
}
}

DocumentDownloader::DocumentDownloader(QObject *parent)
    : QObject(parent)
{
}

void DocumentDownloader::downloadToCache(int generation,
                                          const QString &url,
                                          const QString &userName,
                                          const QString &secret,
                                          const QString &preferredFileName)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit downloadFailed(tr("Account credentials are incomplete."), generation);
        return;
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret);
    QNetworkReply *reply = requestManager->get(request);
    armTimeout(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, generation, preferredFileName]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        const QByteArray contentType = reply->header(QNetworkRequest::ContentTypeHeader).toByteArray();
        const QByteArray disposition = reply->rawHeader("Content-Disposition");
        reply->deleteLater();
        requestManager->deleteLater();

        if (status < 200 || status >= 300) {
            emit downloadFailed(tr("Document download failed with HTTP %1.").arg(status), generation);
            return;
        }
        if (responseBody.isEmpty()) {
            emit downloadFailed(tr("The downloaded document is empty."), generation);
            return;
        }

        const QString basePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        if (basePath.isEmpty()) {
            emit downloadFailed(tr("Document cache is not available."), generation);
            return;
        }
        QDir dir(basePath);
        if (!dir.mkpath(QStringLiteral("DocumentDownloads")) || !dir.cd(QStringLiteral("DocumentDownloads"))) {
            emit downloadFailed(tr("Document cache could not be prepared."), generation);
            return;
        }

        QString fileName = contentDispositionFileName(disposition);
        if (fileName.trimmed().isEmpty()) {
            fileName = preferredFileName;
        }
        fileName = safeCacheFileName(fileName);
        if (!fileName.endsWith(QStringLiteral(".pdf"), Qt::CaseInsensitive)) {
            fileName += QStringLiteral(".pdf");
        }

        const QByteArray digest = QCryptographicHash::hash(
                    (fileName + QString::number(QDateTime::currentMSecsSinceEpoch())).toUtf8(),
                    QCryptographicHash::Sha1).toHex().left(10);
        const QString filePath = dir.filePath(QStringLiteral("%1-%2").arg(QString::fromLatin1(digest), fileName));

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            emit downloadFailed(tr("The downloaded document could not be saved."), generation);
            return;
        }
        file.write(responseBody);
        file.close();

        const QString mimeType = QString::fromLatin1(contentType.split(';').first().trimmed());
        emit downloaded(QUrl::fromLocalFile(filePath).toString(),
                         fileName,
                         mimeType.isEmpty() ? QStringLiteral("application/pdf") : mimeType,
                         generation);
    });
}

QNetworkAccessManager *DocumentDownloader::isolatedManager()
{
    return new QNetworkAccessManager(this);
}

QNetworkRequest DocumentDownloader::authorizedRequest(const QString &url, const QString &userName, const QString &secret) const
{
    QUrl requestUrl(url);
    if (!userName.isEmpty()) {
        requestUrl.setUserName(userName);
    }

    QNetworkRequest request(requestUrl);
    request.setRawHeader("Authorization", "Basic " + QByteArray(QString(userName + QStringLiteral(":") + secret).toUtf8()).toBase64());
    request.setRawHeader("OCS-APIRequest", "true");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("Pragma", "no-cache");
    request.setRawHeader("Connection", "close");
    // Without this, a server behind an http->https or path redirect fails
    // every request outright (Qt does not follow redirects by default).
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    return request;
}
