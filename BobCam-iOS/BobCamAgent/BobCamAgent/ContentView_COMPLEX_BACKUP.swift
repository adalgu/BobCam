import SwiftUI
import Vision
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var multiModalService = MultiModalEatingDetectionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @State private var showingSettings = false
    @AppStorage("showFeedbackBanner") private var showFeedbackBanner: Bool = true
    @AppStorage("useMultiModalDetection") private var useMultiModalDetection: Bool = false
    @State private var feedbackState: FeedbackBannerView.FeedbackState = .neutral
    @State private var currentDetectionStatus: String = "분석 중..."
    @State private var showDebugInfo: Bool = true  // 디버그 정보 표시
    @State private var lipMovementValue: Double = 0.0
    @State private var detectionConfidence: Double = 0.0
    @State private var frameProcessingRate: Int = 0
    @State private var consecutiveEatingFrames: Int = 0

    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }

    // Current detection service (선택된 감지 서비스)
    private var currentDetectionService: any FaceTrackingServiceProtocol {
          useMultiModalDetection ? multiModalService : visionService
        }
    
    // Debounced publisher to stabilize feedback banner updates
    private var debouncedEatingPublisher: AnyPublisher<Bool, Never> {
          if useMultiModalDetection {
              return multiModalService.$isEating
                  .removeDuplicates()
                  .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
                  .eraseToAnyPublisher()
          } else {
              return visionService.$isEating
                  .removeDuplicates()
                  .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
                  .eraseToAnyPublisher()
          }
        }

    // Localized message derived from current feedback state
    private var localizedMessage: String {
        switch feedbackState {
        case .eating:
            return NSLocalizedString("eating_positive",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "좋아요 잘 먹고 있어요.",
                                     comment: "Positive feedback when eating detected")
        case .notEating:
            return NSLocalizedString("eating_prompt",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "밥 더 먹어요.",
                                     comment: "Prompt when not eating detected")
        case .neutral:
            return NSLocalizedString("analyzing",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "분석 중…",
                                     comment: "Neutral analyzing state")
        }
    }

    var body: some View {
        // 완전히 클린한 빨간색 화면 테스트 - 모든 오버레이 제거
        Rectangle()
            .fill(Color.red)
            .ignoresSafeArea()
            .overlay(
                VStack {
                    Text("ULTRA CLEAN RED TEST - 빌드 1930")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.yellow)  // 노란색으로 변경하여 더 확실히
                        .padding()
                    
                    Text("이 노란 글씨가 보이면 완전히 새 빌드!")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text(Date().formatted())
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                    
                    Spacer()
                }
            )
            .ignoresSafeArea()
            // 모든 오버레이 제거 - 완전히 클린한 테스트
            /*
            모든 오버레이 UI 제거됨 - 빌드 테스트용
            */
        }
        .ignoresSafeArea()
        .onAppear {
            cameraService.startSession()
            setupDetectionService()
        }
        .onDisappear {
            stopAllDetectionServices()
            cameraService.stopSession()
        }
        .onChange(of: useMultiModalDetection) { _ in
            // A/B 테스트: 감지 모드 변경 시 서비스 전환
            stopAllDetectionServices()
            setupDetectionService()
        }
        .onReceive(visionService.$isEating) { isEating in
            // 기존 립 감지 결과에 따른 비디오 제어
            if !useMultiModalDetection {
                if isEating {
                    videoService.playVideo()
                } else {
                    videoService.pauseVideo()
                }
            }
        }
        // .onReceive(multiModalService.$isEating) { isEating in
        //     // 멀티모달 감지 결과에 따른 비디오 제어
        //     if useMultiModalDetection {
        //         if isEating {
        //             videoService.playVideo()
        //         } else {
        //             videoService.pauseVideo()
        //         }
        //     }
        // }
        .onReceive(debouncedEatingPublisher) { isEating in
            feedbackState = isEating ? .eating : .notEating
        }
        .onReceive(visionService.$isFaceDetected) { isFaceDetected in
            cameraService.updateFaceDetectionStatus(isFaceDetected)
            updateDetectionStatus()
        }
        .onReceive(visionService.$isEating) { _ in
            updateDetectionStatus()
        }
        .onReceive(visionService.$serviceState) { _ in
            updateDetectionStatus()
        }
        // Update debug metrics in real-time
        .onReceive(visionService.$currentLipDistance) { newValue in
            lipMovementValue = Double(newValue)
        }
        .onReceive(visionService.$detectionConfidence) { newValue in
            detectionConfidence = Double(newValue)
        }
        .onReceive(visionService.$consecutiveEatingFrames) { newValue in
            consecutiveEatingFrames = newValue
        }
        .onReceive(visionService.$fps) { newValue in
            frameProcessingRate = Int(newValue)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                isPresented: $showingSettings
            )
        }
    }
    
    // MARK: - Helper Methods
    private func setupDetectionService() {
        if useMultiModalDetection {
            print("[ContentView] 멀티모달 감지 모드 시작")
            cameraService.delegate = multiModalService
            multiModalService.startTracking()
        } else {
            print("[ContentView] 기본 립 트래킹 모드 시작")
            cameraService.delegate = visionService
            visionService.startTracking()
        }
    }
    
    private func stopAllDetectionServices() {
        print("[ContentView] 모든 감지 서비스 중지")
        visionService.stopTracking()
        multiModalService.stopTracking()
        cameraService.delegate = nil
    }
    
    private func getStatusMessage() -> String {
        let serviceState = visionService.serviceState
        let isFaceDetected = visionService.isFaceDetected
        let isEating = useMultiModalDetection ? multiModalService.isEating : visionService.isEating
        
        switch serviceState {
        case .failed, .cameraError:
            return "감지 오류가 발생했습니다"
        case .idle, .paused:
            return "얼굴을 분석하고 있어요..."
        case .running:
            if !isFaceDetected {
                return "얼굴을 카메라 앞에 위치해주세요"
            } else if isEating {
                return "식사 중! 잘하고 있어요 🍽️"
            } else {
                return "밥을 더 먹어보세요 😊"
            }
        }
    }
    
    private func updateDetectionStatus() {
        let visionServiceState = visionService.serviceState
        let isFaceDetected = visionService.isFaceDetected
        let isEating = useMultiModalDetection ? multiModalService.isEating : visionService.isEating
        
        // 서비스 상태 우선 체크
        switch visionServiceState {
        case .failed, .cameraError:
            currentDetectionStatus = "감지 오류가 발생했습니다"
            return
        case .idle, .paused:
            currentDetectionStatus = "얼굴을 분석하고 있어요..."
            return
        case .running:
            break // 계속 진행
        }
        
        // 얼굴 감지 상태 체크
        if !isFaceDetected {
            currentDetectionStatus = "얼굴을 카메라 앞에 위치해주세요"
            return
        }
        
        // 식사 감지 상태 체크
        if isEating {
            currentDetectionStatus = "식사 중! 잘하고 있어요 🍽️"
        } else {
            currentDetectionStatus = "밥을 더 먹어보세요 😊"
        }
    }
    
    private func getStatusIcon() -> String {
        if currentDetectionStatus.contains("식사 중") {
            return "checkmark.circle.fill"
        } else if currentDetectionStatus.contains("밥을 더 먹어") {
            return "exclamationmark.circle.fill"
        } else if currentDetectionStatus.contains("분석") {
            return "magnifyingglass.circle.fill"
        } else if currentDetectionStatus.contains("얼굴을") {
            return "person.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private func getStatusBackgroundColor() -> Color {
        if currentDetectionStatus.contains("식사 중") {
            return .green
        } else if currentDetectionStatus.contains("밥을 더 먹어") {
            return .orange
        } else if currentDetectionStatus.contains("분석") {
            return .blue
        } else if currentDetectionStatus.contains("얼굴을") {
            return .gray
        } else {
            return .red
        }
    }
}

#Preview {
    ContentView()
}
