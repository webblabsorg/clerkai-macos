import SwiftUI
import AppKit

class FloatingPanel: NSPanel {
    private var hostingView: NSHostingView<AnyView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
        setupContent()
        restorePosition()
    }
    
    private func setupPanel() {
        // Panel behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        
        // Appearance
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        
        // Hide standard buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    private func setupContent() {
        let contentView = MainContentView()
            .environmentObject(AppState.shared)
        
        hostingView = NSHostingView(rootView: AnyView(contentView))
        hostingView?.translatesAutoresizingMaskIntoConstraints = false
        
        if let hostingView = hostingView {
            self.contentView = hostingView
        }
    }
    
    private func restorePosition() {
        if let positionData = UserDefaults.standard.data(forKey: "panelPosition"),
           let position = try? JSONDecoder().decode(PanelPosition.self, from: positionData) {
            setFrameOrigin(NSPoint(x: position.x, y: position.y))
        } else {
            center()
        }
    }
    
    private func savePosition() {
        let position = PanelPosition(x: frame.origin.x, y: frame.origin.y)
        if let data = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(data, forKey: "panelPosition")
        }
    }
    
    override func close() {
        savePosition()
        super.close()
    }
    
    // MARK: - Public Methods
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        savePosition()
        orderOut(nil)
    }
    
    // MARK: - Size Management
    
    func updateSize(for state: UIState) {
        let newSize: NSSize
        
        switch state {
        case .minimized:
            newSize = NSSize(width: 48, height: 48)
        case .compact:
            newSize = NSSize(width: 320, height: 56)
        case .expanded:
            newSize = NSSize(width: 400, height: 600)
        case .toolExecution:
            newSize = NSSize(width: 450, height: 650)
        }
        
        let newFrame = NSRect(
            origin: frame.origin,
            size: newSize
        )
        
        setFrame(newFrame, display: true, animate: true)
    }
}

// MARK: - Position Persistence

private struct PanelPosition: Codable {
    let x: CGFloat
    let y: CGFloat
}
