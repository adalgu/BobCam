import SwiftUI
import AVFoundation

// MARK: - Permission Handler
class PermissionManager: ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var hasCompletedOnboarding = false

    init() {
        checkInitialPermissions()
    }

    func checkInitialPermissions() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        hasCompletedOnboarding = cameraPermissionStatus == .authorized
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)

        await MainActor.run {
            self.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            self.hasCompletedOnboarding = granted
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @StateObject private var permissionManager = PermissionManager()
    @State private var currentStep = 0

    private let onboardingSteps = [
        OnboardingStep(
            icon: "video.fill",
            title: "아이 식사 도우미",
            description: "BobCam은 아이의 입 움직임을 감지하여\n자동으로 재미있는 영상을 재생합니다",
            buttonText: "시작하기"
        ),
        OnboardingStep(
            icon: "camera.fill",
            title: "카메라 권한 필요",
            description: "아이의 얼굴을 인식하기 위해\n카메라 접근 권한이 필요합니다\n\n모든 처리는 기기 내에서만 이루어지며\n외부로 전송되지 않습니다",
            buttonText: "권한 허용"
        ),
        OnboardingStep(
            icon: "checkmark.circle.fill",
            title: "준비 완료!",
            description: "이제 BobCam을 사용할 준비가 되었습니다\n아이를 카메라 앞에 앉혀주세요",
            buttonText: "시작하기"
        )
    ]

    var body: some View {
        if permissionManager.hasCompletedOnboarding {
            // 메인 앱으로 이동
            ContentView()
                .environmentObject(permissionManager)
        } else {
            onboardingContent
        }
    }

    private var onboardingContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 상단 로고/아이콘 영역
                VStack(spacing: 20) {
                    Image(systemName: onboardingSteps[currentStep].icon)
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.blue)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)

                    VStack(spacing: 16) {
                        Text(onboardingSteps[currentStep].title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(onboardingSteps[currentStep].description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)

                // 하단 버튼 및 네비게이션 영역
                VStack(spacing: 24) {
                    // 페이지 인디케이터
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingSteps.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? .blue : .gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }

                    // 메인 액션 버튼
                    Button(action: handleMainAction) {
                        Text(onboardingSteps[currentStep].buttonText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue)
                            )
                    }
                    .disabled(currentStep == 1 && permissionManager.cameraPermissionStatus == .denied)

                    // 권한 거부 시 설정 안내
                    if currentStep == 1 && permissionManager.cameraPermissionStatus == .denied {
                        VStack(spacing: 12) {
                            Text("카메라 권한이 거부되었습니다")
                                .font(.callout)
                                .foregroundColor(.red)

                            Button("설정에서 권한 허용") {
                                openAppSettings()
                            }
                            .font(.callout)
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 32))
            }
        }
        .background(Color(.systemBackground))
        .onReceive(permissionManager.$cameraPermissionStatus) { status in
            if status == .authorized && currentStep == 1 {
                // 권한 승인 시 다음 단계로
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentStep = 2
                }
            }
        }
    }

    private func handleMainAction() {
        switch currentStep {
        case 0:
            // 첫 번째 단계: 다음으로
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep = 1
            }

        case 1:
            // 두 번째 단계: 권한 요청
            if permissionManager.cameraPermissionStatus == .notDetermined {
                Task {
                    await permissionManager.requestCameraPermission()
                }
            } else if permissionManager.cameraPermissionStatus == .denied {
                openAppSettings()
            }

        case 2:
            // 세 번째 단계: 완료
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                permissionManager.hasCompletedOnboarding = true
            }

        default:
            break
        }
    }

    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Onboarding Step Model
struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .previewDisplayName("Onboarding")
    }
}
