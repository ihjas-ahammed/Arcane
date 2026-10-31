package me.ihjas.missions

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import java.io.File
import java.io.FileNotFoundException

/**
 * Read-only Storage Access Framework provider. It shows one Arcane folder, the briefing exports,
 * in the system file picker ("Open from"), so JSON files can be picked from there.
 *
 * Only [EXPORT_DIR_NAME] under the app's documents folder is exposed. The app database and the
 * backups folder are not reachable through this provider. The system grants access only to
 * callers that hold MANAGE_DOCUMENTS (the system file picker).
 */
class ArcaneExportsProvider : DocumentsProvider() {

    override fun onCreate(): Boolean = true

    private fun rootDir(): File {
        val base = File(context!!.applicationInfo.dataDir, DOCUMENTS_DIR_NAME)
        return File(base, EXPORT_DIR_NAME).apply { mkdirs() }
    }

    private fun canonicalRoot(): String = rootDir().canonicalPath

    /** Resolves a document id to a file inside the root. Rejects anything outside it. */
    private fun fileFor(documentId: String): File {
        val file = File(documentId).canonicalFile
        val root = canonicalRoot()
        if (file.path != root && !file.path.startsWith(root + File.separator)) {
            throw FileNotFoundException("Outside the Arcane exports folder")
        }
        if (!file.exists()) throw FileNotFoundException("Not found: $documentId")
        return file
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_ROOT_COLUMNS)
        val root = canonicalRoot()
        result.newRow().apply {
            add(Root.COLUMN_ROOT_ID, root)
            add(Root.COLUMN_DOCUMENT_ID, root)
            add(Root.COLUMN_TITLE, "Arcane briefings")
            add(Root.COLUMN_SUMMARY, "Offline JSON exports")
            add(Root.COLUMN_FLAGS, Root.FLAG_LOCAL_ONLY or Root.FLAG_SUPPORTS_IS_CHILD)
            add(Root.COLUMN_MIME_TYPES, "*/*")
            add(Root.COLUMN_ICON, context!!.applicationInfo.icon)
            add(Root.COLUMN_AVAILABLE_BYTES, rootDir().freeSpace)
        }
        return result
    }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_COLUMNS)
        includeFile(result, fileFor(documentId))
        return result
    }

    override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_COLUMNS)
        val parent = fileFor(parentDocumentId)
        parent.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".json") }
            ?.sortedBy { it.name }
            ?.forEach { includeFile(result, it) }
        return result
    }

    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Arcane exports are read-only")
        val file = fileFor(documentId)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        return documentId.startsWith(parentDocumentId + File.separator)
    }

    private fun includeFile(result: MatrixCursor, file: File) {
        val isRoot = file.canonicalPath == canonicalRoot()
        val mime = if (file.isDirectory) Document.MIME_TYPE_DIR else "application/json"
        result.newRow().apply {
            add(Document.COLUMN_DOCUMENT_ID, file.canonicalPath)
            add(Document.COLUMN_DISPLAY_NAME, if (isRoot) "Arcane briefings" else file.name)
            add(Document.COLUMN_SIZE, file.length())
            add(Document.COLUMN_MIME_TYPE, mime)
            add(Document.COLUMN_LAST_MODIFIED, file.lastModified())
            add(Document.COLUMN_FLAGS, 0)
            add(Document.COLUMN_ICON, context!!.applicationInfo.icon)
        }
    }

    companion object {
        /** Android's documents folder for this app is `<dataDir>/app_flutter`. */
        private const val DOCUMENTS_DIR_NAME = "app_flutter"
        /** Folder written by the Flutter side with the latest offline briefing exports. */
        const val EXPORT_DIR_NAME = "briefing_exports"

        private val DEFAULT_ROOT_COLUMNS = arrayOf(
            Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID, Root.COLUMN_TITLE, Root.COLUMN_SUMMARY,
            Root.COLUMN_FLAGS, Root.COLUMN_MIME_TYPES, Root.COLUMN_ICON, Root.COLUMN_AVAILABLE_BYTES,
        )
        private val DEFAULT_DOCUMENT_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_SIZE,
            Document.COLUMN_MIME_TYPE, Document.COLUMN_LAST_MODIFIED, Document.COLUMN_FLAGS,
            Document.COLUMN_ICON,
        )
    }
}
