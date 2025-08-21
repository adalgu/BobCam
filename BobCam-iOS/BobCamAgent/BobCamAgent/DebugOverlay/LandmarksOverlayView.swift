//
//  LandmarksOverlayView.swift
//  BobCam
//
//  Real-time lip landmark visualization overlay for debugging and algorithm tuning
//

import SwiftUI
import Vision
import Combine

/// Overlay view that renders facial landmarks in real-time on top of the camera feed
struct LandmarksOverlayView: UIViewRepresentable {
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    let cameraFrame: CGRect
    
    func makeUIView(context: Context) -> LandmarksOverlayUIView {
        let view = LandmarksOverlayUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.debugSettings = debugSettings
        return view
    }
    
    func updateUIView(_ uiView: LandmarksOverlayUIView, context: Context) {
        uiView.cameraFrame = cameraFrame
        uiView.debugSettings = debugSettings
        
        // Update landmarks when vision service processes new frame
        if debugSettings.showLandmarksOverlay {
            uiView.setNeedsDisplay()
        }
    }
}

/// Custom UIView for efficient landmark rendering using Core Graphics
class LandmarksOverlayUIView: UIView {
    
    // MARK: - Properties
    var debugSettings: DebugSettings?
    var cameraFrame: CGRect = .zero
    private var currentLandmarks: VNFaceLandmarks2D?
    private var faceObservation: VNFaceObservation?
    
    // MARK: - Landmark Data Storage
    private var landmarkHistory: CircularBuffer<LandmarkFrame> = CircularBuffer(capacity: 10)
    private var smoothedLandmarks: VNFaceLandmarks2D?
    
    // MARK: - Animation Properties
    private var animationTimer: Timer?
    private var trailAlpha: CGFloat = 1.0
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }
    
    // MARK: - Public Methods
    
    /// Update landmarks from vision processing
    func updateLandmarks(_ landmarks: VNFaceLandmarks2D?, faceObservation: VNFaceObservation?) {
        self.currentLandmarks = landmarks
        self.faceObservation = faceObservation
        
        // Store in history for trail visualization
        if let landmarks = landmarks {
            let frame = LandmarkFrame(
                landmarks: landmarks,
                timestamp: CACurrentMediaTime()
            )
            landmarkHistory.write(frame)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let settings = debugSettings,
              settings.showLandmarksOverlay else { return }
        
        context.saveGState()
        
        // Clear the context
        context.clear(rect)
        
        // Draw landmark history (trails)
        if settings.showBufferVisualization {
            drawLandmarkTrails(context: context, rect: rect)
        }
        
        // Draw current landmarks
        if let landmarks = currentLandmarks,
           let faceObservation = faceObservation {
            drawCurrentLandmarks(
                context: context,
                rect: rect,
                landmarks: landmarks,
                faceObservation: faceObservation
            )
        }
        
        context.restoreGState()
    }
    
    private func drawCurrentLandmarks(
        context: CGContext,
        rect: CGRect,
        landmarks: VNFaceLandmarks2D,
        faceObservation: VNFaceObservation
    ) {
        guard let settings = debugSettings else { return }
        
        // Transform coordinates from Vision to view space
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -rect.height)
        let faceRect = faceObservation.boundingBox.applying(transform)
        
        // Draw face bounding box
        if settings.showLandmarkLabels {
            drawFaceBoundingBox(context: context, faceRect: faceRect)
        }
        
        // Draw outer lips (main focus for eating detection)
        if let outerLips = landmarks.outerLips {
            drawLipRegion(
                context: context,
                region: outerLips,
                faceRect: faceRect,
                color: UIColor.systemRed,
                label: "Outer Lips",
                settings: settings
            )
        }
        
        // Draw inner lips
        if let innerLips = landmarks.innerLips {
            drawLipRegion(
                context: context,
                region: innerLips,
                faceRect: faceRect,
                color: UIColor.systemOrange,
                label: "Inner Lips",
                settings: settings
            )
        }
        
        // Draw additional facial features for reference
        drawAdditionalLandmarks(
            context: context,
            landmarks: landmarks,
            faceRect: faceRect,
            settings: settings
        )
        
        // Draw algorithm-specific points
        drawAlgorithmSpecificPoints(
            context: context,
            landmarks: landmarks,
            faceRect: faceRect,
            settings: settings
        )
    }
    
    private func drawLipRegion(
        context: CGContext,
        region: VNFaceLandmarkRegion2D,
        faceRect: CGRect,
        color: UIColor,
        label: String,
        settings: DebugSettings
    ) {
        let points = region.normalizedPoints
        
        // Draw connecting lines
        context.setStrokeColor(color.withAlphaComponent(settings.landmarkOpacity).cgColor)
        context.setLineWidth(settings.landmarkLineWidth)
        
        if !points.isEmpty {
            context.beginPath()
            let firstPoint = convertPoint(points[0], faceRect: faceRect)
            context.move(to: firstPoint)
            
            for point in points.dropFirst() {
                let convertedPoint = convertPoint(point, faceRect: faceRect)
                context.addLine(to: convertedPoint)
            }
            
            // Close the path for lip regions
            context.closePath()
            context.strokePath()
        }
        
        // Draw individual points
        context.setFillColor(color.withAlphaComponent(settings.landmarkOpacity).cgColor)
        for (index, point) in points.enumerated() {
            let convertedPoint = convertPoint(point, faceRect: faceRect)
            let pointRect = CGRect(
                x: convertedPoint.x - settings.landmarkPointSize / 2,
                y: convertedPoint.y - settings.landmarkPointSize / 2,
                width: settings.landmarkPointSize,
                height: settings.landmarkPointSize
            )
            context.fillEllipse(in: pointRect)
            
            // Draw point labels if enabled
            if settings.showLandmarkLabels {
                drawPointLabel(
                    context: context,
                    text: "\(index)",
                    point: convertedPoint,
                    color: color
                )
            }
        }
        
        // Draw region label
        if settings.showLandmarkLabels, !points.isEmpty {
            let centerPoint = calculateCenterPoint(points: points, faceRect: faceRect)
            drawPointLabel(
                context: context,
                text: label,
                point: centerPoint,
                color: color,
                fontSize: 14
            )
        }
    }
    
    private func drawAlgorithmSpecificPoints(
        context: CGContext,
        landmarks: VNFaceLandmarks2D,
        faceRect: CGRect,
        settings: DebugSettings
    ) {
        guard let outerLips = landmarks.outerLips else { return }
        
        let points = outerLips.normalizedPoints
        
        // Draw the specific points used in lip distance calculation
        // Top center (indices 9, 10, 11)
        if let topCenter = getAveragePoint(from: outerLips, indices: [9, 10, 11]) {
            let convertedPoint = convertPoint(topCenter, faceRect: faceRect)
            drawAlgorithmPoint(
                context: context,
                point: convertedPoint,
                color: UIColor.systemGreen,
                label: "Top Center",
                settings: settings
            )
        }
        
        // Bottom center (indices 0, 1, 2)
        if let bottomCenter = getAveragePoint(from: outerLips, indices: [0, 1, 2]) {
            let convertedPoint = convertPoint(bottomCenter, faceRect: faceRect)
            drawAlgorithmPoint(
                context: context,
                point: convertedPoint,
                color: UIColor.systemBlue,
                label: "Bottom Center",
                settings: settings
            )
        }
        
        // Draw distance line between key points
        if let topCenter = getAveragePoint(from: outerLips, indices: [9, 10, 11]),
           let bottomCenter = getAveragePoint(from: outerLips, indices: [0, 1, 2]) {
            
            let topPoint = convertPoint(topCenter, faceRect: faceRect)
            let bottomPoint = convertPoint(bottomCenter, faceRect: faceRect)
            
            // Draw measuring line
            context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(2.0)
            context.beginPath()
            context.move(to: topPoint)
            context.addLine(to: bottomPoint)
            context.strokePath()
            
            // Draw distance value
            let midPoint = CGPoint(
                x: (topPoint.x + bottomPoint.x) / 2,
                y: (topPoint.y + bottomPoint.y) / 2
            )
            
            let distance = sqrt(pow(topCenter.x - bottomCenter.x, 2) + pow(topCenter.y - bottomCenter.y, 2))
            drawPointLabel(
                context: context,
                text: String(format: "%.4f", distance),
                point: midPoint,
                color: UIColor.systemYellow,
                fontSize: 12
            )
        }
    }
    
    private func drawAlgorithmPoint(
        context: CGContext,
        point: CGPoint,
        color: UIColor,
        label: String,
        settings: DebugSettings
    ) {
        // Draw larger point for algorithm-specific landmarks
        let pointSize = settings.landmarkPointSize * 2
        context.setFillColor(color.withAlphaComponent(settings.landmarkOpacity).cgColor)
        let pointRect = CGRect(
            x: point.x - pointSize / 2,
            y: point.y - pointSize / 2,
            width: pointSize,
            height: pointSize
        )
        context.fillEllipse(in: pointRect)
        
        // Draw label
        if settings.showLandmarkLabels {
            drawPointLabel(
                context: context,
                text: label,
                point: CGPoint(x: point.x, y: point.y - pointSize - 5),
                color: color,
                fontSize: 10
            )
        }
    }
    
    private func drawAdditionalLandmarks(
        context: CGContext,
        landmarks: VNFaceLandmarks2D,
        faceRect: CGRect,
        settings: DebugSettings
    ) {
        // Draw other landmarks with reduced opacity for reference
        let referenceAlpha = settings.landmarkOpacity * 0.3
        
        // Nose
        if let nose = landmarks.nose {
            drawFeatureRegion(
                context: context,
                region: nose,
                faceRect: faceRect,
                color: UIColor.systemBlue.withAlphaComponent(referenceAlpha),
                settings: settings
            )
        }
        
        // Left eye
        if let leftEye = landmarks.leftEye {
            drawFeatureRegion(
                context: context,
                region: leftEye,
                faceRect: faceRect,
                color: UIColor.systemPurple.withAlphaComponent(referenceAlpha),
                settings: settings
            )
        }
        
        // Right eye
        if let rightEye = landmarks.rightEye {
            drawFeatureRegion(
                context: context,
                region: rightEye,
                faceRect: faceRect,
                color: UIColor.systemPurple.withAlphaComponent(referenceAlpha),
                settings: settings
            )
        }
    }
    
    private func drawFeatureRegion(
        context: CGContext,
        region: VNFaceLandmarkRegion2D,
        faceRect: CGRect,
        color: UIColor,
        settings: DebugSettings
    ) {
        let points = region.normalizedPoints
        
        // Draw points only (no lines for reference features)
        context.setFillColor(color.cgColor)
        for point in points {
            let convertedPoint = convertPoint(point, faceRect: faceRect)
            let pointRect = CGRect(
                x: convertedPoint.x - settings.landmarkPointSize / 4,
                y: convertedPoint.y - settings.landmarkPointSize / 4,
                width: settings.landmarkPointSize / 2,
                height: settings.landmarkPointSize / 2
            )
            context.fillEllipse(in: pointRect)
        }
    }
    
    private func drawLandmarkTrails(context: CGContext, rect: CGRect) {
        let history = landmarkHistory.allItems()
        let currentTime = CACurrentMediaTime()
        
        for (index, frame) in history.enumerated() {
            let age = currentTime - frame.timestamp
            let alpha = max(0.0, 1.0 - (age / 2.0)) // Fade over 2 seconds
            
            if alpha > 0.1, let outerLips = frame.landmarks.outerLips {
                drawTrailLipRegion(
                    context: context,
                    region: outerLips,
                    rect: rect,
                    alpha: alpha,
                    isLatest: index == history.count - 1
                )
            }
        }
    }
    
    private func drawTrailLipRegion(
        context: CGContext,
        region: VNFaceLandmarkRegion2D,
        rect: CGRect,
        alpha: CGFloat,
        isLatest: Bool
    ) {
        let points = region.normalizedPoints
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -rect.height)
        
        // Draw simplified trail points
        context.setFillColor(UIColor.systemRed.withAlphaComponent(alpha * 0.3).cgColor)
        
        for point in points {
            let transformedPoint = point.applying(transform)
            let viewPoint = CGPoint(
                x: transformedPoint.x * rect.width,
                y: transformedPoint.y * rect.height
            )
            
            let pointSize: CGFloat = isLatest ? 2.0 : 1.0
            let pointRect = CGRect(
                x: viewPoint.x - pointSize / 2,
                y: viewPoint.y - pointSize / 2,
                width: pointSize,
                height: pointSize
            )
            context.fillEllipse(in: pointRect)
        }
    }
    
    private func drawFaceBoundingBox(context: CGContext, faceRect: CGRect) {
        context.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.stroke(faceRect)
    }
    
    private func drawPointLabel(
        context: CGContext,
        text: String,
        point: CGPoint,
        color: UIColor,
        fontSize: CGFloat = 10
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: color,
            .backgroundColor: UIColor.black.withAlphaComponent(0.7)
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height - 2,
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: rect)
    }
    
    // MARK: - Helper Methods
    
    private func convertPoint(_ point: CGPoint, faceRect: CGRect) -> CGPoint {
        return CGPoint(
            x: faceRect.origin.x + point.x * faceRect.width,
            y: faceRect.origin.y + point.y * faceRect.height
        )
    }
    
    private func calculateCenterPoint(points: [CGPoint], faceRect: CGRect) -> CGPoint {
        let sum = points.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        let center = CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
        return convertPoint(center, faceRect: faceRect)
    }
    
    private func getAveragePoint(from region: VNFaceLandmarkRegion2D, indices: [Int]) -> CGPoint? {
        let points = region.normalizedPoints
        guard !indices.contains(where: { $0 >= points.count }) else { return nil }
        
        let sum = indices.reduce(CGPoint.zero) { result, index in
            let point = points[index]
            return CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        
        return CGPoint(x: sum.x / CGFloat(indices.count), y: sum.y / CGFloat(indices.count))
    }
}

// MARK: - Supporting Data Structures

/// Stores landmark data with timestamp for trail visualization
struct LandmarkFrame {
    let landmarks: VNFaceLandmarks2D
    let timestamp: CFTimeInterval
}

