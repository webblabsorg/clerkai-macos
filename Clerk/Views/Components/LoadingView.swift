import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var appState: AppState
    
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(.circular)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var message: String = "Loading..."
    var progress: Double?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(.circular)
                }
                
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(Rectangle())
            .offset(x: isAnimating ? 200 : -200)
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct ToolCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView()
                .frame(width: 32, height: 32)
                .cornerRadius(8)
            
            SkeletonView()
                .frame(height: 14)
                .cornerRadius(4)
            
            SkeletonView()
                .frame(width: 80, height: 10)
                .cornerRadius(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingView()
        
        ToolCardSkeleton()
            .frame(width: 150, height: 100)
    }
    .environmentObject(AppState.shared)
    .padding()
}
