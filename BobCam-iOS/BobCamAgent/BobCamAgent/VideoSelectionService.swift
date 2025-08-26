import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import Combine
import UniformTypeIdentifiers

// MARK: - Video Selection Service
@MainActor
class VideoSelectionService: ObservableObject {

    // MARK: - Published Properties
    @Published var isShowingVideoPicker = false
    @Published var isShowingYouTubeInput = false
    @Published var selectedVideoType: VideoType?
    @Published var hasSelectedVideo = false
    @Published var selectionState: SelectionState = .idle
    @Published var youTubeURLInput: String = ""
    
    // Exposed properties from VideoService
    @Published var isNetworkAvailable: Bool = true
    @Published var playbackState: PlaybackState = .idle

    // MARK: - Types
    enum SelectionState {
        case idle
        case selecting
        case importing
        case validatingYouTube
        case failed(Error)
    }

    enum VideoSelectionError: LocalizedError {
        case importFailed
        case invalidVideoFormat
        case videoTooLarge
        case copyFailed
        case accessDenied
        case invalidYouTubeURL
        case youTubeContentRestricted
        case networkUnavailable

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
            case .invalidYouTubeURL:
                return "유효하지 않은 YouTube URL입니다"
            case .youTubeContentRestricted:
                return "어린이에게 적합하지 않은 콘텐츠입니다"
            case .networkUnavailable:
                return "YouTube 비디오는 인터넷 연결이 필요합니다"
            }
        }
    }

    // MARK: - Selection Options
    enum VideoSourceOption: CaseIterable {
        case photoLibrary
        case youtube
        case defaultVideo
        
        var title: String {
            switch self {
            case .photoLibrary:
                return "사진 라이브러리"
            case .youtube:
                return "YouTube URL"
            case .defaultVideo:
                return "기본 비디오"
            }
        }
        
        var icon: String {
            switch self {
            case .photoLibrary:
                return "photo.on.rectangle"
            case .youtube:
                return "play.rectangle"
            case .defaultVideo:
                return "video"
            }
        }
    }

    // MARK: - Constants
    private struct Constants {
        static let maxVideoSizeBytes: Int64 = 100 * 1024 * 1024 // 100MB
        static let supportedVideoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        static let userDefaultsKey = "selectedVideoType"
        static let documentsSubdirectory = "BobCamVideos"
        static let youTubeURLKey = "youTubeURL"
    }

    // MARK: - Private Properties
    private let videoService: VideoService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(videoService: VideoService) {
        print("[VideoSelectionService] 🎬 Initializing VideoSelectionService")
        self.videoService = videoService
        
        // Bind VideoService properties
        self.isNetworkAvailable = videoService.isNetworkAvailable
        self.playbackState = videoService.playbackState
        
        // Set up subscriptions
        videoService.$isNetworkAvailable
            .assign(to: &$isNetworkAvailable)
        
        videoService.$playbackState
            .assign(to: &$playbackState)
        
        print("[VideoSelectionService] 🔗 Property bindings established")
        
        // Load persisted video type or default
        loadPersistedVideoType()
        
        print("[VideoSelectionService] ✅ VideoSelectionService initialization completed")
    }

    // MARK: - Public Methods

    /// Show video source selection options
    func showVideoSourceOptions() {
        selectionState = .selecting
        isShowingVideoPicker = true
    }

    /// 비디오 선택 시작 (기존 메서드 - backward compatibility)
    func selectVideo() {
        showVideoSourceOptions()
    }

    /// Handle video source selection
    func handleVideoSourceSelection(_ source: VideoSourceOption) {
        switch source {
        case .photoLibrary:
            isShowingVideoPicker = true
        case .youtube:
            isShowingYouTubeInput = true
            youTubeURLInput = ""
        case .defaultVideo:
            resetToDefaultVideo()
        }
    }

    /// Handle YouTube URL input
    func handleYouTubeURLInput() {
        guard !youTubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            selectionState = .failed(VideoSelectionError.invalidYouTubeURL)
            return
        }
        
        let urlString = youTubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check network availability
        guard videoService.isNetworkAvailable else {
            selectionState = .failed(VideoSelectionError.networkUnavailable)
            return
        }
        
        selectionState = .validatingYouTube
        
        Task {
            do {
                let youTubeVideo = try await validateAndCreateYouTubeVideo(from: urlString)
                
                await MainActor.run {
                    let videoType = VideoType.youtube(youTubeVideo)
                    self.videoService.loadVideo(videoType)
                    self.selectedVideoType = videoType
                    self.hasSelectedVideo = true
                    self.selectionState = .idle
                    self.isShowingYouTubeInput = false
                    self.persistVideoType(videoType)
                }
            } catch {
                await MainActor.run {
                    self.selectionState = .failed(error)
                }
            }
        }
    }

    /// PHPickerResult 처리
    func handleVideoSelection(_ results: [PHPickerResult]) {
        guard let result = results.first else {
            selectionState = .idle
            return
        }

        selectionState = .importing

        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] tempURL, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.selectionState = .failed(VideoSelectionError.accessDenied)
                }
                print("Video selection error: \(error)")
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.selectionState = .failed(VideoSelectionError.importFailed)
                }
                return
            }

            do {
                // Copy to app sandbox synchronously BEFORE this completion handler returns
                let destinationURL = try VideoSelectionService.copyVideoToDocumentsSync(from: tempURL)

                DispatchQueue.main.async {
                    // Load into player and persist path
                    let videoType = VideoType.local(destinationURL)
                    self.videoService.loadVideo(videoType)
                    self.selectedVideoType = videoType
                    self.hasSelectedVideo = true
                    self.selectionState = .idle
                    self.isShowingVideoPicker = false
                    self.persistVideoType(videoType)
                }
            } catch {
                DispatchQueue.main.async {
                    self.selectionState = .failed(error)
                }
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
        selectedVideoType = nil
        hasSelectedVideo = false
        UserDefaults.standard.removeObject(forKey: Constants.userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Constants.youTubeURLKey)
        selectionState = .idle

        // 저장된 비디오 파일 삭제
        cleanupStoredVideos()
    }

    // MARK: - Private Methods - YouTube Validation

    func validateAndCreateYouTubeVideo(from urlString: String) async throws -> YouTubeVideo {
        // Basic URL validation
        guard YouTubeURLUtils.isValidYouTubeURL(urlString) else {
            throw VideoSelectionError.invalidYouTubeURL
        }
        
        // URL safety validation
        guard ChildSafetyFilter.validateURL(urlString) else {
            throw VideoSelectionError.youTubeContentRestricted
        }
        
        // Create YouTube video object
        guard let youTubeVideo = YouTubeURLUtils.createYouTubeVideo(from: urlString) else {
            throw VideoSelectionError.invalidYouTubeURL
        }
        
        // Child safety check
        guard ChildSafetyFilter.isChildSafe(youTubeVideo) else {
            throw VideoSelectionError.youTubeContentRestricted
        }
        
        // In a production app, you might want to make an API call to YouTube
        // to get additional metadata and verify the video exists
        
        return youTubeVideo
    }

    // MARK: - Private Methods - Local Video Processing

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
                await loadVideoInService(videoType: .local(destinationURL))

                // 상태 업데이트 및 저장
                await updateSelectionState(videoType: .local(destinationURL))

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

    private nonisolated static func copyVideoToDocumentsSync(from sourceURL: URL) throws -> URL {
        // Compute documents and target folder without touching @MainActor state
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoDirectory = documentsPath.appendingPathComponent(Constants.documentsSubdirectory)

        // Ensure directory exists
        try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)

        // Clear previous stored videos (best-effort)
        if let files = try? FileManager.default.contentsOfDirectory(at: videoDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }

        // Build destination filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let destinationURL = videoDirectory.appendingPathComponent("selected_video_\(timestamp).\(ext)")

        // Copy synchronously
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }

    private func loadVideoInService(videoType: VideoType) async {
        await MainActor.run {
            videoService.loadVideo(videoType)
        }
    }

    private func updateSelectionState(videoType: VideoType) async {
        await MainActor.run {
            self.selectedVideoType = videoType
            self.hasSelectedVideo = true
            self.selectionState = .idle
            self.isShowingVideoPicker = false

            self.persistVideoType(videoType)
        }
    }

    // MARK: - Persistence Methods

    private func persistVideoType(_ videoType: VideoType) {
        switch videoType {
        case .local(let url):
            UserDefaults.standard.set("local", forKey: Constants.userDefaultsKey)
            UserDefaults.standard.set(url.path, forKey: "localVideoPath")
            UserDefaults.standard.removeObject(forKey: Constants.youTubeURLKey)
        case .youtube(let youTubeVideo):
            UserDefaults.standard.set("youtube", forKey: Constants.userDefaultsKey)
            UserDefaults.standard.set(youTubeVideo.videoId, forKey: Constants.youTubeURLKey)
            UserDefaults.standard.removeObject(forKey: "localVideoPath")
        }
    }

    private func loadPersistedVideoType() {
        guard let typeString = UserDefaults.standard.string(forKey: Constants.userDefaultsKey) else {
            loadDefaultVideo()
            return
        }

        switch typeString {
        case "local":
            loadPersistedLocalVideo()
        case "youtube":
            loadPersistedYouTubeVideo()
        default:
            loadDefaultVideo()
        }
    }

    private func loadPersistedLocalVideo() {
        guard let path = UserDefaults.standard.string(forKey: "localVideoPath") else {
            print("[VideoSelectionService] 📏 No persisted local video path found")
            loadDefaultVideo()
            return
        }
        
        print("[VideoSelectionService] 📏 Loading persisted local video from: \(path)")
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[VideoSelectionService] ❌ Persisted video file no longer exists at: \(path)")
            // Clean up the invalid reference
            UserDefaults.standard.removeObject(forKey: "localVideoPath")
            loadDefaultVideo()
            return
        }
        
        print("[VideoSelectionService] ✅ Persisted local video file verified")
        let videoType = VideoType.local(url)
        selectedVideoType = videoType
        hasSelectedVideo = true
        videoService.loadVideo(videoType)
    }

    private func loadPersistedYouTubeVideo() {
        guard let videoId = UserDefaults.standard.string(forKey: Constants.youTubeURLKey) else {
            print("[VideoSelectionService] 📏 No persisted YouTube video ID found")
            loadDefaultVideo()
            return
        }
        
        guard videoService.isNetworkAvailable else {
            print("[VideoSelectionService] 🌐 Network unavailable for YouTube video, loading default")
            loadDefaultVideo()
            return
        }
        
        print("[VideoSelectionService] 🔴 Loading persisted YouTube video: \(videoId)")
        let youTubeVideo = YouTubeVideo(videoId: videoId, isChildSafe: true)
        let videoType = VideoType.youtube(youTubeVideo)
        
        selectedVideoType = videoType
        hasSelectedVideo = true
        videoService.loadVideo(videoType)
    }

    private func loadDefaultVideo() {
        print("[VideoSelectionService] 🎬 Loading default video from bundle...")
        
        // Try multiple methods to find the demo video
        var videoURL: URL?
        
        // Method 1: Bundle.main.path
        if let bundlePath = Bundle.main.path(forResource: "demo", ofType: "mp4") {
            print("[VideoSelectionService] ✅ Found demo.mp4 via Bundle.main.path: \(bundlePath)")
            videoURL = URL(fileURLWithPath: bundlePath)
        }
        // Method 2: Bundle.main.url
        else if let bundleURL = Bundle.main.url(forResource: "demo", withExtension: "mp4") {
            print("[VideoSelectionService] ✅ Found demo.mp4 via Bundle.main.url: \(bundleURL)")
            videoURL = bundleURL
        }
        // Method 3: Direct bundle resource search
        else {
            // List all mp4 files in bundle for debugging
            let bundleContents = Bundle.main.paths(forResourcesOfType: "mp4", inDirectory: nil)
            print("[VideoSelectionService] 📻 Bundle MP4 files found: \(bundleContents)")
            
            // Check if demo.mp4 exists in bundle root
            if let demoPath = bundleContents.first(where: { $0.contains("demo") }) {
                print("[VideoSelectionService] ✅ Found demo.mp4 in bundle contents: \(demoPath)")
                videoURL = URL(fileURLWithPath: demoPath)
            }
        }
        
        // Load the video if found
        if let videoURL = videoURL {
            // Verify file accessibility
            if FileManager.default.fileExists(atPath: videoURL.path) {
                print("[VideoSelectionService] ✅ Demo video file verified at: \(videoURL.path)")
                let videoType = VideoType.local(videoURL)
                
                selectedVideoType = videoType
                hasSelectedVideo = false  // Default video doesn't count as user selection
                videoService.loadVideo(videoType)
                print("[VideoSelectionService] 🎬 Default video loading initiated")
            } else {
                print("[VideoSelectionService] ❌ Demo video file not accessible at: \(videoURL.path)")
                handleNoDefaultVideo()
            }
        } else {
            print("[VideoSelectionService] ❌ No demo video found in bundle")
            handleNoDefaultVideo()
        }
    }
    
    private func handleNoDefaultVideo() {
        print("[VideoSelectionService] ⚠️ No default demo video available - user must select a video")
        selectedVideoType = nil
        hasSelectedVideo = false
        selectionState = .idle
        
        // Optionally show a message to user that they need to select a video
        // This could trigger a UI state that prompts video selection
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

// MARK: - Computed Properties for UI
extension VideoSelectionService {
    var selectedVideoURL: URL? {
        switch selectedVideoType {
        case .local(let url):
            return url
        case .youtube:
            return nil
        case .none:
            return nil
        }
    }
    
    var selectedYouTubeVideo: YouTubeVideo? {
        switch selectedVideoType {
        case .youtube(let video):
            return video
        case .local:
            return nil
        case .none:
            return nil
        }
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