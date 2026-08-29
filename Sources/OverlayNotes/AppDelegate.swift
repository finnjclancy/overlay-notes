import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notesStore: NotesStore?
    private var settingsStore: SettingsStore?
    private var notesWindowController: NotesWindowController?
    private var visibilityHotKeyManager: HotKeyManager?
    private var modeHotKeyManager: HotKeyManager?
    private var colorHotKeyManager: HotKeyManager?
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var modeMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapIfNeeded()
        notesWindowController?.showWindowAndFocus()
        updateMenuState(isVisible: notesWindowController?.isWindowVisible == true)
        updateModeMenuState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notesStore?.flush()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bootstrapIfNeeded()

        if !flag {
            notesWindowController?.showWindowAndFocus()
        }

        return true
    }

    @objc private func toggleNotes(_ sender: Any?) {
        bootstrapIfNeeded()
        notesWindowController?.toggleVisibility()
    }

    @objc private func cycleMode(_ sender: Any?) {
        bootstrapIfNeeded()
        notesWindowController?.cycleMode()
    }

    @objc private func cycleTextColor(_ sender: Any?) {
        bootstrapIfNeeded()
        notesWindowController?.cycleTextColor()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        guard statusItem == nil else {
            return
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Notes"
        statusItem.button?.toolTip = "Overlay Notes"

        let menu = NSMenu()
        let toggleMenuItem = NSMenuItem(
            title: "",
            action: #selector(toggleNotes(_:)),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        let modeMenuItem = NSMenuItem(
            title: "",
            action: #selector(cycleMode(_:)),
            keyEquivalent: ""
        )
        modeMenuItem.target = self
        menu.addItem(modeMenuItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Overlay Notes",
            action: #selector(quitApp(_:)),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
        self.toggleMenuItem = toggleMenuItem
        self.modeMenuItem = modeMenuItem
    }

    private func updateMenuState(isVisible: Bool) {
        guard let toggleMenuItem else {
            return
        }

        let actionName = isVisible ? "Hide Notes" : "Show Notes"
        toggleMenuItem.title = "\(actionName) (Control + Option + Command + N)"
    }

    private func updateModeMenuState() {
        let mode = OverlayMode(rawValue: settingsStore?.overlayMode ?? "") ?? .normalEdit
        modeMenuItem?.title = "Mode: \(mode.displayName) (Control + Option + Command + R)"
    }

    private func bootstrapIfNeeded() {
        if notesStore == nil {
            notesStore = NotesStore()
        }

        if settingsStore == nil {
            settingsStore = SettingsStore()
        }

        if notesWindowController == nil, let notesStore, let settingsStore {
            let mode = OverlayMode(rawValue: settingsStore.overlayMode) ?? .normalEdit
            let controller = NotesWindowController(
                notesStore: notesStore,
                mode: mode,
                fontSize: settingsStore.fontSize,
                textColorChoice: TextColorChoice(rawValue: settingsStore.textColorChoice) ?? .white
            )
            controller.onVisibilityChange = { [weak self] isVisible in
                self?.updateMenuState(isVisible: isVisible)
            }
            controller.onModeChange = { [weak self] mode in
                self?.settingsStore?.overlayMode = mode.rawValue
                self?.updateModeMenuState()
            }
            controller.onFontSizeChange = { [weak self] fontSize in
                self?.settingsStore?.fontSize = fontSize
            }
            controller.onTextColorChange = { [weak self] textColorChoice in
                self?.settingsStore?.textColorChoice = textColorChoice.rawValue
            }
            notesWindowController = controller
        }

        configureStatusItem()

        if visibilityHotKeyManager == nil {
            visibilityHotKeyManager = HotKeyManager(
                keyCode: UInt32(kVK_ANSI_N),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.toggleNotes(nil)
                }
            }
        }

        if modeHotKeyManager == nil {
            modeHotKeyManager = HotKeyManager(
                keyCode: UInt32(kVK_ANSI_R),
                modifiers: UInt32(controlKey | optionKey | cmdKey),
                hotKeyID: 2
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.cycleMode(nil)
                }
            }
        }

        if colorHotKeyManager == nil {
            colorHotKeyManager = HotKeyManager(
                keyCode: UInt32(kVK_ANSI_C),
                modifiers: UInt32(controlKey | optionKey | cmdKey),
                hotKeyID: 3
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.cycleTextColor(nil)
                }
            }
        }
    }
}
