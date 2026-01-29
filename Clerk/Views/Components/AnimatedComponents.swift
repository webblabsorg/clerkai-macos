import SwiftUI

// MARK: - Breathing Animation

struct BreathingView<Content: View>: View {
    let content: Content
    @State private var isBreathing = false
    
    var scale: CGFloat = 1.05
    var duration: Double = 2.0
    
    init(scale: CGFloat = 1.05, duration: Double = 2.0, @ViewBuilder content: () -> Content) {
        self.scale = scale
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(isBreathing ? scale : 1.0)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear {
                isBreathing = true
            }
    }
}

// MARK: - Pulse Animation

struct PulseView<Content: View>: View {
    let content: Content
    @State private var isPulsing = false
    
    var color: Color = ThemeColors.accentGold
    var duration: Double = 1.5
    
    init(color: Color = ThemeColors.accentGold, duration: Double = 1.5, @ViewBuilder content: () -> Content) {
        self.color = color
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.0 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: duration)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: isPulsing
                    )
            }
            
            content
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.white.opacity(0.3),
                Color.clear
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: phase)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 300
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var color: Color = ThemeColors.accentGold
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.5)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 4
    var size: CGFloat = 40
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var foregroundColor: Color = ThemeColors.accentGold
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Slide Transition

extension AnyTransition {
    static var slideFromRight: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var slideFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat
    var isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.6) : .clear, radius: radius)
            .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: radius * 2)
    }
}

extension View {
    func glow(color: Color = ThemeColors.accentGold, radius: CGFloat = 8, isActive: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

struct ShakeModifier: ViewModifier {
    var trigger: Bool
    @State private var shakeAmount: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: shakeAmount))
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.default) {
                        shakeAmount = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shakeAmount = 0
                    }
                }
            }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, ThemeColors.accentGold]
    var particleCount: Int = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .red,
                size: CGFloat.random(in: 4...10),
                position: CGPoint(x: size.width / 2, y: -20),
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: 200...400)
                ),
                opacity: 1.0
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var position: CGPoint
    var velocity: CGPoint
    var opacity: Double
}

#Preview {
    VStack(spacing: 40) {
        BreathingView {
            Circle()
                .fill(ThemeColors.accentGold)
                .frame(width: 48, height: 48)
        }
        
        TypingIndicator()
        
        ProgressRing(progress: 0.7)
        
        Button("Bounce") {}
            .buttonStyle(BounceButtonStyle())
            .buttonStyle(PrimaryButtonStyle())
    }
    .padding()
}
