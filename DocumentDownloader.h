#ifndef DOCUMENTDOWNLOADER_H
#define DOCUMENTDOWNLOADER_H

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkRequest;

class DocumentDownloader : public QObject
{
    Q_OBJECT

public:
    explicit DocumentDownloader(QObject *parent = nullptr);

    Q_INVOKABLE void downloadToCache(int generation,
                                      const QString &url,
                                      const QString &userName,
                                      const QString &secret,
                                      const QString &preferredFileName);

signals:
    void downloaded(const QString &fileUrl, const QString &fileName, const QString &mimeType, int generation);
    void downloadFailed(const QString &message, int generation);

private:
    QNetworkAccessManager *isolatedManager();
    QNetworkRequest authorizedRequest(const QString &url, const QString &userName, const QString &secret) const;
};

#endif
