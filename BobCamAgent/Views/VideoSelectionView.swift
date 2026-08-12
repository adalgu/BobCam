import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct VideoSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var youtubeURL = ""
    @State private var showingPicker = false

    let onVideoSelected: (VideoSource) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("소스", selection: $selectedTab) {
                    Text("YouTube").tag(0)
                    Text("사진첩").tag(1)
                    Text("저장된 영상").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                switch selectedTab {
                case 0:
                    youtubeInputView
                case 1:
                    photoLibraryView
                case 2:
                    localVideosView
                default:
                    EmptyView()
                }

                Spacer()
            }
            .navigationTitle("영상 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                VideoPicker { url in
                    if let url = url {
                        onVideoSelected(.photoLibrary(url: url))
                        dismiss()
                    }
                }
            }
        }
    }

    private var youtubeInputView: some View {
        VStack(spacing: 20) {
            Text("YouTube URL을 입력하세요")
                .font(.headline)
                .padding(.top, 40)

            TextField("https://youtube.com/watch?v=...", text: $youtubeURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.URL)
                .padding(.horizontal)

            Button(action: loadYouTube) {
                Text("재생하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(youtubeURL.isEmpty ? Color.gray : Color.red)
                    .cornerRadius(12)
            }
            .disabled(youtubeURL.isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    private var photoLibraryView: some View {
        VStack(spacing: 20) {
            Button(action: { showingPicker = true }) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("사진첩에서 영상 선택")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .padding()
            }

            Spacer()
        }
        .padding(.top, 20)
    }

    private var localVideosView: some View {
        let localVideos = getLocalVideos()

        return Group {
            if localVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("저장된 영상이 없습니다")
                        .foregroundColor(.gray)
                }
                .padding(.top, 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(localVideos, id: \.id) { video in
                            LocalVideoRow(video: video) {
                                onVideoSelected(video)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func loadYouTube() {
        guard let url = URL(string: youtubeURL) else { return }
        onVideoSelected(.youtube(url: url))
        dismiss()
    }

    private func getLocalVideos() -> [VideoSource] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosURL = documentsURL.appendingPathComponent("Videos")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: videosURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { ["mp4", "mov", "m4v"].contains($0.pathExtension.lowercased()) }
            .map { .local(url: $0) }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    let onVideoPicked: (URL?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoPicked: onVideoPicked)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onVideoPicked: (URL?) -> Void

        init(onVideoPicked: @escaping (URL?) -> Void) {
            self.onVideoPicked = onVideoPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else {
                onVideoPicked(nil)
                return
            }

            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let url = url, error == nil else {
                        DispatchQueue.main.async {
                            self.onVideoPicked(nil)
                        }
                        return
                    }

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension)

                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        DispatchQueue.main.async {
                            self.onVideoPicked(tempURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.onVideoPicked(nil)
                        }
                    }
                }
            } else {
                onVideoPicked(nil)
            }
        }
    }
}

struct LocalVideoRow: View {
    let video: VideoSource
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                Text(video.id)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
