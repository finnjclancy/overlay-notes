import AppKit

enum TextColorChoice: String {
    case black
    case white
    case grey
    case red
    case yellow
    case blue

    var color: NSColor {
        switch self {
        case .black:
            return .black
        case .white:
            return .white
        case .grey:
            return NSColor(calibratedWhite: 0.7, alpha: 1.0)
        case .red:
            return .systemRed
        case .yellow:
            return .systemYellow
        case .blue:
            return .systemBlue
        }
    }

    var placeholderColor: NSColor {
        switch self {
        case .black:
            return NSColor.black.withAlphaComponent(0.35)
        case .white:
            return NSColor.white.withAlphaComponent(0.35)
        case .grey:
            return NSColor(calibratedWhite: 0.7, alpha: 0.4)
        case .red:
            return NSColor.systemRed.withAlphaComponent(0.45)
        case .yellow:
            return NSColor.systemYellow.withAlphaComponent(0.55)
        case .blue:
            return NSColor.systemBlue.withAlphaComponent(0.45)
        }
    }

    var segmentIndex: Int {
        switch self {
        case .black:
            return 0
        case .white:
            return 1
        case .grey:
            return 2
        case .red:
            return 3
        case .yellow:
            return 4
        case .blue:
            return 5
        }
    }

    static func fromSegment(_ index: Int) -> TextColorChoice {
        switch index {
        case 0:
            return .black
        case 1:
            return .white
        case 2:
            return .grey
        case 3:
            return .red
        case 4:
            return .yellow
        default:
            return .blue
        }
    }
}

enum OverlayMode: String {
    case normalEdit
    case transparentEdit
    case readOnly

    var next: OverlayMode {
        switch self {
        case .normalEdit:
            return .transparentEdit
        case .transparentEdit:
            return .readOnly
        case .readOnly:
            return .normalEdit
        }
    }

    var isEditable: Bool {
        self != .readOnly
    }

    var isTransparent: Bool {
        self != .normalEdit
    }

    var segmentIndex: Int {
        switch self {
        case .normalEdit:
            return 0
        case .transparentEdit:
            return 1
        case .readOnly:
            return 2
        }
    }

    var displayName: String {
        switch self {
        case .normalEdit:
            return "Normal Edit"
        case .transparentEdit:
            return "Transparent Edit"
        case .readOnly:
            return "Read-Only"
        }
    }

    static func fromSegment(_ index: Int) -> OverlayMode {
        switch index {
        case 0:
            return .normalEdit
        case 1:
            return .transparentEdit
        default:
            return .readOnly
        }
    }
}

@MainActor
final class NotesWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    private static let frameAutosaveName = "OverlayNotes.WindowFrame"
    private let minimumFontSize: CGFloat = 10
    private let maximumFontSize: CGFloat = 18

    private let notesStore: NotesStore
    private let rootView = NSView()
    private let controlsContainer = NSView()
    private let editorBackground = NSView()
    private let scrollView = NSScrollView()
    private let textView = NotesTextView()
    private let placeholderLabel = NSTextField(labelWithString: "Paste notes here")
    private let modeControl = NSSegmentedControl(labels: ["E", "T", "R"], trackingMode: .selectOne, target: nil, action: nil)
    private let colorControl = NSSegmentedControl(labels: ["B", "W", "G", "R", "Y", "U"], trackingMode: .selectOne, target: nil, action: nil)
    private let fontSizeLabel = NSTextField(labelWithString: "")
    private let fontSizeDownButton = NSButton(title: "-", target: nil, action: nil)
    private let fontSizeUpButton = NSButton(title: "+", target: nil, action: nil)

    private var activeSpaceObserver: NSObjectProtocol?
    private var hasPlacedWindow = false
    private var mode: OverlayMode
    private var fontSize: CGFloat
    private var textColorChoice: TextColorChoice
    private var controlsHeightConstraint: NSLayoutConstraint?

    var onVisibilityChange: (@MainActor (Bool) -> Void)?
    var onModeChange: (@MainActor (OverlayMode) -> Void)?
    var onFontSizeChange: (@MainActor (CGFloat) -> Void)?
    var onTextColorChange: (@MainActor (TextColorChoice) -> Void)?

    var isWindowVisible: Bool {
        window?.isVisible == true
    }

    init(
        notesStore: NotesStore,
        mode: OverlayMode,
        fontSize: CGFloat,
        textColorChoice: TextColorChoice
    ) {
        self.notesStore = notesStore
        self.mode = mode
        self.fontSize = fontSize
        self.textColorChoice = textColorChoice

        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        configureWindow(panel)
        configureContent(in: panel)
        restoreNotes()
        applyPresentationMode()
        registerObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleVisibility() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindowAndFocus()
        }
    }

    func showWindowAndFocus() {
        guard let panel = window as? OverlayPanel else {
            return
        }

        placeWindowIfNeeded(panel)
        keepWindowPinned()

        if !mode.isEditable {
            panel.orderFrontRegardless()
        } else {
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(textView)
        }

        onVisibilityChange?(true)
    }

    func hideWindow() {
        notesStore.flush()
        window?.orderOut(nil)
        onVisibilityChange?(false)
    }

    func cycleMode() {
        mode = mode.next
        applyPresentationMode()
        onModeChange?(mode)
    }

    func cycleTextColor() {
        switch textColorChoice {
        case .black:
            textColorChoice = .white
        case .white:
            textColorChoice = .grey
        case .grey:
            textColorChoice = .red
        case .red:
            textColorChoice = .yellow
        case .yellow:
            textColorChoice = .blue
        case .blue:
            textColorChoice = .black
        }

        applyPresentationMode()
        onTextColorChange?(textColorChoice)
    }

    func textDidChange(_ notification: Notification) {
        placeholderLabel.isHidden = !textView.string.isEmpty
        notesStore.save(textView.string)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    @objc private func modeControlChanged(_ sender: NSSegmentedControl) {
        mode = OverlayMode.fromSegment(sender.selectedSegment)
        applyPresentationMode()
        onModeChange?(mode)
    }

    @objc private func colorControlChanged(_ sender: NSSegmentedControl) {
        textColorChoice = TextColorChoice.fromSegment(sender.selectedSegment)
        applyPresentationMode()
        onTextColorChange?(textColorChoice)
    }

    @objc private func decreaseFontSize(_ sender: Any?) {
        setFontSize(fontSize - 1)
    }

    @objc private func increaseFontSize(_ sender: Any?) {
        setFontSize(fontSize + 1)
    }

    private func configureWindow(_ window: OverlayPanel) {
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 280, height: 240)
        window.delegate = self
        updateStandardButtonsVisibility(for: window)
        if window.setFrameUsingName(Self.frameAutosaveName) {
            hasPlacedWindow = true
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
    }

    private func configureContent(in window: NSWindow) {
        rootView.wantsLayer = true
        rootView.translatesAutoresizingMaskIntoConstraints = false

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false

        modeControl.segmentStyle = .capsule
        modeControl.controlSize = .small
        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))
        modeControl.toolTip = "Mode"
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        colorControl.segmentStyle = .capsule
        colorControl.controlSize = .small
        colorControl.target = self
        colorControl.action = #selector(colorControlChanged(_:))
        colorControl.toolTip = "B black, W white, G grey, R red, Y yellow, U blue"
        colorControl.translatesAutoresizingMaskIntoConstraints = false

        fontSizeDownButton.bezelStyle = .rounded
        fontSizeDownButton.controlSize = .mini
        fontSizeDownButton.target = self
        fontSizeDownButton.action = #selector(decreaseFontSize(_:))
        fontSizeDownButton.translatesAutoresizingMaskIntoConstraints = false

        fontSizeUpButton.bezelStyle = .rounded
        fontSizeUpButton.controlSize = .mini
        fontSizeUpButton.target = self
        fontSizeUpButton.action = #selector(increaseFontSize(_:))
        fontSizeUpButton.translatesAutoresizingMaskIntoConstraints = false

        fontSizeLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        fontSizeLabel.textColor = .secondaryLabelColor
        fontSizeLabel.alignment = .center
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        editorBackground.wantsLayer = true
        editorBackground.layer?.cornerRadius = 8
        editorBackground.layer?.borderWidth = 1
        editorBackground.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        textView.frame = NSRect(x: 0, y: 0, width: 320, height: 360)
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.delegate = self
        textView.string = ""
        textView.font = .systemFont(ofSize: fontSize)
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView

        placeholderLabel.font = .systemFont(ofSize: fontSize)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        editorBackground.addSubview(scrollView)
        editorBackground.addSubview(placeholderLabel)

        controlsContainer.addSubview(modeControl)
        controlsContainer.addSubview(colorControl)
        controlsContainer.addSubview(fontSizeDownButton)
        controlsContainer.addSubview(fontSizeLabel)
        controlsContainer.addSubview(fontSizeUpButton)

        rootView.addSubview(controlsContainer)
        rootView.addSubview(editorBackground)

        window.contentView = rootView

        controlsHeightConstraint = controlsContainer.heightAnchor.constraint(equalToConstant: 18)

        NSLayoutConstraint.activate([
            controlsContainer.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 2),
            controlsContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            controlsContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            controlsHeightConstraint!,

            modeControl.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
            modeControl.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 72),

            colorControl.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            colorControl.leadingAnchor.constraint(equalTo: modeControl.trailingAnchor, constant: 4),
            colorControl.widthAnchor.constraint(equalToConstant: 150),

            fontSizeUpButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            fontSizeUpButton.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            fontSizeUpButton.widthAnchor.constraint(equalToConstant: 22),

            fontSizeLabel.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            fontSizeLabel.trailingAnchor.constraint(equalTo: fontSizeUpButton.leadingAnchor, constant: -4),
            fontSizeLabel.widthAnchor.constraint(equalToConstant: 22),

            fontSizeDownButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            fontSizeDownButton.trailingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor, constant: -4),
            fontSizeDownButton.widthAnchor.constraint(equalToConstant: 22),

            editorBackground.topAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: 2),
            editorBackground.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            editorBackground.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            editorBackground.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: editorBackground.topAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: editorBackground.leadingAnchor, constant: 2),
            scrollView.trailingAnchor.constraint(equalTo: editorBackground.trailingAnchor, constant: -2),
            scrollView.bottomAnchor.constraint(equalTo: editorBackground.bottomAnchor, constant: -2),

            placeholderLabel.topAnchor.constraint(equalTo: editorBackground.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: editorBackground.leadingAnchor, constant: 14),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: editorBackground.trailingAnchor, constant: -14)
        ])
    }

    private func registerObservers() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.keepWindowPinned()
            }
        }
    }

    private func restoreNotes() {
        textView.string = notesStore.load()
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    private func applyPresentationMode() {
        guard let panel = window as? OverlayPanel else {
            return
        }

        let isEditable = mode.isEditable
        let isTransparent = mode.isTransparent

        updateStandardButtonsVisibility(for: panel)

        controlsContainer.isHidden = isTransparent
        controlsHeightConstraint?.constant = isTransparent ? 0 : 18

        panel.allowsKeyFocus = isEditable
        panel.ignoresMouseEvents = !isEditable
        panel.hasShadow = !isTransparent

        modeControl.selectedSegment = mode.segmentIndex
        colorControl.selectedSegment = textColorChoice.segmentIndex
        fontSizeLabel.stringValue = "\(Int(fontSize))"

        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.allowsEditingInteraction = isEditable
        textView.font = .systemFont(ofSize: fontSize)
        placeholderLabel.font = .systemFont(ofSize: fontSize)

        fontSizeDownButton.isEnabled = isEditable
        fontSizeUpButton.isEnabled = isEditable
        colorControl.isEnabled = isEditable

        if isTransparent {
            rootView.layer?.backgroundColor = NSColor.clear.cgColor
            editorBackground.layer?.borderColor = NSColor.clear.cgColor
            editorBackground.layer?.backgroundColor = NSColor.clear.cgColor
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textColor = textColorChoice.color
            textView.insertionPointColor = isEditable ? textColorChoice.color : .clear
            placeholderLabel.textColor = textColorChoice.placeholderColor
        } else {
            let backgroundColor = editorBackgroundColor()
            rootView.layer?.backgroundColor = backgroundColor.cgColor
            editorBackground.layer?.borderColor = NSColor.separatorColor.cgColor
            editorBackground.layer?.backgroundColor = backgroundColor.cgColor
            scrollView.drawsBackground = true
            scrollView.backgroundColor = backgroundColor
            textView.drawsBackground = true
            textView.backgroundColor = backgroundColor
            textView.textColor = textColorChoice.color
            textView.insertionPointColor = textColorChoice.color
            placeholderLabel.textColor = textColorChoice.placeholderColor
        }

        if panel.isVisible {
            if isEditable {
                panel.makeKeyAndOrderFront(nil)
                panel.makeFirstResponder(textView)
            } else {
                panel.makeFirstResponder(nil)
                panel.resignKey()
                panel.orderFrontRegardless()
            }
        }
    }

    private func setFontSize(_ proposedSize: CGFloat) {
        let clampedSize = min(max(proposedSize, minimumFontSize), maximumFontSize)
        guard clampedSize != fontSize else {
            return
        }

        fontSize = clampedSize
        applyPresentationMode()
        onFontSizeChange?(fontSize)
    }

    private func editorBackgroundColor() -> NSColor {
        switch textColorChoice {
        case .white:
            return NSColor(calibratedWhite: 0.12, alpha: 1.0)
        case .grey:
            return NSColor(calibratedWhite: 0.12, alpha: 1.0)
        case .yellow:
            return NSColor(calibratedWhite: 0.12, alpha: 1.0)
        case .black, .red, .blue:
            return NSColor(calibratedWhite: 0.98, alpha: 1.0)
        }
    }

    private func keepWindowPinned() {
        guard let window, window.isVisible else {
            return
        }

        window.level = .statusBar
        window.orderFrontRegardless()
        updateStandardButtonsVisibility(for: window)
    }

    private func placeWindowIfNeeded(_ window: NSWindow) {
        guard !hasPlacedWindow else {
            return
        }

        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetFrame = NSRect(
            x: visibleFrame.maxX - 420,
            y: visibleFrame.maxY - 560,
            width: 380,
            height: 492
        )
        window.setFrame(targetFrame, display: true)
        hasPlacedWindow = true
    }

    private func updateStandardButtonsVisibility(for window: NSWindow) {
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

private final class OverlayPanel: NSPanel {
    var allowsKeyFocus = true

    override var canBecomeKey: Bool { allowsKeyFocus }
    override var canBecomeMain: Bool { allowsKeyFocus }
}

private final class NotesTextView: NSTextView {
    var allowsEditingInteraction = true

    override var acceptsFirstResponder: Bool {
        allowsEditingInteraction
    }

    override var needsPanelToBecomeKey: Bool {
        allowsEditingInteraction
    }

    override func mouseDown(with event: NSEvent) {
        guard allowsEditingInteraction else {
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard allowsEditingInteraction else {
            return
        }

        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard allowsEditingInteraction else {
            return
        }

        super.mouseUp(with: event)
    }

    override func paste(_ sender: Any?) {
        guard allowsEditingInteraction else {
            return
        }

        guard let pastedText = preferredPasteString(from: .general) else {
            super.paste(sender)
            return
        }

        insertPastedText(pastedText)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard allowsEditingInteraction, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }

        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch characters {
        case "x":
            cut(nil)
            return true
        case "c":
            copy(nil)
            return true
        case "v":
            paste(nil)
            return true
        case "a":
            selectAll(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    private func preferredPasteString(from pasteboard: NSPasteboard) -> String? {
        let richTextSources: [(NSPasteboard.PasteboardType, NSAttributedString.DocumentType)] = [
            (.html, .html),
            (.rtf, .rtf),
            (.rtfd, .rtfd)
        ]

        for (pasteboardType, documentType) in richTextSources {
            guard let data = pasteboard.data(forType: pasteboardType),
                  let importedString = importedString(from: data, documentType: documentType),
                  !importedString.isEmpty else {
                continue
            }

            return normalizedPasteString(importedString)
        }

        guard let plainText = pasteboard.string(forType: .string), !plainText.isEmpty else {
            return nil
        }

        return normalizedPasteString(plainText)
    }

    private func importedString(from data: Data, documentType: NSAttributedString.DocumentType) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        return try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ).string
    }

    private func normalizedPasteString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func insertPastedText(_ string: String) {
        let replacementRange = selectedRange()
        guard shouldChangeText(in: replacementRange, replacementString: string) else {
            return
        }

        let attributes = typingAttributes.isEmpty ? [:] : typingAttributes
        let attributedString = NSAttributedString(string: string, attributes: attributes)
        textStorage?.replaceCharacters(in: replacementRange, with: attributedString)
        didChangeText()

        let insertedLength = attributedString.length
        setSelectedRange(NSRange(location: replacementRange.location + insertedLength, length: 0))
    }
}
