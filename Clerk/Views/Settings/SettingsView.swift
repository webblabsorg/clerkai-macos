import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            HotKeySettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            AccountSettingsView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
            
            LanguageSettingsView()
                .tabItem {
                    Label("Language", systemImage: "globe")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show in Dock", isOn: $showInDock)
                Toggle("Show in menu bar", isOn: $showInMenuBar)
            }
            
            Section("Behavior") {
                Toggle("Show suggestions automatically", isOn: .constant(true))
                Toggle("Play sounds", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appState.currentTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        HStack {
                            Circle()
                                .fill(themePreviewColor(theme))
                                .frame(width: 16, height: 16)
                            Text(theme.displayName)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Section("Preview") {
                themePreview
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: appState.currentTheme) { _, newTheme in
            UserDefaults.standard.set(newTheme.rawValue, forKey: "appTheme")
        }
    }
    
    private func themePreviewColor(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .gray
        case .light: return ThemeColors.deepWhite
        case .dark: return ThemeColors.deepBlack
        case .cream: return ThemeColors.deepCream
        case .chocolate: return ThemeColors.deepChocolate
        }
    }
    
    private var themePreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sample Text")
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                Spacer()
                Button("Button") {}
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.backgroundColor(for: appState.currentTheme))
            )
        }
        .padding()
    }
}

// MARK: - HotKey Settings

struct HotKeySettingsView: View {
    var body: some View {
        Form {
            Section("Global Shortcuts") {
                HStack {
                    Text("Toggle Panel")
                    Spacer()
                    Text("⌘⇧C")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("Quick Summarize")
                    Spacer()
                    Text("⌘⇧S")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("Quick Risk Check")
                    Spacer()
                    Text("⌘⇧R")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            if let user = appState.currentUser {
                Section("Profile") {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Name", value: user.name ?? "Not set")
                    LabeledContent("Plan", value: user.subscriptionTier.displayName)
                }
                
                Section("Usage") {
                    if let remaining = user.remainingMonthlyRuns {
                        LabeledContent("Monthly runs remaining", value: "\(remaining)")
                    } else {
                        LabeledContent("Monthly runs", value: "Unlimited")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                }
            } else {
                Section {
                    Text("Not signed in")
                    Button("Sign In") {
                        signIn()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func signIn() {
        // TODO: Implement sign in
    }
    
    private func signOut() {
        appState.currentUser = nil
        appState.isAuthenticated = false
    }
}

// MARK: - Language Settings

struct LanguageSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLanguage: String = "en"
    @State private var searchText = ""
    
    var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allSupported
        }
        return Language.allSupported.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nativeName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            TextField("Search languages...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            // Language list
            List(filteredLanguages, selection: $selectedLanguage) { language in
                HStack {
                    VStack(alignment: .leading) {
                        Text(language.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(language.nativeName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if language.isRTL {
                        Text("RTL")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if language.code == selectedLanguage {
                        Image(systemName: "checkmark")
                            .foregroundColor(ThemeColors.accentGold)
                    }
                }
                .tag(language.code)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
