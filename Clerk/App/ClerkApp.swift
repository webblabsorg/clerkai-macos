import SwiftUI
import AppKit

@main
struct ClerkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanel?
    private var hotKeyManager: HotKeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupFloatingPanel()
        setupHotKeys()
        
        // Hide dock icon (menu bar app)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "scale.3d", accessibilityDescription: "Clerk")
            button.action = #selector(togglePanel)
            button.target = self
        }
        
        setupStatusBarMenu()
    }
    
    private func setupStatusBarMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Clerk", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Clerk", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupFloatingPanel() {
        floatingPanel = FloatingPanel()
    }
    
    private func setupHotKeys() {
        hotKeyManager = HotKeyManager.shared
        hotKeyManager?.registerDefaultHotKeys()
    }
    
    @objc private func togglePanel() {
        floatingPanel?.toggle()
    }
    
    @objc private func showPanel() {
        floatingPanel?.show()
    }
    
    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
