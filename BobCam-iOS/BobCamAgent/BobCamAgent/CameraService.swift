import Foundation
import AVFoundation
import Combine
import UIKit

// MARK: - Camera Service Delegate Protocol
protocol CameraServiceDelegate: AnyObject {
    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer)
    func didEncounterCameraError(_ error: CameraServiceError)
}

// MARK: - Camera Service Errors
enum CameraServiceError: LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case sessionConfigurationFailed
    case captureSessionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "카메라 권한이 거부되었습니다. 설정에서 권한을 허용해주세요."
        case .deviceNotAvailable:
            return "카메라 장치를 사용할 수 없습니다."
        case .sessionConfigurationFailed:
            return "카메라 설정을 구성할 수 없습니다."
        case .captureSessionFailed(let error):
            return "카메라 캡처 오류: \(error.localizedDescription)"
        }
    }
}

// MARK: - Camera Service
class CameraService: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var captureDevice: AVCaptureDevice?
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Private Properties
    let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.bobcam.camera", qos: .userInitiated)

    weak var delegate: CameraServiceDelegate?

    // O3 제안: CVPixelBufferPool로 메모리 최적화
    private var pixelBufferPool: CVPixelBufferPool?

    // 프레임 스로틀링을 위한 카운터 (VisionService와 독립적)
    private var frameCounter: Int = 0
    private let frameSkipInterval: Int = 4 // 60fps -> 15fps (4프레임마다 1번 처리)

    // MARK: - Configuration
    struct Configuration {
        static let sessionPreset: AVCaptureSession.Preset = .hd1280x720 // O3 제안: 720p로 최적화
        static let targetFPS: Int32 = 30 // 입력은 30fps, 처리는 15fps
        static let pixelFormat: OSType = kCVPixelFormatType_32BGRA
    }

    // MARK: - Initialization
    override init() {
        super.init()
        checkPermissionStatus()
    }

    // MARK: - Public Methods
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.startCaptureSession()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.stopCaptureSession()
        }
    }

    func requestPermission() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)

        await MainActor.run {
            self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }

        return status
    }

    // MARK: - Private Methods
    private func checkPermissionStatus() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func startCaptureSession() {
        guard permissionStatus == .authorized else {
            DispatchQueue.main.async {
                self.delegate?.didEncounterCameraError(.permissionDenied)
            }
            return
        }

        guard !captureSession.isRunning else { return }

        configureCaptureSession()
        captureSession.startRunning()

        DispatchQueue.main.async {
            self.isSessionRunning = self.captureSession.isRunning
        }
    }

    private func stopCaptureSession() {
        guard captureSession.isRunning else { return }

        captureSession.stopRunning()

        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
    }

    private func configureCaptureSession() {
        captureSession.beginConfiguration()

        // 세션 프리셋 설정 (O3 제안: 720p)
        if captureSession.canSetSessionPreset(Configuration.sessionPreset) {
            captureSession.sessionPreset = Configuration.sessionPreset
        }

        // 전면 카메라 설정
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .front) else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.delegate?.didEncounterCameraError(.deviceNotAvailable)
            }
            return
        }

        // 카메라 설정 최적화 (O3 제안사항)
        do {
            try frontCamera.lockForConfiguration()

            // FPS 설정 - 30fps로 안정화
            frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Configuration.targetFPS)
            frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Configuration.targetFPS)

            // 자동 초점 및 노출 설정
            if frontCamera.isFocusModeSupported(.continuousAutoFocus) {
                frontCamera.focusMode = .continuousAutoFocus
            }

            if frontCamera.isExposureModeSupported(.continuousAutoExposure) {
                frontCamera.exposureMode = .continuousAutoExposure
            }

            frontCamera.unlockForConfiguration()
        } catch {
            frontCamera.unlockForConfiguration()
            print("카메라 설정 실패: \(error)")
        }

        // 카메라 입력 추가
        do {
            let cameraInput = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
                DispatchQueue.main.async {
                    self.captureDevice = frontCamera
                }
            }
        } catch {
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.delegate?.didEncounterCameraError(.captureSessionFailed(error))
            }
            return
        }

        // 비디오 데이터 출력 설정
        configureVideoDataOutput()

        captureSession.commitConfiguration()
    }

    private func configureVideoDataOutput() {
        // O3 제안: 픽셀 포맷 최적화
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Configuration.pixelFormat
        ]

        // 실시간 처리를 위한 설정
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // 델리게이트 설정
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)

            // 비디오 연결 설정
            if let connection = videoDataOutput.connection(with: .video) {
                // 전면 카메라 미러링 설정
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }

                // 세로 방향 설정
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
    }

    // O3 제안: CVPixelBufferPool 초기화
    private func createPixelBufferPool() {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Configuration.pixelFormat,
            kCVPixelBufferWidthKey as String: 720,
            kCVPixelBufferHeightKey as String: 1280,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        CVPixelBufferPoolCreate(kCFAllocatorDefault,
                               poolAttributes as CFDictionary,
                               pixelBufferAttributes as CFDictionary,
                               &pixelBufferPool)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {

        // 프레임 스킵핑으로 15fps 처리 구현
        frameCounter += 1
        guard frameCounter % frameSkipInterval == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // 델리게이트로 프레임 전달
        delegate?.didReceiveFrame(pixelBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput,
                      didDrop sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        // 드롭된 프레임 로깅 (필요시)
        print("Frame dropped")
    }
}
