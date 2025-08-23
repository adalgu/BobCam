# YouTube WKWebView Integration for BobCam iOS App

## Overview

This implementation adds YouTube video playback support to the BobCam iOS app while maintaining full backward compatibility with existing local video functionality. The integration uses WKWebView with the YouTube iframe API to provide seamless video control from eating detection.

## Architecture

### Core Components

1. **VideoTypes.swift** - Defines video type enumeration and YouTube models
2. **YouTubePlayerView.swift** - WKWebView-based YouTube player with iframe API
3. **VideoService.swift** - Updated to support both local and YouTube videos
4. **VideoSelectionService.swift** - Enhanced to handle YouTube URL input
5. **VideoPlayerView.swift** - Updated UI to switch between AVPlayer and WKWebView
6. **YouTubeIntegrationTest.swift** - Comprehensive testing framework

### Key Features

- **Dual Video Support**: Seamlessly handles both local video files and YouTube URLs
- **Child Safety Filtering**: Built-in content filtering for age-appropriate content
- **Network Connectivity**: Automatic network monitoring with graceful fallback
- **Inline Playback**: WKWebView configured for inline media playback without controls
- **JavaScript Communication**: Bidirectional communication for video control
- **Eating Detection Integration**: Full compatibility with existing play/pause controls

## Implementation Details

### VideoType Enum

```swift
enum VideoType: Equatable {
    case local(URL)
    case youtube(YouTubeVideo)
    
    var isLocal: Bool
    var isYouTube: Bool
    var displayName: String
}
```

### YouTubeVideo Model

```swift
struct YouTubeVideo: Codable, Equatable {
    let videoId: String
    let title: String?
    let channelTitle: String?
    let thumbnailURL: URL?
    let duration: TimeInterval?
    let isChildSafe: Bool
    
    var embedURL: URL? // Generates iframe embed URL with parameters
}
```

### YouTube URL Validation

```swift
struct YouTubeURLUtils {
    static func extractVideoId(from urlString: String) -> String?
    static func isValidYouTubeURL(_ urlString: String) -> Bool
    static func createYouTubeVideo(from urlString: String) -> YouTubeVideo?
}
```

### Child Safety Filter

```swift
struct ChildSafetyFilter {
    static func isChildSafe(_ video: YouTubeVideo) -> Bool
    static func validateURL(_ urlString: String) -> Bool
    static let childSafeChannels: [String]
}
```

## YouTube Player Implementation

### WKWebView Configuration

- **Inline Playback**: `allowsInlineMediaPlayback = true`
- **Auto-play Support**: `mediaTypesRequiringUserActionForPlayback = []`
- **PiP Disabled**: `allowsPictureInPictureMediaPlaybook = false`
- **Scroll Disabled**: Prevents user interaction beyond video playback

### iframe API Integration

The YouTube iframe API provides:
- Video state monitoring (playing, paused, buffering, ended)
- Programmatic control (play, pause, stop, seek)
- Error handling and network status
- Automatic looping with playlist parameter

### JavaScript Bridge

```javascript
// Control functions callable from Swift
function playVideo()
function pauseVideo()
function stopVideo()
function seekToStart()

// Event handlers that communicate to Swift
function onPlayerReady(event)
function onPlayerStateChange(event) 
function onPlayerError(event)
```

## Updated Services

### VideoService Changes

- **Dual Player Support**: Maintains both AVQueuePlayer and YouTubePlayerController
- **Network Monitoring**: Uses NWPathMonitor for connectivity status
- **State Management**: Unified playback state across both player types
- **Error Handling**: Comprehensive error recovery for network issues

### VideoSelectionService Changes

- **YouTube URL Input**: New input method with validation
- **Persistence**: Stores both local and YouTube video preferences
- **Source Selection**: UI for choosing between photo library, YouTube, and default video

### VideoPlayerView Changes

- **Dynamic Player Switching**: Conditionally renders AVPlayer or YouTubePlayerView
- **Network Status UI**: Shows connectivity warnings for YouTube content
- **Error Recovery**: Provides fallback options when videos fail to load

## User Interface Updates

### Video Selection Flow

1. **Source Selection Sheet**: Choose from Photo Library, YouTube URL, or Default Video
2. **YouTube URL Input**: Dedicated interface for URL entry with validation
3. **Network Status**: Visual indicators for connectivity requirements
4. **Error Handling**: Clear error messages with recovery options

### Video Status Indicators

- **Video Type Icons**: Different icons for local vs YouTube content
- **Connection Status**: Network availability warnings
- **Loading States**: Progress indicators during YouTube validation

## Network Handling

### Connectivity Monitoring

```swift
private let networkMonitor = NWPathMonitor()
private let networkQueue = DispatchQueue(label: "NetworkMonitor")

networkMonitor.pathUpdateHandler = { [weak self] path in
    DispatchQueue.main.async {
        self?.isNetworkAvailable = path.status == .satisfied
        // Auto-pause YouTube content if network becomes unavailable
    }
}
```

### Error Recovery

- **Network Loss**: Automatically pauses YouTube videos
- **Invalid URLs**: Clear validation errors with suggestions
- **Content Restrictions**: Child safety warnings with alternatives
- **Load Failures**: Fallback to local video or retry options

## Security Considerations

### Child Safety

- **URL Validation**: Blocks obviously inappropriate content keywords
- **Channel Whitelist**: Curated list of child-safe channels
- **Age Restriction**: Defaults to child-safe content assumption
- **Content Filtering**: Multiple layers of safety validation

### Privacy Protection

- **Local Processing**: All eating detection remains on-device
- **No Data Transmission**: YouTube integration doesn't share user data
- **Secure Communication**: HTTPS-only for YouTube content
- **Minimal Permissions**: Only required network access

## Performance Optimization

### Memory Management

- **Buffer Pooling**: Continues existing CVPixelBufferPool optimization
- **Player Cleanup**: Proper resource cleanup for both player types
- **Background Handling**: Intelligent pause/resume based on app state

### Network Efficiency

- **Connection Monitoring**: Proactive network status tracking
- **Bandwidth Consideration**: YouTube player automatically adapts quality
- **Caching**: Leverages WKWebView's built-in caching mechanisms

## Testing Framework

### YouTubeIntegrationTest

Comprehensive test suite covering:

1. **URL Validation**: Tests various YouTube URL formats
2. **VideoType Creation**: Validates enum functionality
3. **Child Safety Filter**: Ensures content filtering works
4. **Service Integration**: Tests VideoService compatibility
5. **Selection Service**: Validates YouTube URL handling

### Test UI

```swift
struct YouTubeIntegrationTestView: View {
    @StateObject private var testRunner = YouTubeIntegrationTest()
    // Interactive test execution with results display
}
```

## Integration with Existing Features

### Eating Detection Compatibility

- **Play/Pause Control**: Seamlessly works with both video types
- **State Synchronization**: Unified isPlaying state management  
- **Performance Monitoring**: Existing monitoring works with YouTube
- **Debug Overlay**: Compatible with debug UI features

### Settings Integration

- **Persistent Storage**: YouTube preferences saved to UserDefaults
- **Reset Functionality**: Can revert to default video at any time
- **Privacy Settings**: Clear indication of network requirements

## Usage Instructions

### For Users

1. **Tap Video Selection Button** in VideoPlayerView
2. **Choose YouTube URL** from source options
3. **Enter Valid YouTube URL** (supports various formats)
4. **Confirm Selection** - app validates and loads video
5. **Eating Detection** controls play/pause automatically

### For Developers

1. **Add Files to Xcode Project**: Ensure all new Swift files are included
2. **Update Info.plist**: Add required network permissions if needed
3. **Test Network Connectivity**: Verify behavior with/without internet
4. **Run Integration Tests**: Use YouTubeIntegrationTestView for validation

## Supported YouTube URL Formats

- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://m.youtube.com/watch?v=VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`

## Error Handling

### Common Errors and Solutions

1. **Invalid URL**: Clear validation message with format examples
2. **Network Unavailable**: Graceful fallback with retry options
3. **Content Restricted**: Child safety warning with alternatives
4. **Load Timeout**: Automatic retry with local video fallback
5. **Player Initialization Failed**: Error recovery with diagnostics

## Future Enhancements

### Potential Improvements

1. **YouTube API Integration**: Full metadata retrieval and validation
2. **Content Recommendation**: Curated child-safe video suggestions
3. **Offline Caching**: Download capability for offline playbook
4. **Parental Controls**: Enhanced content filtering options
5. **Analytics Integration**: Usage tracking and preference learning

### Architecture Extensions

1. **Plugin System**: Support for additional video sources
2. **Custom Player Controls**: Enhanced UI for video management
3. **Batch Selection**: Multiple video queue management
4. **Smart Recommendations**: ML-based content suggestions

## Conclusion

This YouTube WKWebView integration provides a robust, child-safe, and performant solution for online video playbook while maintaining full backward compatibility with existing local video functionality. The implementation follows iOS best practices, includes comprehensive error handling, and provides a seamless user experience that integrates perfectly with the existing eating detection system.

The modular architecture allows for easy future enhancements while the comprehensive testing framework ensures reliability and maintainability of the codebase.