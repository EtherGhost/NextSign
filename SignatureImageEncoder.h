#ifndef SIGNATUREIMAGEENCODER_H
#define SIGNATUREIMAGEENCODER_H

#include <QObject>
#include <QString>

class SignatureImageEncoder : public QObject
{
    Q_OBJECT

public:
    explicit SignatureImageEncoder(QObject *parent = nullptr);

    // Returns a "data:image/png;base64,..." URI for the given local file, or an
    // empty string if the file could not be read, decoded as an image, or encoded
    // within LibreSign's upload size limit.
    Q_INVOKABLE QString toBase64DataUri(const QString &fileUrl) const;
};

#endif
