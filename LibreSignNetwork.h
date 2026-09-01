#ifndef LIBRESIGNNETWORK_H
#define LIBRESIGNNETWORK_H

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkRequest;

class LibreSignNetwork : public QObject
{
    Q_OBJECT

public:
    explicit LibreSignNetwork(QObject *parent = nullptr);

    Q_INVOKABLE void sendRequest(int generation,
                                  const QString &requestId,
                                  const QString &method,
                                  const QString &url,
                                  const QString &userName,
                                  const QString &secret,
                                  const QString &body,
                                  const QString &contentType);

signals:
    void requestFinished(const QString &requestId, int status, const QString &responseText, int generation);
    void requestFailed(const QString &requestId, const QString &message, int generation);

private:
    QNetworkAccessManager *isolatedManager();
    QNetworkRequest authorizedRequest(const QString &url,
                                       const QString &userName,
                                       const QString &secret,
                                       const QString &contentType) const;
};

#endif
