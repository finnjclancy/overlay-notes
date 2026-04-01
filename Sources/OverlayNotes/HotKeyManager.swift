import Carbon
import Foundation

private let overlayNotesHotKeySignature: OSType = 0x4F564E54

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    var eventHotKeyID = EventHotKeyID()

    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventHotKeyID
    )

    if status == noErr, eventHotKeyID.signature == overlayNotesHotKeySignature, eventHotKeyID.id == manager.hotKeyID {
        manager.fire()
        return noErr
    }

    return OSStatus(eventNotHandledErr)
}

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void
    fileprivate let hotKeyID: UInt32

    init(
        keyCode: UInt32,
        modifiers: UInt32,
        hotKeyID: UInt32 = 1,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        self.hotKeyID = hotKeyID

        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            userData,
            &eventHandler
        )

        let carbonHotKeyID = EventHotKeyID(signature: overlayNotesHotKeySignature, id: hotKeyID)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    fileprivate func fire() {
        handler()
    }
}
