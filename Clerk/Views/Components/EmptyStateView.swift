import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ThemeColors.accentGold.opacity(0.6))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct NoResultsView: View {
    @EnvironmentObject var appState: AppState
    
    let searchQuery: String
    
    var body: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No tools found for \"\(searchQuery)\". Try a different search term."
        )
    }
}

struct NoRecentToolsView: View {
    var body: some View {
        EmptyStateView(
            icon: "clock",
            title: "No Recent Tools",
            message: "Tools you use will appear here for quick access."
        )
    }
}

struct NoFavoritesView: View {
    var body: some View {
        EmptyStateView(
            icon: "star",
            title: "No Favorites",
            message: "Star your favorite tools for quick access."
        )
    }
}

struct OfflineView: View {
    var onRetry: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "wifi.slash",
            title: "No Connection",
            message: "Please check your internet connection and try again.",
            actionTitle: "Retry",
            action: onRetry
        )
    }
}

struct ErrorStateView: View {
    let error: Error
    var onRetry: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: ErrorHandler.shared.userMessage(for: error),
            actionTitle: onRetry != nil ? "Try Again" : nil,
            action: onRetry
        )
    }
}

#Preview {
    VStack(spacing: 40) {
        NoResultsView(searchQuery: "test")
        NoRecentToolsView()
    }
    .environmentObject(AppState.shared)
}
