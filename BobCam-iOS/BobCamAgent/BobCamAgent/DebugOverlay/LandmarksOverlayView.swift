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

        // Pull latest landmarks from VisionService for overlay
        if debugSettings.showLandmarksOverlay {
            let (landmarks, faceObs) = visionService.getCurrentLandmarksForDebug()
            uiView.updateLandmarks(landmarks, faceObservation: faceObs)
        } else {
            uiView.setNeedsDisplay()
        }
    }
}

/// Custom UIView for efficient landmark rendering using Core Graphics
class LandmarksOverlayUIView: UIView {

    // MARK: - Properties
    var debugSettings: DebugSettings?
    var cameraFrame: CGRect = .zero
    private var currentOuterPoints: [CGPoint]?
    private var currentInnerPoints: [CGPoint]?
    private var currentBoundingBox: CGRect?

    // MARK: - Landmark Data Storage
    private var landmarkHistory: CircularBuffer<LandmarkFrame> = CircularBuffer(capacity: 10)

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
        // Thread safety validation - this method can be called from main thread for UI updates
        // Only log if called from background thread unexpectedly during vision processing
        if !Thread.isMainThread {
            print("⚠️ [LandmarksOverlay] updateLandmarks called from background thread - this is unusual but safe")
        }
        
        // Snapshot normalized points into plain CGPoint arrays to avoid retaining Vision objects across threads
        var outerPoints: [CGPoint]? = nil
        var innerPoints: [CGPoint]? = nil
        var bbox: CGRect? = nil

        if let landmarks = landmarks {
            if let outer = landmarks.outerLips {
                // Bounds checking and validation
                let normalizedPoints = outer.normalizedPoints
                guard normalizedPoints.count > 0 && normalizedPoints.count <= 20 else {
                    print("⚠️ [LandmarksOverlay] Invalid outer lips point count: \(normalizedPoints.count)")
                    return
                }
                
                // Validate normalized coordinates are within [0,1] range
                let validPoints = normalizedPoints.compactMap { point -> CGPoint? in
                    guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
                        print("⚠️ [LandmarksOverlay] Invalid normalized point: \(point)")
                        return nil
                    }
                    return CGPoint(x: point.x, y: point.y)
                }
                
                guard validPoints.count > 3 else {
                    print("⚠️ [LandmarksOverlay] Insufficient valid outer lip points: \(validPoints.count)")
                    return
                }
                
                outerPoints = validPoints
            }
            
            if let inner = landmarks.innerLips {
                let normalizedPoints = inner.normalizedPoints
                if normalizedPoints.count > 0 && normalizedPoints.count <= 20 {
                    let validPoints = normalizedPoints.compactMap { point -> CGPoint? in
                        guard point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1 else {
                            return nil
                        }
                        return CGPoint(x: point.x, y: point.y)
                    }
                    innerPoints = validPoints.count > 3 ? validPoints : nil
                } else {
                    print("⚠️ [LandmarksOverlay] Invalid inner lips point count: \(normalizedPoints.count)")
                    innerPoints = nil
                }
            }
        }

        if let faceObs = faceObservation {
            let boundingBox = faceObs.boundingBox
            // Validate bounding box is reasonable
            if boundingBox.width > 0.01 && boundingBox.height > 0.01 &&
               boundingBox.width <= 1.0 && boundingBox.height <= 1.0 {
                bbox = boundingBox
            } else {
                print("⚠️ [LandmarksOverlay] Invalid face bounding box: \(boundingBox)")
                bbox = nil
            }
        }

        // Memory pressure check - Use memory pressure API correctly
        let memoryPressure = ProcessInfo.processInfo.thermalState
        if memoryPressure == .critical || memoryPressure == .serious {
            print("🔴 [LandmarksOverlay] Critical memory/thermal pressure - skipping landmark update")
            return
        }

        // Assign snapshots and write history on main thread (UI-safety)
        DispatchQueue.main.async { [weak self] in
            // Main thread validation
            assert(Thread.isMainThread, "UI updates must be on main thread")
            
            guard let self = self else { return }
            
            // Additional safety check before updating
            guard self.superview != nil else {
                print("⚠️ [LandmarksOverlay] View not in hierarchy - skipping update")
                return
            }
            
            self.currentOuterPoints = outerPoints
            self.currentInnerPoints = innerPoints
            self.currentBoundingBox = bbox

            // Store in history for trail visualization (use simple point snapshots)
            if let outer = outerPoints, outer.count > 0 {
                let frame = LandmarkFrame(
                    outerLips: outer,
                    innerLips: innerPoints,
                    boundingBox: bbox ?? .zero,
                    timestamp: CACurrentMediaTime()
                )
                
                // Check buffer capacity before writing
                if self.landmarkHistory.count >= self.landmarkHistory.capacity {
                    print("ℹ️ [LandmarksOverlay] Buffer full, oldest frame will be overwritten")
                }
                
                self.landmarkHistory.write(frame)
            }

            self.setNeedsDisplay()
        }
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        // Main thread validation
        assert(Thread.isMainThread, "draw(_:) must be called on main thread")
        
        guard let context = UIGraphicsGetCurrentContext(),
              let settings = debugSettings,
              settings.showLandmarksOverlay else { 
            return 
        }

        // Safety bounds check
        guard rect.width > 0 && rect.height > 0 else {
            print("⚠️ [LandmarksOverlay] Invalid draw rect: \(rect)")
            return
        }

        context.saveGState()
        defer { context.restoreGState() }

        // Clear the context
        context.clear(rect)

        // Memory pressure check during drawing
        let memoryPressure = ProcessInfo.processInfo.thermalState
        if memoryPressure == .critical || memoryPressure == .serious {
            // Draw emergency fallback
            drawMemoryPressureWarning(context: context, rect: rect)
            return
        }

        // Draw landmark history (trails)
        if settings.showBufferVisualization {
            drawLandmarkTrails(context: context, rect: rect)
        }

        // Draw current landmarks (use snapshot copies) with validation
        if let outer = currentOuterPoints, 
           let bbox = currentBoundingBox,
           outer.count > 0 {
            
            // Validate data integrity
            guard outer.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                print("⚠️ [LandmarksOverlay] Invalid outer points detected - skipping draw")
                return
            }
            
            if let inner = currentInnerPoints {
                guard inner.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                    print("⚠️ [LandmarksOverlay] Invalid inner points detected - using outer only")
                    drawCurrentLandmarks(
                        context: context,
                        rect: rect,
                        outerPoints: outer,
                        innerPoints: nil,
                        faceBoundingBox: bbox
                    )
                    return
                }
            }
            
            drawCurrentLandmarks(
                context: context,
                rect: rect,
                outerPoints: outer,
                innerPoints: currentInnerPoints,
                faceBoundingBox: bbox
            )
        } else {
            // Draw "no landmarks" indicator if debug labels enabled
            if settings.showLandmarkLabels {
                drawNoLandmarksIndicator(context: context, rect: rect)
            }
        }
    }
    
    private func drawMemoryPressureWarning(context: CGContext, rect: CGRect) {
        context.setFillColor(UIColor.red.withAlphaComponent(0.8).cgColor)
        context.fill(CGRect(x: rect.midX - 50, y: rect.midY - 10, width: 100, height: 20))
        
        let warningText = "⚠️ LOW MEMORY"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        let attributedString = NSAttributedString(string: warningText, attributes: attributes)
        let size = attributedString.size()
        let textRect = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        attributedString.draw(in: textRect)
    }
    
    private func drawNoLandmarksIndicator(context: CGContext, rect: CGRect) {
        let message = "No landmarks detected"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray.withAlphaComponent(0.7)
        ]
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let size = attributedString.size()
        let textRect = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        attributedString.draw(in: textRect)
    }

    private func drawCurrentLandmarks(
        context: CGContext,
        rect: CGRect,
        outerPoints: [CGPoint],
        innerPoints: [CGPoint]?,
        faceBoundingBox: CGRect
    ) {
        guard let settings = debugSettings else { return }

        // Transform coordinates from Vision to view space (bounding box is in normalized coordinates)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -rect.height)
        let faceRect = faceBoundingBox.applying(transform)

        // Draw face bounding box
        if settings.showLandmarkLabels {
            drawFaceBoundingBox(context: context, faceRect: faceRect)
        }

        // Draw outer lips (main focus for eating detection)
        drawLipRegion(
            context: context,
            points: outerPoints,
            faceRect: faceRect,
            color: UIColor.systemRed,
            label: "Outer Lips",
            settings: settings
        )

        // Draw inner lips if present
        if let inner = innerPoints {
            drawLipRegion(
                context: context,
                points: inner,
                faceRect: faceRect,
                color: UIColor.systemOrange,
                label: "Inner Lips",
                settings: settings
            )
        }

        // Draw algorithm-specific points using outer lip snapshot
        drawAlgorithmSpecificPoints(
            context: context,
            outerPoints: outerPoints,
            faceRect: faceRect,
            settings: settings
        )
    }

    private func drawLipRegion(
        context: CGContext,
        points: [CGPoint],
        faceRect: CGRect,
        color: UIColor,
        label: String,
        settings: DebugSettings
    ) {
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
        outerPoints: [CGPoint],
        faceRect: CGRect,
        settings: DebugSettings
    ) {
        let points = outerPoints

        // Draw the specific points used in lip distance calculation
        // Top center (indices 9, 10, 11)
        if let topCenter = getAveragePoint(from: points, indices: [9, 10, 11]) {
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
        if let bottomCenter = getAveragePoint(from: points, indices: [0, 1, 2]) {
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
        if let topCenter = getAveragePoint(from: points, indices: [9, 10, 11]),
           let bottomCenter = getAveragePoint(from: points, indices: [0, 1, 2]) {

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

            if alpha > 0.1, !frame.outerLips.isEmpty {
                drawTrailLipRegion(
                    context: context,
                    points: frame.outerLips,
                    rect: rect,
                    alpha: alpha,
                    isLatest: index == history.count - 1
                )
            }
        }
    }

    private func drawTrailLipRegion(
        context: CGContext,
        points: [CGPoint],
        rect: CGRect,
        alpha: CGFloat,
        isLatest: Bool
    ) {
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

    private func getAveragePoint(from points: [CGPoint], indices: [Int]) -> CGPoint? {
        // Enhanced bounds checking
        guard !points.isEmpty, !indices.isEmpty else { 
            print("⚠️ [LandmarksOverlay] Empty points or indices in getAveragePoint")
            return nil 
        }
        
        // Validate all indices are within bounds
        let validIndices = indices.filter { $0 >= 0 && $0 < points.count }
        guard validIndices.count == indices.count else {
            print("⚠️ [LandmarksOverlay] Invalid indices in getAveragePoint: \(indices), points count: \(points.count)")
            return nil
        }
        
        // Validate points are finite
        let validPoints = validIndices.compactMap { index -> CGPoint? in
            let point = points[index]
            guard point.x.isFinite && point.y.isFinite else {
                print("⚠️ [LandmarksOverlay] Non-finite point at index \(index): \(point)")
                return nil
            }
            return point
        }
        
        guard validPoints.count > 0 else {
            print("⚠️ [LandmarksOverlay] No valid points found in getAveragePoint")
            return nil
        }

        let sum = validPoints.reduce(CGPoint.zero) { result, point in
            return CGPoint(x: result.x + point.x, y: result.y + point.y)
        }

        let average = CGPoint(x: sum.x / CGFloat(validPoints.count), y: sum.y / CGFloat(validPoints.count))
        
        // Final validation of result
        guard average.x.isFinite && average.y.isFinite else {
            print("⚠️ [LandmarksOverlay] Non-finite average point: \(average)")
            return nil
        }
        
        return average
    }
}

// MARK: - Supporting Data Structures

/// Stores landmark data with timestamp for trail visualization
struct LandmarkFrame {
    let outerLips: [CGPoint]
    let innerLips: [CGPoint]?
    let boundingBox: CGRect
    let timestamp: CFTimeInterval
}
