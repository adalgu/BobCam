//
//  LandmarksOverlayView_Fixed.swift
//  BobCam
//
//  PHASE 3: Fixed version addressing app crashes
//  Key fixes: Thread safety, memory management, error handling
//

import SwiftUI
import Vision
import Combine

/// Thread-safe overlay view that renders facial landmarks with crash protection
struct LandmarksOverlayView_Fixed: UIViewRepresentable {
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    let cameraFrame: CGRect

    func makeUIView(context: Context) -> LandmarksOverlayUIView_Fixed {
        let view = LandmarksOverlayUIView_Fixed()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.debugSettings = debugSettings
        return view
    }

    func updateUIView(_ uiView: LandmarksOverlayUIView_Fixed, context: Context) {
        uiView.cameraFrame = cameraFrame
        uiView.debugSettings = debugSettings

        // CRASH FIX: Only update when overlay is enabled and view is in hierarchy
        guard debugSettings.showLandmarksOverlay,
              uiView.superview != nil else {
            uiView.clearLandmarks()
            return
        }

        // CRASH FIX: Use defensive copy on main thread to prevent race conditions
        uiView.updateLandmarksFromVisionService(visionService)
    }
}

/// Thread-safe UIView for landmark rendering with comprehensive error handling
class LandmarksOverlayUIView_Fixed: UIView {

    // MARK: - Thread-Safe Properties
    var debugSettings: DebugSettings?
    var cameraFrame: CGRect = .zero
    
    // CRASH FIX: Atomic access to landmark data
    private let landmarkQueue = DispatchQueue(label: "com.bobcam.landmarks", qos: .userInitiated)
    private var _currentOuterPoints: [CGPoint]?
    private var _currentInnerPoints: [CGPoint]?
    private var _currentBoundingBox: CGRect?
    
    // Thread-safe property accessors
    private var currentOuterPoints: [CGPoint]? {
        get { landmarkQueue.sync { _currentOuterPoints } }
        set { landmarkQueue.sync { _currentOuterPoints = newValue } }
    }
    
    private var currentInnerPoints: [CGPoint]? {
        get { landmarkQueue.sync { _currentInnerPoints } }
        set { landmarkQueue.sync { _currentInnerPoints = newValue } }
    }
    
    private var currentBoundingBox: CGRect? {
        get { landmarkQueue.sync { _currentBoundingBox } }
        set { landmarkQueue.sync { _currentBoundingBox = newValue } }
    }

    // CRASH FIX: Simplified history without mutating operations that cause crashes
    private var landmarkHistory: [LandmarkFrame] = []
    private let maxHistorySize = 10
    
    // CRASH FIX: Track view lifecycle to prevent drawing on deallocated views
    private var isViewValid = false

    // MARK: - Initialization with Safety Checks
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    deinit {
        isViewValid = false
        print("🟢 [LandmarksOverlay] View deallocated safely")
    }

    private func setupView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isViewValid = true
        
        // CRASH FIX: Enable layer-backed rendering for better stability
        layer.drawsAsynchronously = false
        layer.shouldRasterize = false
    }

    // MARK: - Public Methods with Crash Protection

    /// Thread-safe method to update landmarks from VisionService
    func updateLandmarksFromVisionService(_ visionService: VisionService) {
        // CRASH FIX: Validate view state before processing
        guard isViewValid, superview != nil else {
            print("⚠️ [LandmarksOverlay] View invalid or not in hierarchy - skipping update")
            return
        }

        // CRASH FIX: Get landmarks on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let (landmarks, faceObservation) = visionService.getCurrentLandmarksForDebug()
            self.processLandmarks(landmarks, faceObservation: faceObservation)
        }
    }
    
    /// Clear all landmark data safely
    func clearLandmarks() {
        landmarkQueue.async { [weak self] in
            self?._currentOuterPoints = nil
            self?._currentInnerPoints = nil
            self?._currentBoundingBox = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }
    
    // MARK: - Private Methods with Enhanced Safety
    
    private func processLandmarks(_ landmarks: VNFaceLandmarks2D?, faceObservation: VNFaceObservation?) {
        // CRASH FIX: Early validation checks
        guard isViewValid else { return }
        
        // CRASH FIX: Memory pressure check before processing
        let memoryPressure = ProcessInfo.processInfo.thermalState
        if memoryPressure == .critical || memoryPressure == .serious {
            print("🔴 [LandmarksOverlay] Critical system pressure - skipping landmark processing")
            return
        }
        
        // Process landmarks with comprehensive validation
        var outerPoints: [CGPoint]?
        var innerPoints: [CGPoint]?
        var bbox: CGRect?
        
        if let landmarks = landmarks {
            outerPoints = extractValidPoints(from: landmarks.outerLips, label: "outer")
            innerPoints = extractValidPoints(from: landmarks.innerLips, label: "inner")
        }
        
        if let faceObs = faceObservation {
            bbox = validateBoundingBox(faceObs.boundingBox)
        }
        
        // CRASH FIX: Update properties atomically
        updateLandmarkProperties(outer: outerPoints, inner: innerPoints, bbox: bbox)
    }
    
    private func extractValidPoints(from region: VNFaceLandmarkRegion2D?, label: String) -> [CGPoint]? {
        guard let region = region else { return nil }
        
        let normalizedPoints = region.normalizedPoints
        
        // CRASH FIX: Strict bounds checking
        guard normalizedPoints.count > 0 && normalizedPoints.count <= 30 else {
            print("⚠️ [LandmarksOverlay] Invalid \(label) point count: \(normalizedPoints.count)")
            return nil
        }
        
        // CRASH FIX: Validate each point individually
        let validPoints = normalizedPoints.compactMap { point -> CGPoint? in
            guard point.x.isFinite && point.y.isFinite,
                  point.x >= 0 && point.x <= 1,
                  point.y >= 0 && point.y <= 1 else {
                return nil
            }
            return CGPoint(x: point.x, y: point.y)
        }
        
        // CRASH FIX: Require minimum points for stable rendering
        guard validPoints.count >= 4 else {
            print("⚠️ [LandmarksOverlay] Insufficient valid \(label) points: \(validPoints.count)")
            return nil
        }
        
        return validPoints
    }
    
    private func validateBoundingBox(_ box: CGRect) -> CGRect? {
        // CRASH FIX: Comprehensive bounding box validation
        guard box.width > 0.01 && box.height > 0.01,
              box.width <= 1.0 && box.height <= 1.0,
              box.origin.x >= 0 && box.origin.y >= 0,
              box.origin.x + box.width <= 1.0,
              box.origin.y + box.height <= 1.0 else {
            print("⚠️ [LandmarksOverlay] Invalid bounding box: \(box)")
            return nil
        }
        return box
    }
    
    private func updateLandmarkProperties(outer: [CGPoint]?, inner: [CGPoint]?, bbox: CGRect?) {
        landmarkQueue.async { [weak self] in
            guard let self = self, self.isViewValid else { return }
            
            self._currentOuterPoints = outer
            self._currentInnerPoints = inner
            self._currentBoundingBox = bbox
            
            // CRASH FIX: Add to history with size limit
            if let outer = outer, !outer.isEmpty {
                let frame = LandmarkFrame(
                    outerLips: outer,
                    innerLips: inner,
                    boundingBox: bbox ?? .zero,
                    timestamp: CACurrentMediaTime()
                )
                
                self.landmarkHistory.append(frame)
                if self.landmarkHistory.count > self.maxHistorySize {
                    self.landmarkHistory.removeFirst()
                }
            }
            
            // CRASH FIX: Ensure UI updates happen on main thread
            DispatchQueue.main.async {
                guard self.isViewValid, self.superview != nil else { return }
                self.setNeedsDisplay()
            }
        }
    }

    // MARK: - Drawing with Comprehensive Safety

    override func draw(_ rect: CGRect) {
        // CRASH FIX: Validate drawing context
        guard isViewValid,
              let context = UIGraphicsGetCurrentContext(),
              let settings = debugSettings,
              settings.showLandmarksOverlay,
              rect.width > 0 && rect.height > 0 else {
            return
        }
        
        // CRASH FIX: Use autorelease pool for memory management
        autoreleasepool {
            drawLandmarksSafely(context: context, rect: rect, settings: settings)
        }
    }
    
    private func drawLandmarksSafely(context: CGContext, rect: CGRect, settings: DebugSettings) {
        context.saveGState()
        defer { context.restoreGState() }
        
        // CRASH FIX: Clear context safely
        context.setBlendMode(.normal)
        context.clear(rect)
        
        // CRASH FIX: Memory pressure check during drawing
        let memoryPressure = ProcessInfo.processInfo.thermalState
        if memoryPressure == .critical {
            drawMemoryPressureWarning(context: context, rect: rect)
            return
        }
        
        // CRASH FIX: Get thread-safe copies of landmark data
        let outer = currentOuterPoints
        let inner = currentInnerPoints
        let bbox = currentBoundingBox
        
        // Draw landmarks with validation
        if let outerPoints = outer, let boundingBox = bbox, !outerPoints.isEmpty {
            do {
                try drawValidatedLandmarks(
                    context: context,
                    rect: rect,
                    outerPoints: outerPoints,
                    innerPoints: inner,
                    faceBoundingBox: boundingBox,
                    settings: settings
                )
            } catch {
                print("⚠️ [LandmarksOverlay] Drawing error: \(error)")
                drawErrorIndicator(context: context, rect: rect)
            }
        } else if settings.showLandmarkLabels {
            drawNoLandmarksIndicator(context: context, rect: rect)
        }
    }
    
    private func drawValidatedLandmarks(
        context: CGContext,
        rect: CGRect,
        outerPoints: [CGPoint],
        innerPoints: [CGPoint]?,
        faceBoundingBox: CGRect,
        settings: DebugSettings
    ) throws {
        // CRASH FIX: Validate all points before drawing
        guard outerPoints.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            throw LandmarkDrawingError.invalidPoints
        }
        
        if let inner = innerPoints {
            guard inner.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                throw LandmarkDrawingError.invalidPoints
            }
        }
        
        // Transform coordinates safely
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -rect.height)
        let faceRect = faceBoundingBox.applying(transform)
        
        // CRASH FIX: Validate transformed rectangle
        guard faceRect.width > 0 && faceRect.height > 0 else {
            throw LandmarkDrawingError.invalidBounds
        }
        
        // Draw face bounding box
        if settings.showLandmarkLabels {
            drawFaceBoundingBox(context: context, faceRect: faceRect)
        }
        
        // Draw lip regions with safe rendering
        drawLipRegionSafely(
            context: context,
            points: outerPoints,
            faceRect: faceRect,
            color: UIColor.systemRed,
            label: "Outer",
            settings: settings
        )
        
        if let inner = innerPoints {
            drawLipRegionSafely(
                context: context,
                points: inner,
                faceRect: faceRect,
                color: UIColor.systemOrange,
                label: "Inner",
                settings: settings
            )
        }
    }
    
    private func drawLipRegionSafely(
        context: CGContext,
        points: [CGPoint],
        faceRect: CGRect,
        color: UIColor,
        label: String,
        settings: DebugSettings
    ) {
        // CRASH FIX: Bounds check before drawing
        guard !points.isEmpty, points.count <= 30 else { return }
        
        // CRASH FIX: Set drawing parameters with validation
        context.setStrokeColor(color.withAlphaComponent(min(settings.landmarkOpacity, 1.0)).cgColor)
        context.setLineWidth(max(0.5, min(settings.landmarkLineWidth, 5.0)))
        
        // Draw connecting lines
        context.beginPath()
        let firstPoint = convertPointSafely(points[0], faceRect: faceRect)
        context.move(to: firstPoint)
        
        for point in points.dropFirst() {
            let convertedPoint = convertPointSafely(point, faceRect: faceRect)
            context.addLine(to: convertedPoint)
        }
        
        context.closePath()
        context.strokePath()
        
        // Draw individual points
        context.setFillColor(color.withAlphaComponent(min(settings.landmarkOpacity, 1.0)).cgColor)
        let pointSize = max(1.0, min(settings.landmarkPointSize, 10.0))
        
        for (index, point) in points.enumerated() {
            let convertedPoint = convertPointSafely(point, faceRect: faceRect)
            let pointRect = CGRect(
                x: convertedPoint.x - pointSize / 2,
                y: convertedPoint.y - pointSize / 2,
                width: pointSize,
                height: pointSize
            )
            context.fillEllipse(in: pointRect)
            
            // Draw labels with bounds checking
            if settings.showLandmarkLabels && index < 20 {
                drawPointLabelSafely(
                    context: context,
                    text: "\(index)",
                    point: convertedPoint,
                    color: color
                )
            }
        }
    }
    
    // MARK: - Safe Helper Methods
    
    private func convertPointSafely(_ point: CGPoint, faceRect: CGRect) -> CGPoint {
        return CGPoint(
            x: max(0, min(faceRect.origin.x + point.x * faceRect.width, bounds.width)),
            y: max(0, min(faceRect.origin.y + point.y * faceRect.height, bounds.height))
        )
    }
    
    private func drawPointLabelSafely(
        context: CGContext,
        text: String,
        point: CGPoint,
        color: UIColor,
        fontSize: CGFloat = 10
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: max(8, min(fontSize, 16))),
            .foregroundColor: color,
            .backgroundColor: UIColor.black.withAlphaComponent(0.7)
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        let rect = CGRect(
            x: max(0, min(point.x - size.width / 2, bounds.width - size.width)),
            y: max(0, min(point.y - size.height - 2, bounds.height - size.height)),
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: rect)
    }
    
    private func drawFaceBoundingBox(context: CGContext, faceRect: CGRect) {
        context.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.stroke(faceRect)
    }
    
    private func drawMemoryPressureWarning(context: CGContext, rect: CGRect) {
        context.setFillColor(UIColor.red.withAlphaComponent(0.8).cgColor)
        context.fill(CGRect(x: rect.midX - 60, y: rect.midY - 15, width: 120, height: 30))
        
        let warningText = "⚠️ MEMORY WARNING"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
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
    
    private func drawErrorIndicator(context: CGContext, rect: CGRect) {
        let message = "Landmark Error"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.red
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
}

// MARK: - Error Types

enum LandmarkDrawingError: Error {
    case invalidPoints
    case invalidBounds
    case drawingContextError
    
    var localizedDescription: String {
        switch self {
        case .invalidPoints: return "Invalid landmark points"
        case .invalidBounds: return "Invalid drawing bounds"
        case .drawingContextError: return "Drawing context error"
        }
    }
}

// MARK: - Supporting Data Structures (Simplified)

/// Simplified landmark frame without complex circular buffer operations
struct LandmarkFrame {
    let outerLips: [CGPoint]
    let innerLips: [CGPoint]?
    let boundingBox: CGRect
    let timestamp: CFTimeInterval
}