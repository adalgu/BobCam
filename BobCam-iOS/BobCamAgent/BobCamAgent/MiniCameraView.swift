import SwiftUI
import AVFoundation

// MARK: - Mini Camera View
struct MiniCameraView: View {
    @ObservedObject var cameraService: CameraService
    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = CGPoint(x: 0.85, y: 0.15) // Relative position (0-1)
    
    // Camera preview dimensions
    private let miniSize: CGSize = CGSize(width: 100, height: 150)
    private let expandedSize: CGSize = CGSize(width: 200, height: 300)
    
    var body: some View {
        GeometryReader { geometry in
            cameraPreviewView(geometry)
                .position(
                    x: position.x * geometry.size.width,
                    y: position.y * geometry.size.height
                )
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            // Update position and snap to edges
                            let translationX = value.translation.width
                            let translationY = value.translation.height
                            let newX = (position.x * geometry.size.width + translationX) / geometry.size.width
                            let newY = (position.y * geometry.size.height + translationY) / geometry.size.height
                            
                            position = snapToEdges(
                                CGPoint(x: newX, y: newY),
                                screenSize: geometry.size
                            )
                            
                            dragOffset = .zero
                        }
                )
                .onTapGesture {
                    toggleExpanded()
                }
        }
    }
    
    // MARK: - Camera Preview Content
    private func cameraPreviewView(_ geometry: GeometryProxy) -> some View {
        let currentSize = isExpanded ? expandedSize : miniSize
        
        return ZStack {
            // Camera preview layer
            if cameraService.isSessionRunning {
                CameraPreviewLayerView(previewLayer: cameraService.previewLayer)
                    .frame(width: currentSize.width, height: currentSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Placeholder when camera is not available
                cameraPlaceholder(size: currentSize)
            }
            
            // Overlay controls and indicators
            overlayContent(size: currentSize)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: position)
    }
    
    // MARK: - Camera Placeholder
    private func cameraPlaceholder(size: CGSize) -> some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
                
                if isExpanded {
                    Text("Camera\nUnavailable")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Overlay Content
    private func overlayContent(size: CGSize) -> some View {
        VStack {
            HStack {
                // Eating status indicator
                eatingStatusIndicator()
                
                Spacer()
                
                // Expand/collapse button
                expandButton()
            }
            .padding(8)
            
            Spacer()
            
            if isExpanded {
                // Additional controls for expanded view
                expandedControls()
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    // MARK: - Eating Status Indicator
    private func eatingStatusIndicator() -> some View {
        Circle()
            .fill(cameraService.isDetectingFace ? .green : .red)
            .frame(width: 8, height: 8)
            .opacity(0.8)
            .animation(.easeInOut(duration: 0.3), value: cameraService.isDetectingFace)
    }
    
    // MARK: - Expand Button
    private func expandButton() -> some View {
        Button(action: toggleExpanded) {
            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(4)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Expanded Controls
    private func expandedControls() -> some View {
        VStack(spacing: 8) {
            // Camera status
            HStack {
                Image(systemName: "camera")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(cameraService.isSessionRunning ? "Active" : "Inactive")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            
            // Face detection status
            HStack {
                Image(systemName: "face.dashed")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(cameraService.isDetectingFace ? "Detected" : "No Face")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(cameraService.isDetectingFace ? .green : .white.opacity(0.7))
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Helper Methods
    private func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }
    
    private func snapToEdges(_ point: CGPoint, screenSize: CGSize) -> CGPoint {
        let margin: CGFloat = 0.05 // 5% margin from edges
        let maxX = 1.0 - margin
        let maxY = 1.0 - margin
        
        var newX = max(margin, min(maxX, point.x))
        let newY = max(margin, min(maxY, point.y))
        
        // Snap to closest edge horizontally
        if newX < 0.5 {
            newX = margin // Left edge
        } else {
            newX = maxX // Right edge
        }
        
        return CGPoint(x: newX, y: newY)
    }
}

// MARK: - Camera Preview Layer View
struct CameraPreviewLayerView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        MiniCameraView(cameraService: CameraService())
    }
}