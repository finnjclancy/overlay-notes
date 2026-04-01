import Foundation

final class NotesStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private var lastSavedText = ""

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let directoryURL = appSupportURL.appendingPathComponent("OverlayNotes", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            fputs("Failed to create notes directory: \(error)\n", stderr)
        }

        fileURL = directoryURL.appendingPathComponent("notes.txt")
    }

    func load() -> String {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ""
        }

        lastSavedText = text
        return text
    }

    func save(_ text: String) {
        guard text != lastSavedText else {
            return
        }

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedText = text
        } catch {
            fputs("Failed to save notes: \(error)\n", stderr)
        }
    }

    func flush() {
        save(lastSavedText)
    }
}
