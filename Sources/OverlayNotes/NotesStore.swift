import Foundation

final class NotesStore: NSObject {
    private let fileManager: FileManager
    private let fileURL: URL
    private var lastSavedText = ""
    private var pendingText: String?
    private var saveTimer: Timer?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let directoryURL = appSupportURL.appendingPathComponent("OverlayNotes", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("notes.txt")

        super.init()

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            fputs("Failed to create notes directory: \(error)\n", stderr)
        }
    }

    func load() -> String {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ""
        }

        lastSavedText = text
        return text
    }

    func save(_ text: String) {
        guard text != lastSavedText || pendingText != nil else {
            return
        }

        pendingText = text
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(
            timeInterval: 0.6,
            target: self,
            selector: #selector(persistPendingText),
            userInfo: nil,
            repeats: false
        )
    }

    func flush() {
        saveTimer?.invalidate()
        saveTimer = nil
        persistPendingText()
    }

    @objc private func persistPendingText() {
        guard let text = pendingText, text != lastSavedText else {
            pendingText = nil
            return
        }

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedText = text
            pendingText = nil
        } catch {
            fputs("Failed to save notes: \(error)\n", stderr)
        }
    }
}
