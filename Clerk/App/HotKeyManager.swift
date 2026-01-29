import Foundation
import Carbon
import AppKit
import ApplicationServices

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private let userDefaults = UserDefaultsManager.shared
    
    private var registeredHotKeys: [UInt32: HotKeyAction] = [:]
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var bindings: [HotKeyAction: HotKeyBinding] = [:]
    private var isUsingEventTap = false
    
    private init() {
        loadBindings()
        start()
    }
    
    deinit {
        unregisterAllHotKeys()
        stopEventTap()
    }
    
    // MARK: - Start / Stop
    
    private func start() {
        if ensureInputMonitoringPermission(prompt: false) {
            setupEventTap()
            isUsingEventTap = eventTap != nil
        }
        
        if !isUsingEventTap {
            setupEventHandler()
            registerBindingsWithCarbon()
        }
    }
    
    func openInputMonitoringPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Setup
    
    /// Input Monitoring permission is required for CGEventTap keyboard listening.
    /// This is distinct from Accessibility permission.
    @discardableResult
    func ensureInputMonitoringPermission(prompt: Bool) -> Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightListenEventAccess() {
                return true
            }
            if prompt {
                return CGRequestListenEventAccess()
            }
            return false
        }
        
        return true
    }
    
    private func setupEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handleKeyDown(event)
            return Unmanaged.passUnretained(event)
        }
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            setupEventHandler()
            registerBindingsWithCarbon()
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func stopEventTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }
    
    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        let modifiers = HotKeyModifiers(
            command: flags.contains(.maskCommand),
            shift: flags.contains(.maskShift),
            option: flags.contains(.maskAlternate),
            control: flags.contains(.maskControl)
        )
        
        guard let action = bindings.first(where: { _, binding in
            binding.keyCode == keyCode && binding.modifiers == modifiers
        })?.key else {
            return
        }
        
        DispatchQueue.main.async {
            self.dispatch(action)
        }
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            guard status == noErr else { return status }
            
            // Dispatch to main thread
            DispatchQueue.main.async {
                HotKeyManager.shared.handleHotKey(id: hotKeyID.id)
            }
            
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
    
    // MARK: - Registration
    
    func registerDefaultHotKeys() {
        bindings[.togglePanel] = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: HotKeyModifiers(command: true, shift: true, option: false, control: false)
        )
        bindings[.quickSummarize] = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: HotKeyModifiers(command: true, shift: true, option: false, control: false)
        )
        bindings[.quickRiskCheck] = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: HotKeyModifiers(command: true, shift: true, option: false, control: false)
        )
        
        persistBindings()
        if !isUsingEventTap {
            registerBindingsWithCarbon()
        }
    }
    
    private func registerBindingsWithCarbon() {
        unregisterAllHotKeys()
        
        // Carbon fallback is only used when CGEventTap isn't available.
        // Note: Carbon modifiers are different from CGEvent flags.
        for (action, binding) in bindings {
            register(keyCode: binding.keyCode, modifiers: binding.modifiers.carbonFlags, action: action)
        }
    }
    
    func register(keyCode: UInt32, modifiers: UInt32, action: HotKeyAction) {
        let id = UInt32(registeredHotKeys.count + 1)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C524B) // "CLRK"
        hotKeyID.id = id
        
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            registeredHotKeys[id] = action
            hotKeyRefs.append(hotKeyRef)
        }
    }
    
    func unregisterAllHotKeys() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        registeredHotKeys.removeAll()
    }
    
    // MARK: - Handling
    
    private func handleHotKey(id: UInt32) {
        guard let action = registeredHotKeys[id] else { return }
        
        dispatch(action)
    }
    
    private func dispatch(_ action: HotKeyAction) {
        switch action {
        case .togglePanel:
            NotificationCenter.default.post(name: .togglePanel, object: nil)
        case .quickSummarize:
            NotificationCenter.default.post(name: .quickAction, object: "document_summarizer")
        case .quickRiskCheck:
            NotificationCenter.default.post(name: .quickAction, object: "contract_risk_analyzer")
        case .minimize:
            AppState.shared.transitionTo(.minimized)
        case .expand:
            AppState.shared.transitionTo(.expanded)
        }
    }
    
    // MARK: - Persistence
    
    private func loadBindings() {
        if let toggle: HotKeyBinding = userDefaults.get(.togglePanelHotKey) {
            bindings[.togglePanel] = toggle
        }
        if let summarize: HotKeyBinding = userDefaults.get(.quickSummarizeHotKey) {
            bindings[.quickSummarize] = summarize
        }
        if let risk: HotKeyBinding = userDefaults.get(.quickRiskCheckHotKey) {
            bindings[.quickRiskCheck] = risk
        }

        if bindings.isEmpty {
            registerDefaultHotKeys()
            return
        }

        // Basic conflict detection: duplicates within our own bindings + obvious system conflicts.
        let values = Array(bindings.values)
        let hasInternalDuplicates = Set(values).count != values.count
        let hasLikelySystemConflict = values.contains(where: isLikelySystemShortcut)
        if hasInternalDuplicates || hasLikelySystemConflict {
            bindings.removeAll()
            registerDefaultHotKeys()
        }
    }
    
    private func persistBindings() {
        if let toggle = bindings[.togglePanel] {
            userDefaults.set(toggle, for: .togglePanelHotKey)
        }
        if let summarize = bindings[.quickSummarize] {
            userDefaults.set(summarize, for: .quickSummarizeHotKey)
        }
        if let risk = bindings[.quickRiskCheck] {
            userDefaults.set(risk, for: .quickRiskCheckHotKey)
        }
    }

    private func isLikelySystemShortcut(_ binding: HotKeyBinding) -> Bool {
        // Not exhaustive, but avoids a few common global shortcuts.
        // Cmd+Space (Spotlight)
        if binding.keyCode == UInt32(kVK_Space),
           binding.modifiers.command,
           !binding.modifiers.shift,
           !binding.modifiers.option,
           !binding.modifiers.control {
            return true
        }
        
        // Cmd+Tab (App switcher)
        if binding.keyCode == UInt32(kVK_Tab),
           binding.modifiers.command,
           !binding.modifiers.shift,
           !binding.modifiers.option,
           !binding.modifiers.control {
            return true
        }
        
        return false
    }
}

// MARK: - Hot Key Actions

enum HotKeyAction: String, Codable, CaseIterable {
    case togglePanel
    case quickSummarize
    case quickRiskCheck
    case minimize
    case expand
    
    var displayName: String {
        switch self {
        case .togglePanel: return "Toggle Panel"
        case .quickSummarize: return "Quick Summarize"
        case .quickRiskCheck: return "Quick Risk Check"
        case .minimize: return "Minimize"
        case .expand: return "Expand"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let togglePanel = Notification.Name("com.clerk.togglePanel")
    static let quickAction = Notification.Name("com.clerk.quickAction")
}

// MARK: - Binding Types

struct HotKeyBinding: Codable, Hashable {
    let keyCode: UInt32
    let modifiers: HotKeyModifiers
}

struct HotKeyModifiers: Codable, Hashable {
    let command: Bool
    let shift: Bool
    let option: Bool
    let control: Bool

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if command { flags |= UInt32(cmdKey) }
        if shift { flags |= UInt32(shiftKey) }
        if option { flags |= UInt32(optionKey) }
        if control { flags |= UInt32(controlKey) }
        return flags
    }
}

struct HotKeyBindingsStore: Codable {
    let bindings: [HotKeyAction: HotKeyBinding]
}
