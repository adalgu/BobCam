import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var videoSelectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService
    @ObservedObject var visionService: VisionService
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 비디오 설정 섹션
                    VideoSettingsSection(
                        selectionService: videoSelectionService,
                        videoService: videoService
                    )
                    
                    // 감지 설정 섹션
                    DetectionSettingsSection(visionService: visionService)
                    
                    // 앱 정보 섹션
                    AppInfoSection()
                }
                .padding()
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Video Settings Section
struct VideoSettingsSection: View {
    @ObservedObject var selectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "비디오 설정", icon: "video")
            
            // 비디오 선택 카드
            VideoPreviewCard(
                selectionService: selectionService,
                videoService: videoService
            )
            
            // 비디오 선택 버튼
            HStack {
                VideoSelectionButton(selectionService: selectionService)
                Spacer()
            }
            
            // 비디오 설정 안내
            InfoBox(
                title: "비디오 선택 안내",
                message: "갤러리에서 원하는 비디오를 선택하여 재생할 수 있습니다. 최대 100MB까지 지원되며, mp4, mov 형식을 권장합니다.",
                icon: "info.circle"
            )
        }
    }
}

// MARK: - Detection Settings Section  
struct DetectionSettingsSection: View {
    @ObservedObject var visionService: VisionService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "감지 설정", icon: "eye")
            
            // 감도 설정
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("감지 감도")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", visionService.sensitivity))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $visionService.sensitivity,
                    in: 0.1...2.0,
                    step: 0.1
                ) {
                    Text("감도")
                } minimumValueLabel: {
                    Text("낮음")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("높음")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 현재 상태 표시
            HStack {
                Circle()
                    .fill(visionService.isEating ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(visionService.isEating ? "먹는 중 감지됨" : "먹지 않음")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - App Info Section
struct AppInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "앱 정보", icon: "info.circle")
            
            VStack(spacing: 12) {
                InfoRow(title: "버전", value: "1.0.0")
                InfoRow(title: "개발자", value: "BobCam Team")
                InfoRow(title: "지원", value: "support@bobcam.app")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 개인정보 처리방침 안내
            InfoBox(
                title: "개인정보 보호",
                message: "모든 비디오 처리는 기기 내에서만 이루어지며, 외부 서버로 데이터가 전송되지 않습니다.",
                icon: "shield.checkered"
            )
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct InfoBox: View {
    let title: String
    let message: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView(
        videoSelectionService: VideoSelectionService(videoService: VideoService()),
        videoService: VideoService(),
        visionService: VisionService(),
        isPresented: .constant(true)
    )
}