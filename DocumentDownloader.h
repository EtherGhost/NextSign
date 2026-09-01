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

    // Separate from downloadToCache()/downloaded() so a signature-preview image fetch
    // can't be mistaken for a document-preview download by whatever is listening.
    Q_INVOKABLE void downloadImageToCache(int generation,
                                           const QString &url,
                                           const QString &userName,
                                           const QString &secret);

signals:
    void downloaded(const QString &fileUrl, const QString &fileName, const QString &mimeType, int generation);
    void downloadFailed(const QString &message, int generation);
    void imageDownloaded(const QString &fileUrl, int generation);
    void imageDownloadFailed(const QString &message, int generation);

private:
    QNetworkAccessManager *isolatedManager();
    QNetworkRequest authorizedRequest(const QString &url, const QString &userName, const QString &secret) const;
    void downloadFileToCache(int generation,
                              const QString &url,
                              const QString &userName,
                              const QString &secret,
                              const QString &preferredFileName,
                              bool isImage);
};

#endif
