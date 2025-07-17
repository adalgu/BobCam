import Foundation
import Vision

// MARK: - 개선된 Configuration 시스템
struct LipDetectionConfiguration {
    let historySize: Int
    let minMovementThreshold: Float
    let eatingPatternThreshold: Float
    let varianceThreshold: Float
    
    static let `default` = LipDetectionConfiguration(
        historySize: 10,
        minMovementThreshold: 0.05,
        eatingPatternThreshold: 0.15,
        varianceThreshold: 0.001
    )
    
    // 원격 설정이나 A/B 테스트를 위한 확장 가능성
    static func create(from remoteConfig: [String: Any]) -> LipDetectionConfiguration {
        return LipDetectionConfiguration(
            historySize: remoteConfig["historySize"] as? Int ?? 10,
            minMovementThreshold: remoteConfig["minMovementThreshold"] as? Float ?? 0.05,
            eatingPatternThreshold: remoteConfig["eatingPatternThreshold"] as? Float ?? 0.15,
            varianceThreshold: remoteConfig["varianceThreshold"] as? Float ?? 0.001
        )
    }
}

// MARK: - 에러 상태 정의
enum VisionServiceState {
    case idle
    case running
    case paused
    case failed(Error)
}

enum VisionServiceError: LocalizedError {
    case visionRequestFailed(Error)
    case landmarksNotAvailable
    case configurationInvalid
    
    var errorDescription: String? {
        switch self {
        case .visionRequestFailed(let error):
            return "얼굴 인식 처리 실패: \(error.localizedDescription)"
        case .landmarksNotAvailable:
            return "얼굴 특징점을 감지할 수 없습니다"
        case .configurationInvalid:
            return "립 트래킹 설정이 올바르지 않습니다"
        }
    }
}

// MARK: - 개선된 립 움직임 감지기
class LipMovementDetector {
    
    // MARK: - Properties
    private let configuration: LipDetectionConfiguration
    private var lipDistanceHistory: [Float] = []
    private var sensitivity: Float = 0.5
    
    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    func detectEatingMotion(from landmarks: VNFaceLandmarks2D) -> Bool {
        guard let lipDistance = calculateSafeLipDistance(landmarks) else {
            return false
        }
        
        updateHistory(with: lipDistance)
        return analyzeEatingPattern()
    }
    
    func updateSensitivity(_ newSensitivity: Float) {
        sensitivity = max(0.1, min(1.0, newSensitivity)) // 범위 제한
    }
    
    func reset() {
        lipDistanceHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 안전한 립 거리 계산 - 하드코딩된 인덱스 의존성 제거
    private func calculateSafeLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        // 우선 outerLips 사용 (더 안전)
        guard let outerLips = landmarks.outerLips else {
            return nil
        }
        
        let points = outerLips.normalizedPoints
        guard points.count >= 20 else {
            return nil
        }
        
        // 상하 입술 포인트를 더 안전하게 계산
        // outerLips에서 상단/하단 포인트 찾기
        let sortedByY = points.sorted { $0.y < $1.y }
        let topPoints = Array(sortedByY.prefix(3))  // 상위 3개 포인트
        let bottomPoints = Array(sortedByY.suffix(3))  // 하위 3개 포인트
        
        let avgTop = topPoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        let avgBottom = bottomPoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        
        let topCenter = CGPoint(x: avgTop.x / 3, y: avgTop.y / 3)
        let bottomCenter = CGPoint(x: avgBottom.x / 3, y: avgBottom.y / 3)
        
        let distance = sqrt(pow(topCenter.x - bottomCenter.x, 2) + 
                           pow(topCenter.y - bottomCenter.y, 2))
        return Float(distance)
    }
    
    private func updateHistory(with distance: Float) {
        lipDistanceHistory.append(distance)
        
        // 설정 가능한 히스토리 크기 사용
        if lipDistanceHistory.count > configuration.historySize {
            lipDistanceHistory.removeFirst()
        }
    }
    
    private func analyzeEatingPattern() -> Bool {
        guard lipDistanceHistory.count >= configuration.historySize else {
            return false
        }
        
        let halfSize = configuration.historySize / 2
        let recentAverage = Array(lipDistanceHistory.suffix(halfSize)).reduce(0, +) / Float(halfSize)
        let olderAverage = Array(lipDistanceHistory.prefix(halfSize)).reduce(0, +) / Float(halfSize)
        let changeRate = abs(recentAverage - olderAverage)
        
        // 민감도를 반영한 임계값 조정
        let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity
        
        let hasEatingPattern = changeRate > adjustedThreshold && 
                               detectRhythmicMovement()
        
        return hasEatingPattern
    }
    
    private func detectRhythmicMovement() -> Bool {
        guard lipDistanceHistory.count >= 6 else { return false }
        
        let recent = Array(lipDistanceHistory.suffix(6))
        let variance = calculateVariance(recent)
        
        // 설정 가능한 분산 임계값 사용
        return variance > configuration.varianceThreshold
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Float(values.count)
    }
}
