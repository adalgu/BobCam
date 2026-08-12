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

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if selectionService.hasSelectedVideo {
                    showingConfirmationAlert = true
                } else {
                    selectionService.selectVideo()
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
                    selectionService.selectVideo()
                }
                Button("기본 비디오로 변경") {
                    selectionService.resetToDefaultVideo()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("새로운 비디오를 선택하거나 기본 비디오로 되돌릴 수 있습니다.")
            }

            // 상태 표시
            if case .importing = selectionService.selectionState {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("가져오는 중...")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else if case .failed(let error) = selectionService.selectionState {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $selectionService.isShowingVideoPicker) {
            VideoPickerView(
                configuration: selectionService.makePickerConfiguration(),
                onCompletion: selectionService.handleVideoSelection
            )
        }
    }

    private var videoButtonIcon: String {
        selectionService.hasSelectedVideo ? "video.fill" : "video.badge.plus"
    }

    private var videoButtonText: String {
        selectionService.hasSelectedVideo ? "비디오 변경" : "비디오 선택"
    }
}

// MARK: - Video Preview Card
struct VideoPreviewCard: View {
    @ObservedObject var selectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video")
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

            if let videoURL = selectionService.selectedVideoURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(videoFileName(from: videoURL))
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(selectionService.hasSelectedVideo ? "사용자 선택 비디오" : "기본 비디오")
                        .font(.caption)
                        .foregroundColor(.secondary)

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

    private func videoFileName(from url: URL) -> String {
        if selectionService.hasSelectedVideo {
            return url.lastPathComponent
        } else {
            return "sample_video.mp4"
        }
    }

    private var videoStatusColor: Color {
        switch videoService.playbackState {
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
        switch videoService.playbackState {
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
