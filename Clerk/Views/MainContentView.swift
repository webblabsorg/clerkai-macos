import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            backgroundView
            
            switch appState.currentUIState {
            case .minimized:
                AvatarView()
                    .transition(.scale.combined(with: .opacity))
            case .compact:
                CompactToolbarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .expanded:
                ExpandedPanelView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .toolExecution:
                ToolExecutionView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.currentUIState)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch appState.currentTheme {
        case .system:
            Color(nsColor: .windowBackgroundColor)
        case .light:
            Color(hex: "#FAFAFA") // Deep White
        case .dark:
            Color(hex: "#0A0A0A") // Deep Black
        case .cream:
            Color(hex: "#F5F0E8") // Deep Cream
        case .chocolate:
            Color(hex: "#2C1810") // Deep Chocolate
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    static let deepBlack = Color(hex: "#0A0A0A")
    static let deepWhite = Color(hex: "#FAFAFA")
    static let deepCream = Color(hex: "#F5F0E8")
    static let deepChocolate = Color(hex: "#2C1810")
    static let accentGold = Color(hex: "#C9A227")
    
    static func textColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light, .cream:
            return deepBlack
        case .dark, .chocolate, .system:
            return deepWhite
        }
    }
    
    static func backgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return deepWhite
        case .dark:
            return deepBlack
        case .cream:
            return deepCream
        case .chocolate:
            return deepChocolate
        case .system:
            return Color(nsColor: .windowBackgroundColor)
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState.shared)
        .frame(width: 400, height: 600)
}
