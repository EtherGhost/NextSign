#include "LibreSignNetwork.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

namespace {

const int kRequestTimeoutMs = 30000;

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
}

LibreSignNetwork::LibreSignNetwork(QObject *parent)
    : QObject(parent)
{
}

void LibreSignNetwork::sendRequest(int generation,
                                    const QString &requestId,
                                    const QString &method,
                                    const QString &url,
                                    const QString &userName,
                                    const QString &secret,
                                    const QString &body,
                                    const QString &contentType)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit requestFailed(requestId, tr("Account credentials are incomplete."), generation);
        return;
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret, contentType);
    const QByteArray verb = method.trimmed().toUpper().toUtf8();
    QNetworkReply *reply = nullptr;

    if (verb == QByteArrayLiteral("GET")) {
        reply = requestManager->get(request);
    } else if (verb == QByteArrayLiteral("POST")) {
        reply = requestManager->post(request, body.toUtf8());
    } else {
        reply = requestManager->sendCustomRequest(request, verb, body.toUtf8());
    }
    armTimeout(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, requestId, generation]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        reply->deleteLater();
        requestManager->deleteLater();

        if (status > 0) {
            emit requestFinished(requestId, status, QString::fromUtf8(responseBody), generation);
            return;
        }
        emit requestFailed(requestId, tr("LibreSign request failed because the network request could not be completed."), generation);
    });
}

QNetworkAccessManager *LibreSignNetwork::isolatedManager()
{
    return new QNetworkAccessManager(this);
}

QNetworkRequest LibreSignNetwork::authorizedRequest(const QString &url,
                                                     const QString &userName,
                                                     const QString &secret,
                                                     const QString &contentType) const
{
    QUrl requestUrl(url);
    if (!userName.isEmpty()) {
        // Isolates this request from any other account's session/connection
        // for the same host - without this, two Ubuntu Touch Online Accounts
        // on the same Nextcloud server can bleed into each other's data,
        // since Qt's implicit network stack otherwise keys cached
        // connections/auth state by host, not by credentials.
        requestUrl.setUserName(userName);
    }

    QNetworkRequest request(requestUrl);
    request.setRawHeader("Authorization", "Basic " + QByteArray(QString(userName + QStringLiteral(":") + secret).toUtf8()).toBase64());
    request.setRawHeader("OCS-APIRequest", "true");
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("Pragma", "no-cache");
    request.setRawHeader("Connection", "close");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    if (!contentType.trimmed().isEmpty()) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType.trimmed());
    }
    return request;
}
