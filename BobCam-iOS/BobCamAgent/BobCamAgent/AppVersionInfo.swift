import SwiftUI

struct AppVersionInfo: View {
    private let appVersion: String
    private let buildNumber: String
    private let gitCommitHash: String?
    
    init() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Git 커밋 해시 가져오기 (빌드 시 추가됨)
        self.gitCommitHash = Bundle.main.infoDictionary?["GitCommitHash"] as? String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                Text("앱 정보")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("버전:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(appVersion)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                HStack {
                    Text("빌드:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(buildNumber)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if let commitHash = gitCommitHash {
                    HStack {
                        Text("커밋:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(String(commitHash.prefix(8)))
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                
                HStack {
                    Text("빌드 시간:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(buildTimestamp)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .padding(.leading, 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var buildTimestamp: String {
        // 빌드 시간을 컴파일 타임에 삽입
        #if DEBUG
        return "DEBUG - " + getCurrentTimestamp()
        #else
        return Bundle.main.infoDictionary?["BuildTimestamp"] as? String ?? "Unknown"
        #endif
    }
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }
}

// MARK: - Compact Version for Status Display
struct CompactVersionInfo: View {
    private let buildNumber: String
    private let gitCommitHash: String?
    
    init() {
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        self.gitCommitHash = Bundle.main.infoDictionary?["GitCommitHash"] as? String
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("v\(buildNumber)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            
            if let commitHash = gitCommitHash {
                Text("(\(String(commitHash.prefix(6))))")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        AppVersionInfo()
        CompactVersionInfo()
    }
    .padding()
    .background(Color(.systemBackground))
}