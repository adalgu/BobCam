import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// MARK: - Video Selection Service
@MainActor
class VideoSelectionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isShowingVideoPicker = false
    @Published var selectedVideoURL: URL?
    @Published var hasSelectedVideo = false
    @Published var selectionState: SelectionState = .idle
    
    // MARK: - Types
    enum SelectionState {
        case idle
        case selecting
        case importing
        case failed(Error)
    }
    
    enum VideoSelectionError: LocalizedError {
        case importFailed
        case invalidVideoFormat
        case videoTooLarge
        case copyFailed
        case accessDenied
        
        var errorDescription: String? {
            switch self {
            case .importFailed:
                return "비디오를 가져올 수 없습니다"
            case .invalidVideoFormat:
                return "지원하지 않는 비디오 형식입니다"
            case .videoTooLarge:
                return "비디오 파일이 너무 큽니다 (최대 100MB)"
            case .copyFailed:
                return "비디오 파일을 저장할 수 없습니다"
            case .accessDenied:
                return "비디오에 접근할 수 없습니다"
            }
        }
    }
    
    // MARK: - Constants
    private struct Constants {
        static let maxVideoSizeBytes: Int64 = 100 * 1024 * 1024 // 100MB
        static let supportedVideoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        static let userDefaultsKey = "selectedVideoURL"
        static let documentsSubdirectory = "BobCamVideos"
    }
    
    // MARK: - Private Properties
    private let videoService: VideoService
    
    // MARK: - Initialization
    init(videoService: VideoService) {
        self.videoService = videoService
        loadPersistedVideoURL()
    }
    
    // MARK: - Public Methods
    
    /// 비디오 선택 시작
    func selectVideo() {
        selectionState = .selecting
        isShowingVideoPicker = true
    }
    
    /// PHPickerResult 처리
    func handleVideoSelection(_ results: [PHPickerResult]) {
        guard let result = results.first else {
            selectionState = .idle
            return
        }
        
        selectionState = .importing
        
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
            Task { @MainActor in
                await self?.processSelectedVideo(url: url, error: error)
            }
        }
    }
    
    /// 기본 비디오로 되돌리기
    func resetToDefaultVideo() {
        clearSelectedVideo()
        loadDefaultVideo()
    }
    
    /// 선택된 비디오 제거
    func clearSelectedVideo() {
        selectedVideoURL = nil
        hasSelectedVideo = false
        UserDefaults.standard.removeObject(forKey: Constants.userDefaultsKey)
        selectionState = .idle
        
        // 저장된 비디오 파일 삭제
        cleanupStoredVideos()
    }
    
    // MARK: - Private Methods
    
    private func processSelectedVideo(url: URL?, error: Error?) {
        if let error = error {
            selectionState = .failed(VideoSelectionError.accessDenied)
            print("Video selection error: \(error)")
            return
        }
        
        guard let sourceURL = url else {
            selectionState = .failed(VideoSelectionError.importFailed)
            return
        }
        
        Task {
            do {
                // 비디오 유효성 검사
                try await validateVideo(at: sourceURL)
                
                // 비디오를 앱 디렉토리에 복사
                let destinationURL = try await copyVideoToDocuments(from: sourceURL)
                
                // VideoService에 로드
                await loadVideoInService(url: destinationURL)
                
                // 상태 업데이트 및 저장
                await updateSelectionState(url: destinationURL)
                
            } catch {
                await MainActor.run {
                    self.selectionState = .failed(error)
                }
            }
        }
    }
    
    private func validateVideo(at url: URL) async throws {
        let asset = AVAsset(url: url)
        
        // 비디오 재생 가능성 확인
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoSelectionError.invalidVideoFormat
        }
        
        // 비디오 길이 확인
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw VideoSelectionError.invalidVideoFormat
        }
        
        // 파일 크기 확인
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard Int64(fileSize) <= Constants.maxVideoSizeBytes else {
            throw VideoSelectionError.videoTooLarge
        }
    }
    
    private func copyVideoToDocuments(from sourceURL: URL) async throws -> URL {
        let documentsPath = getDocumentsDirectory()
        let videoDirectory = documentsPath.appendingPathComponent(Constants.documentsSubdirectory)
        
        // 비디오 디렉토리 생성
        try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        
        // 파일명 생성 (타임스탬프 기반)
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = sourceURL.pathExtension
        let fileName = "selected_video_\(timestamp).\(fileExtension)"
        let destinationURL = videoDirectory.appendingPathComponent(fileName)
        
        // 기존 비디오 파일들 정리
        cleanupStoredVideos()
        
        // 새 비디오 파일 복사
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func loadVideoInService(url: URL) async {
        await MainActor.run {
            videoService.loadVideo(from: url)
        }
    }
    
    private func updateSelectionState(url: URL) async {
        await MainActor.run {
            self.selectedVideoURL = url
            self.hasSelectedVideo = true
            self.selectionState = .idle
            self.isShowingVideoPicker = false
            
            // UserDefaults에 저장
            UserDefaults.standard.set(url.absoluteString, forKey: Constants.userDefaultsKey)
        }
    }
    
    private func loadPersistedVideoURL() {
        guard let urlString = UserDefaults.standard.string(forKey: Constants.userDefaultsKey),
              let url = URL(string: urlString),
              FileManager.default.fileExists(atPath: url.path) else {
            loadDefaultVideo()
            return
        }
        
        selectedVideoURL = url
        hasSelectedVideo = true
        videoService.loadVideo(from: url)
    }
    
    private func loadDefaultVideo() {
        guard let bundlePath = Bundle.main.path(forResource: "sample_video", ofType: "mp4"),
              let videoURL = URL(string: "file://\(bundlePath)") else {
            selectionState = .failed(VideoSelectionError.importFailed)
            return
        }
        
        selectedVideoURL = videoURL
        hasSelectedVideo = false
        videoService.loadVideo(from: videoURL)
    }
    
    private func cleanupStoredVideos() {
        let documentsPath = getDocumentsDirectory()
        let videoDirectory = documentsPath.appendingPathComponent(Constants.documentsSubdirectory)
        
        do {
            let videoFiles = try FileManager.default.contentsOfDirectory(at: videoDirectory,
                                                                        includingPropertiesForKeys: nil)
            for file in videoFiles {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup stored videos: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - PHPickerViewController Configuration Helper
extension VideoSelectionService {
    
    /// PHPickerViewController 설정 생성
    func makePickerConfiguration() -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        return configuration
    }
}