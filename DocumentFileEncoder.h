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
    // PdfPageRenderer and Poppler both take a literal OS path, not a URL; passing
    // a "file://..." string makes them try to open a file literally named
    // "file:/...", which always fails - confirmed live via the exact "Couldn't
    // open file 'file:///...'" error message.
    Q_INVOKABLE QString localPath(const QString &fileUrl) const;

    // Copies fileUrl's content into NextSign's own cache, returning the copy's
    // "file://" url (or an empty string on failure). Used for a document just
    // received via content-hub, before the import handler marks that transfer
    // Collected - content-hub can clean up its own staging file as soon as
    // finalize() is called, which can race a later read straight from the
    // original item.url (confirmed live: "No such file or directory" when
    // PrepareDocumentPage tried to render a page a moment after import).
    Q_INVOKABLE QString copyToCache(const QString &fileUrl, const QString &fileName) const;
};

#endif
