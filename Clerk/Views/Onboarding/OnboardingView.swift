import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let totalSteps = 4
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
            
            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionsStep.tag(1)
                authStep.tag(2)
                completeStep.tag(3)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: currentStep)
            
            // Navigation
            navigationButtons
        }
        .frame(width: 500, height: 450)
        .background(ThemeColors.backgroundColor(for: appState.currentTheme))
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ThemeColors.accentGold : ThemeColors.accentGold.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "scale.3d")
                .font(.system(size: 64))
                .foregroundColor(ThemeColors.accentGold)
            
            Text("Welcome to Clerk")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Text("Your AI-powered legal assistant that works alongside your everyday applications.")
                .font(.system(size: 16))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Permissions Step
    
    private var permissionsStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Permissions Required")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            VStack(alignment: .leading, spacing: 16) {
                permissionRow(
                    icon: "keyboard",
                    title: "Accessibility",
                    description: "Required to detect context and read selected text"
                )
                
                permissionRow(
                    icon: "bell",
                    title: "Notifications",
                    description: "Get alerts for completed analyses and suggestions"
                )
            }
            .padding(.horizontal, 40)
            
            Button("Open System Preferences") {
                openAccessibilityPreferences()
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
        }
    }
    
    private func permissionRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ThemeColors.accentGold)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
            }
        }
    }
    
    // MARK: - Auth Step
    
    private var authStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Sign In")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                            .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
                    )
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                            .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
                    )
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                
                Button {
                    signIn()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 60)
            
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                Button("Sign Up") {
                    // Open sign up in browser
                }
                .foregroundColor(ThemeColors.accentGold)
            }
            .font(.system(size: 13))
            
            Spacer()
        }
    }
    
    // MARK: - Complete Step
    
    private var completeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Text("Clerk is ready to assist you. Use ⌘⇧C to toggle the panel anytime.")
                .font(.system(size: 16))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "hand.tap", text: "Click the avatar to expand")
                tipRow(icon: "keyboard", text: "Use ⌘⇧C to toggle anytime")
                tipRow(icon: "doc.text", text: "Select text to get suggestions")
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ThemeColors.accentGold)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.8))
        }
    }
    
    // MARK: - Navigation
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
    }
    
    // MARK: - Actions
    
    private func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await AuthService.shared.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    currentStep += 1
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaultsManager.shared.hasCompletedOnboarding = true
        // Close onboarding window
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.shared)
}
