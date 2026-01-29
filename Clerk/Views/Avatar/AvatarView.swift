import SwiftUI

struct AvatarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isBreathing = false
    @State private var isPulsing = false
    @State private var dragOffset: CGSize = .zero
    
    private let avatarSize: CGFloat = 48
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(ThemeColors.accentGold.opacity(0.3))
                .frame(width: avatarSize + 8, height: avatarSize + 8)
                .blur(radius: 8)
                .scaleEffect(isBreathing ? 1.1 : 1.0)
            
            // Pulse effect on context detection
            if isPulsing {
                Circle()
                    .stroke(ThemeColors.accentGold, lineWidth: 2)
                    .frame(width: avatarSize + 16, height: avatarSize + 16)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            }
            
            // Main avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ThemeColors.accentGold, ThemeColors.accentGold.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: avatarSize, height: avatarSize)
                .shadow(color: ThemeColors.accentGold.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Icon
            Image(systemName: "scale.3d")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(ThemeColors.deepBlack)
        }
        .offset(dragOffset)
        .gesture(dragGesture)
        .onTapGesture {
            appState.transitionTo(.compact)
        }
        .onTapGesture(count: 2) {
            appState.transitionTo(.expanded)
        }
        .onAppear {
            startBreathingAnimation()
        }
        .onChange(of: appState.detectedContext) { _, newContext in
            if newContext != nil {
                triggerPulse()
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Persist new position
                dragOffset = .zero
                // Position is handled by FloatingPanel
            }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
        }
    }
    
    private func triggerPulse() {
        isPulsing = true
        withAnimation(.easeOut(duration: 0.6)) {
            isPulsing = false
        }
    }
}

#Preview {
    AvatarView()
        .environmentObject(AppState.shared)
        .frame(width: 100, height: 100)
        .background(ThemeColors.deepBlack)
}
