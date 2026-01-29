import SwiftUI

struct ExpandedPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: ToolCategory?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .background(ThemeColors.accentGold.opacity(0.3))
            
            // Search bar
            searchBar
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Suggested tools
                    if searchText.isEmpty {
                        suggestedSection
                        categoriesSection
                        recentSection
                    } else {
                        searchResultsSection
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 600)
        .background(ThemeColors.backgroundColor(for: appState.currentTheme))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                appState.transitionTo(.compact)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Clerk Legal AI")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    appState.transitionTo(.minimized)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                }
                .buttonStyle(.plain)
                
                Button {
                    // Close panel
                    NotificationCenter.default.post(name: .togglePanel, object: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
            
            TextField("Search 301 tools...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Suggested Section
    
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SUGGESTED FOR YOU")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(appState.suggestedTools.prefix(4)) { tool in
                    ToolCard(tool: tool) {
                        appState.setTool(tool)
                    }
                }
            }
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CATEGORIES")
            
            VStack(spacing: 4) {
                ForEach(ToolCategory.allCases.prefix(6), id: \.self) { category in
                    CategoryRow(category: category) {
                        selectedCategory = category
                    }
                }
                
                Button {
                    // Show all categories
                } label: {
                    Text("View All 18 Categories")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ThemeColors.accentGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Recent Section
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("RECENT")
            
            VStack(spacing: 8) {
                RecentToolRow(name: "Contract Risk Analyzer", timeAgo: "2m ago")
                RecentToolRow(name: "Deposition Summarizer", timeAgo: "1h ago")
                RecentToolRow(name: "Legal Email Drafter", timeAgo: "3h ago")
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SEARCH RESULTS")
            
            // TODO: Implement actual search
            Text("Searching for \"\(searchText)\"...")
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.6))
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
            .tracking(0.5)
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 24))
                    .foregroundColor(ThemeColors.accentGold)
                
                Text(tool.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                    .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ToolCategory
    let onTap: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(ThemeColors.accentGold)
                    .frame(width: 24)
                
                Text(category.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                
                Text("(\(category.toolCount))")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.3))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Tool Row

struct RecentToolRow: View {
    let name: String
    let timeAgo: String
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Circle()
                .fill(ThemeColors.accentGold.opacity(0.3))
                .frame(width: 6, height: 6)
            
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Spacer()
            
            Text(timeAgo)
                .font(.system(size: 11))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpandedPanelView()
        .environmentObject(AppState.shared)
}
