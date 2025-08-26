import SwiftUI
import PhotosUI

// MARK: - Video Picker View (SwiftUI wrapper for PHPickerViewController)
struct VideoPickerView: UIViewControllerRepresentable {
    let configuration: PHPickerConfiguration
    let onCompletion: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onCompletion: ([PHPickerResult]) -> Void

        init(onCompletion: @escaping ([PHPickerResult]) -> Void) {
            self.onCompletion = onCompletion
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true) {
                self.onCompletion(results)
            }
        }
    }
}

// MARK: - Video Selection Button
struct VideoSelectionButton: View {
    @ObservedObject var selectionService: VideoSelectionService
    @State private var showingConfirmationAlert = false
    @State private var showingVideoSourceSheet = false

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if selectionService.hasSelectedVideo {
                    showingConfirmationAlert = true
                } else {
                    showingVideoSourceSheet = true
                }
            }) {
                HStack {
                    Image(systemName: videoButtonIcon)
                        .font(.system(size: 14, weight: .medium))

                    Text(videoButtonText)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .alert("비디오 변경", isPresented: $showingConfirmationAlert) {
                Button("새 비디오 선택") {
                    showingVideoSourceSheet = true
                }
                Button("기본 비디오로 변경") {
                    selectionService.resetToDefaultVideo()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("새로운 비디오를 선택하거나 기본 비디오로 되돌릴 수 있습니다.")
            }

            // 상태 표시
            statusView
        }
        .sheet(isPresented: $showingVideoSourceSheet) {
            VideoSourceSelectionView(selectionService: selectionService)
        }
        .sheet(isPresented: $selectionService.isShowingVideoPicker) {
            VideoPickerView(
                configuration: selectionService.makePickerConfiguration(),
                onCompletion: selectionService.handleVideoSelection
            )
        }
        .sheet(isPresented: $selectionService.isShowingYouTubeInput) {
            YouTubeURLInputView(selectionService: selectionService)
        }
    }

    private var videoButtonIcon: String {
        switch selectionService.selectedVideoType {
        case .local:
            return "video.fill"
        case .youtube:
            return "play.rectangle.fill"
        case .none:
            return "video.badge.plus"
        }
    }

    private var videoButtonText: String {
        if selectionService.hasSelectedVideo {
            switch selectionService.selectedVideoType {
            case .local:
                return "로컬 비디오"
            case .youtube:
                return "YouTube 비디오"
            case .none:
                return "비디오 변경"
            }
        } else {
            return "비디오 선택"
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch selectionService.selectionState {
        case .importing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("가져오는 중...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        case .validatingYouTube:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("YouTube 확인 중...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        case .failed(let error):
            Text(error.localizedDescription)
                .font(.caption2)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        default:
            EmptyView()
        }
    }
}

// MARK: - Video Source Selection View
struct VideoSourceSelectionView: View {
    @ObservedObject var selectionService: VideoSelectionService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(VideoSelectionService.VideoSourceOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectionService.handleVideoSourceSelection(option)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                
                                Text(optionDescription(for: option))
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("비디오 소스 선택")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func optionDescription(for option: VideoSelectionService.VideoSourceOption) -> String {
        switch option {
        case .photoLibrary:
            return "기기에 저장된 비디오 파일"
        case .youtube:
            return "YouTube URL로 온라인 비디오 재생"
        case .defaultVideo:
            return "앱 기본 제공 비디오"
        }
    }
}

// MARK: - YouTube URL Input View
struct YouTubeURLInputView: View {
    @ObservedObject var selectionService: VideoSelectionService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YouTube URL 입력")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("아이에게 적합한 YouTube 비디오 URL을 입력하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://www.youtube.com/watch?v=...", text: $selectionService.youTubeURLInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .padding(.horizontal)
                    
                    Text("지원되는 형식:\n• https://www.youtube.com/watch?v=...\n• https://youtu.be/...\n• https://m.youtube.com/watch?v=...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Network status warning
                if !selectionService.isNetworkAvailable {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        Text("네트워크 연결을 확인해주세요")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("YouTube 비디오")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("확인") {
                        selectionService.handleYouTubeURLInput()
                        if case .idle = selectionService.selectionState {
                            dismiss()
                        }
                    }
                    .disabled(selectionService.youTubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             !selectionService.isNetworkAvailable)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Video Preview Card
struct VideoPreviewCard: View {
    @ObservedObject var selectionService: VideoSelectionService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: videoIcon)
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("선택된 비디오")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if selectionService.hasSelectedVideo {
                    Button("제거") {
                        selectionService.clearSelectedVideo()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if let selectedVideoType = selectionService.selectedVideoType {
                VStack(alignment: .leading, spacing: 4) {
                    Text(videoDisplayName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(videoTypeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // YouTube specific info
                    if case .youtube(let youTubeVideo) = selectedVideoType {
                        if let channelTitle = youTubeVideo.channelTitle {
                            Text("채널: \(channelTitle)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if !selectionService.isNetworkAvailable {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .font(.caption2)
                                Text("네트워크 연결 필요")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }

                    // 비디오 상태 표시
                    HStack {
                        Circle()
                            .fill(videoStatusColor)
                            .frame(width: 8, height: 8)

                        Text(videoStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("비디오가 선택되지 않음")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties
    
    private var videoIcon: String {
        guard let videoType = selectionService.selectedVideoType else {
            return "video.slash"
        }
        
        switch videoType {
        case .local:
            return "video"
        case .youtube:
            return "play.rectangle"
        }
    }
    
    private var videoDisplayName: String {
        guard let videoType = selectionService.selectedVideoType else {
            return "없음"
        }
        
        switch videoType {
        case .local(let url):
            return selectionService.hasSelectedVideo ? url.lastPathComponent : "demo.mp4"
        case .youtube(let youTubeVideo):
            return youTubeVideo.title ?? "YouTube Video (\(youTubeVideo.videoId))"
        }
    }
    
    private var videoTypeDescription: String {
        guard let videoType = selectionService.selectedVideoType else {
            return "선택되지 않음"
        }
        
        switch videoType {
        case .local:
            return selectionService.hasSelectedVideo ? "사용자 선택 비디오" : "기본 비디오"
        case .youtube:
            return "YouTube 온라인 비디오"
        }
    }

    private var videoStatusColor: Color {
        switch selectionService.playbackState {
        case .ready, .playing, .paused:
            return .green
        case .loading:
            return .orange
        case .failed:
            return .red
        case .idle:
            return .gray
        }
    }

    private var videoStatusText: String {
        switch selectionService.playbackState {
        case .ready:
            return "준비됨"
        case .playing:
            return "재생 중"
        case .paused:
            return "일시정지"
        case .loading:
            return "로딩 중"
        case .failed:
            return "오류"
        case .idle:
            return "대기 중"
        }
    }
}
