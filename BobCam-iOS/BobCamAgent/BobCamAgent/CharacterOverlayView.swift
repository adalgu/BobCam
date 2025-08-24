import SwiftUI

// MARK: - Character State System
enum CharacterState: String, CaseIterable {
    case waiting = "waiting"
    case encouraging = "encouraging"
    case celebrating = "celebrating"
    case sleeping = "sleeping"
    
    var description: String {
        switch self {
        case .waiting:
            return "Ready to eat!"
        case .encouraging:
            return "Keep going!"
        case .celebrating:
            return "Great job!"
        case .sleeping:
            return "Taking a break..."
        }
    }
    
    var characterEmoji: String {
        switch self {
        case .waiting:
            return "🐻"
        case .encouraging:
            return "🌟"
        case .celebrating:
            return "🎉"
        case .sleeping:
            return "😴"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .waiting:
            return .blue.opacity(0.1)
        case .encouraging:
            return .orange.opacity(0.1)
        case .celebrating:
            return .green.opacity(0.1)
        case .sleeping:
            return .purple.opacity(0.1)
        }
    }
}

// MARK: - Character Animation Types
enum CharacterAnimation: String, CaseIterable {
    case idle = "idle"
    case bounce = "bounce"
    case grow = "grow"
    case sparkle = "sparkle"
    case wave = "wave"
}

// MARK: - Animation Phase System (O3 최적화)
enum AnimationPhase: String, CaseIterable {
    case idle = "idle"
    case celebrating = "celebrating"
    case celebratingFinishing = "celebratingFinishing" 
    case encouraging = "encouraging"
}

// MARK: - Character Overlay View
struct CharacterOverlayView: View {
    @State private var characterState: CharacterState = .waiting
    @State private var currentAnimation: CharacterAnimation = .idle
    @State private var animationPhase: AnimationPhase = .idle  // O3 최적화: 상태 기반 애니메이션
    @State private var animationOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0.0
    @State private var sparkleOpacity: Double = 0.0
    @State private var isWaving: Bool = false
    
    // Binding to eating detection state
    let isEating: Bool
    let isVideoPlaying: Bool
    
    init(isEating: Bool, isVideoPlaying: Bool) {
        self.isEating = isEating
        self.isVideoPlaying = isVideoPlaying
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Character background area
                characterBackgroundView(geometry)
                
                // Main character view
                mainCharacterView(geometry)
                
                // Animation effects overlay
                animationEffectsView(geometry)
            }
            .onAppear {
                startIdleAnimation()
            }
            .onChange(of: isEating) { eating in
                updateCharacterState(eating: eating)
            }
            .onChange(of: isVideoPlaying) { playing in
                if !playing && characterState == .celebrating {
                    characterState = .waiting
                }
            }
        }
    }
    
    // MARK: - Character Background
    private func characterBackgroundView(_ geometry: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(characterState.backgroundColor)
            .frame(width: 200, height: 150)
            .position(
                x: geometry.size.width * 0.5,
                y: geometry.size.height * 0.3
            )
            .opacity(characterState == .sleeping ? 0.3 : 0.8)
            .animation(.easeInOut(duration: 0.5), value: characterState)
    }
    
    // MARK: - Main Character
    private func mainCharacterView(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            // Character emoji with animations
            Text(characterState.characterEmoji)
                .font(.system(size: 60))
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .offset(animationOffset)
                .animation(.easeInOut(duration: 0.4), value: characterState)  // O3 최적화: 단일 애니메이션
            
            // Character status message
            Text(characterState.description)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .opacity(characterState == .sleeping ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: characterState)
        }
        .position(
            x: geometry.size.width * 0.5,
            y: geometry.size.height * 0.3
        )
    }
    
    // MARK: - Animation Effects
    private func animationEffectsView(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // Sparkle effect for celebrating
            if characterState == .celebrating {
                ForEach(0..<6, id: \.self) { index in
                    sparkleView(index: index, geometry: geometry)
                }
            }
            
            // Wave effect for encouraging
            if characterState == .encouraging && isWaving {
                waveEffectView(geometry)
            }
        }
    }
    
    // MARK: - Sparkle Effect
    private func sparkleView(index: Int, geometry: GeometryProxy) -> some View {
        let angle = Double(index) * 60.0 // Distribute sparkles in circle
        let distance: CGFloat = 80
        let centerX = geometry.size.width * 0.5
        let centerY = geometry.size.height * 0.3
        
        return Text("✨")
            .font(.system(size: 20))
            .opacity(sparkleOpacity)
            .position(
                x: centerX + cos(angle * .pi / 180) * distance,
                y: centerY + sin(angle * .pi / 180) * distance
            )
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: sparkleOpacity)
    }
    
    // MARK: - Wave Effect
    private func waveEffectView(_ geometry: GeometryProxy) -> some View {
        Text("👋")
            .font(.system(size: 30))
            .position(
                x: geometry.size.width * 0.7,
                y: geometry.size.height * 0.25
            )
            .rotationEffect(.degrees(isWaving ? 20 : -20))
            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isWaving)
    }
    
    // MARK: - Animation Control Methods (O3 최적화: 상태 기반)
    private func updateCharacterState(eating: Bool) {
        withAnimation(.easeInOut(duration: 0.5)) {
            if eating {
                animationPhase = isVideoPlaying ? .celebrating : .encouraging
                characterState = isVideoPlaying ? .celebrating : .encouraging
                triggerAppropriateAnimation()
            } else {
                animationPhase = (animationPhase == .celebrating) ? .celebratingFinishing : .idle
                characterState = .waiting
                if animationPhase == .celebratingFinishing {
                    // Use Timer instead of DispatchQueue for better control
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        if !isEating {
                            animationPhase = .idle
                            startIdleAnimation()
                        }
                    }
                } else {
                    startIdleAnimation()
                }
            }
        }
    }
    
    private func triggerAppropriateAnimation() {
        switch animationPhase {
        case .celebrating:
            triggerCelebratingAnimation()
        case .encouraging:
            triggerEncouragingAnimation()
        default:
            startIdleAnimation()
        }
    }
    
    private func startIdleAnimation() {
        currentAnimation = .idle
        
        // Gentle breathing animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            scale = 1.05
        }
        
        // Reset other animation states
        animationOffset = .zero
        rotation = 0.0
        sparkleOpacity = 0.0
        isWaving = false
    }
    
    private func triggerEncouragingAnimation() {
        currentAnimation = .wave
        
        // Wave animation
        isWaving = true
        
        // Bounce effect
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(3, autoreverses: true)) {
            animationOffset = CGSize(width: 0, height: -10)
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isWaving = false
            animationOffset = .zero
        }
    }
    
    private func triggerCelebratingAnimation() {
        currentAnimation = .sparkle
        
        // Grow animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            scale = 1.2
        }
        
        // Sparkle effect
        withAnimation(.easeInOut(duration: 0.5)) {
            sparkleOpacity = 1.0
        }
        
        // Rotation celebration
        withAnimation(.easeInOut(duration: 1.0)) {
            rotation = 360.0
        }
        
        // Reset after celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                scale = 1.0
                rotation = 0.0
                sparkleOpacity = 0.0
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CharacterOverlayView(isEating: true, isVideoPlaying: true)
    }
}