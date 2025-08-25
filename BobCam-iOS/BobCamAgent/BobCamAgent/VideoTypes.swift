import Foundation

// MARK: - Video Type Enumeration
enum VideoType: Equatable, CaseIterable {
    case local(URL)
    case youtube(YouTubeVideo)
    
    static func == (lhs: VideoType, rhs: VideoType) -> Bool {
        switch (lhs, rhs) {
        case (.local(let lhsURL), .local(let rhsURL)):
            return lhsURL == rhsURL
        case (.youtube(let lhsVideo), .youtube(let rhsVideo)):
            return lhsVideo.videoId == rhsVideo.videoId
        default:
            return false
        }
    }
    
    static var allCases: [VideoType] {
        return [] // Cannot enumerate all possible cases due to associated values
    }
    
    var isLocal: Bool {
        if case .local = self {
            return true
        }
        return false
    }
    
    var isYouTube: Bool {
        if case .youtube = self {
            return true
        }
        return false
    }
    
    var displayName: String {
        switch self {
        case .local(let url):
            return url.lastPathComponent
        case .youtube(let video):
            return video.title ?? "YouTube Video"
        }
    }
    
    var description: String {
        switch self {
        case .local(let url):
            return "Local: \(url.lastPathComponent)"
        case .youtube(let video):
            return "YouTube: \(video.title ?? video.videoId)"
        }
    }
}

// MARK: - YouTube Video Model
struct YouTubeVideo: Codable, Equatable {
    let videoId: String
    let title: String?
    let channelTitle: String?
    let thumbnailURL: URL?
    let duration: TimeInterval?
    let isChildSafe: Bool
    
    init(videoId: String, title: String? = nil, channelTitle: String? = nil, 
         thumbnailURL: URL? = nil, duration: TimeInterval? = nil, isChildSafe: Bool = true) {
        self.videoId = videoId
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.isChildSafe = isChildSafe
    }
    
    var embedURL: URL? {
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoId)")
        components?.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "fs", value: "0"),
            URLQueryItem(name: "controls", value: "0"),
            URLQueryItem(name: "disablekb", value: "1"),
            URLQueryItem(name: "iv_load_policy", value: "3"),
            URLQueryItem(name: "cc_load_policy", value: "0"),
            URLQueryItem(name: "loop", value: "1"),
            URLQueryItem(name: "playlist", value: videoId)
        ]
        return components?.url
    }
    
    static func == (lhs: YouTubeVideo, rhs: YouTubeVideo) -> Bool {
        return lhs.videoId == rhs.videoId
    }
}

// MARK: - YouTube URL Utilities
struct YouTubeURLUtils {
    
    /// Extract video ID from various YouTube URL formats
    static func extractVideoId(from urlString: String) -> String? {
        let patterns = [
            #"(?:https?://)?(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:www\.)?youtu\.be/([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:m\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"#
        ]
        
        for pattern in patterns {
            if let range = urlString.range(of: pattern, options: .regularExpression),
               let videoIdRange = Range(NSRange(location: 0, length: 11), in: urlString[range]) {
                let match = String(urlString[range])
                if let videoId = extractVideoIdFromMatch(match) {
                    return videoId
                }
            }
        }
        
        return nil
    }
    
    private static func extractVideoIdFromMatch(_ match: String) -> String? {
        let patterns = [
            #"v=([a-zA-Z0-9_-]{11})"#,
            #"embed/([a-zA-Z0-9_-]{11})"#,
            #"youtu\.be/([a-zA-Z0-9_-]{11})"#
        ]
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let nsString = match as NSString
            let results = regex.matches(in: match, range: NSRange(location: 0, length: nsString.length))
            
            if let result = results.first,
               result.numberOfRanges > 1 {
                let videoIdRange = result.range(at: 1)
                return nsString.substring(with: videoIdRange)
            }
        }
        
        return nil
    }
    
    /// Validate if a string is a valid YouTube URL
    static func isValidYouTubeURL(_ urlString: String) -> Bool {
        return extractVideoId(from: urlString) != nil
    }
    
    /// Create YouTubeVideo from URL string
    static func createYouTubeVideo(from urlString: String) -> YouTubeVideo? {
        guard let videoId = extractVideoId(from: urlString) else {
            return nil
        }
        
        return YouTubeVideo(videoId: videoId, isChildSafe: true)
    }
}

// MARK: - Child Safety Filter
struct ChildSafetyFilter {
    
    /// Check if a YouTube video is child-safe based on various criteria
    static func isChildSafe(_ video: YouTubeVideo) -> Bool {
        // For now, we trust the isChildSafe flag
        // In a production app, this could integrate with YouTube API
        // to check for age restrictions, content categories, etc.
        return video.isChildSafe
    }
    
    /// List of known child-safe YouTube channels (curated list)
    static let childSafeChannels = [
        "Cocomelon - Nursery Rhymes",
        "Super Simple Songs",
        "Pinkfong Baby Shark",
        "Little Baby Bum",
        "ChuChu TV",
        "Dave and Ava"
    ]
    
    /// Validate URL for basic safety (no obvious adult content indicators)
    static func validateURL(_ urlString: String) -> Bool {
        let lowercaseURL = urlString.lowercased()
        let blockedKeywords = ["adult", "mature", "18+", "explicit", "violence"]
        
        return !blockedKeywords.contains { keyword in
            lowercaseURL.contains(keyword)
        }
    }
}