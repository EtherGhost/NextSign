#ifndef DOCUMENTFILEENCODER_H
#define DOCUMENTFILEENCODER_H

#include <QObject>
#include <QString>

class DocumentFileEncoder : public QObject
{
    Q_OBJECT

public:
    explicit DocumentFileEncoder(QObject *parent = nullptr);

    // Returns the raw bytes of the given local file, base64-encoded (plain, not a
    // data: URI - request-signature's "file.base64" wants just the bytes). Empty
    // string if the file could not be opened or read.
    Q_INVOKABLE QString fileToBase64(const QString &fileUrl) const;

    // Size in bytes of the given local file, or -1 if it could not be read - used
    // to decide whether to even attempt an upload before spending time encoding it.
    Q_INVOKABLE qint64 fileSize(const QString &fileUrl) const;

    // Plain filesystem path (no "file://" scheme) for the given local file url -
    // the Poppler QML plugin's own "path" property takes a literal OS path, not a
    // URL; passing it a "file://..." string makes it try to open a file literally
    // named "file:/...", which always fails - confirmed live via the exact
    // "Couldn't open file 'file:///...'" error message.
    Q_INVOKABLE QString localPath(const QString &fileUrl) const;
};

#endif
