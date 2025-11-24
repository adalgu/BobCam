# PHPickerViewController Video Selection Integration

## Overview

This implementation replaces the hardcoded `sample_video.mp4` with a complete video selection system that allows users to choose videos from their photo library. The system includes persistent storage, error handling, and seamless integration with the existing VideoService architecture.

## Architecture Components

### 1. VideoSelectionService.swift
**Main service class handling video selection logic**

**Key Features:**
- PHPickerViewController integration for video selection
- UserDefaults persistence for selected video URLs
- Video validation (format, size, playability)
- Local storage management in Documents directory
- Automatic cleanup of old video files
- Error handling with localized error messages

**Error Handling:**
- Import failures
- Invalid video formats
- File size restrictions (100MB limit)
- Access permission issues
- Storage failures

### 2. VideoPickerView.swift
**SwiftUI wrapper for PHPickerViewController**

**Components:**
- `VideoPickerView`: UIViewControllerRepresentable wrapper
- `VideoSelectionButton`: UI control for triggering selection
- `VideoPreviewCard`: Displays current video information and status

**Features:**
- Video-only picker configuration
- Selection limit of 1 video
- User-friendly button states
- Loading and error state display
- Confirmation alerts for video changes

### 3. SettingsView.swift
**Comprehensive settings interface**

**Sections:**
- Video settings with preview and selection controls
- Detection sensitivity configuration
- App information and privacy notices
- Real-time status indicators

### 4. Updated Integration Files

#### ContentView.swift
- Added VideoSelectionService integration
- Settings modal presentation
- Gear icon button in top-right corner
- Proper service initialization pattern

#### CameraView.swift (VideoPlayerView)
- Removed hardcoded video loading
- Added VideoSelectionButton integration
- Enhanced placeholder and error states
- Video selection button overlay when playing

#### Info.plist
- Added NSPhotoLibraryUsageDescription permission
- Updated privacy API types for photo library access
- Proper privacy compliance for App Store

## Usage Flow

### Initial App Launch
1. VideoSelectionService checks UserDefaults for saved video URL
2. If found and file exists, loads the saved video
3. If not found, loads default sample_video.mp4
4. VideoService receives the video URL and initializes player

### Video Selection Process
1. User taps video selection button
2. PHPickerViewController presents with video-only filter
3. User selects video from photo library
4. System validates video (format, size, playability)
5. Video copied to app's Documents directory
6. URL saved to UserDefaults for persistence
7. VideoService loads the new video
8. UI updates to reflect new video status

### Persistence System
- Selected video URLs stored in UserDefaults
- Video files copied to `Documents/BobCamVideos/`
- Automatic cleanup of old video files
- Fallback to default video if saved file missing

## Configuration

### Video Validation Rules
- Maximum file size: 100MB
- Supported formats: .movie, .video, .mpeg4Movie, .quickTimeMovie
- Must be playable by AVAsset
- Must have duration > 0

### Storage Location
- Videos stored in: `Documents/BobCamVideos/selected_video_{timestamp}.{ext}`
- UserDefaults key: "selectedVideoURL"
- Automatic cleanup on new video selection

## UI Integration Points

### Main Interface
- **Top-right corner**: Settings gear icon
- **Video area**: Selection button when no video loaded
- **Video overlay**: Selection button when video is playing
- **Error states**: Selection button in error display

### Settings Screen
- **Video Settings Section**: Preview card and selection controls
- **Detection Settings**: Sensitivity slider and status display
- **App Info**: Version, developer, privacy information

## Error Handling

### User-Facing Errors
- **Import Failed**: "비디오를 가져올 수 없습니다"
- **Invalid Format**: "지원하지 않는 비디오 형식입니다"
- **File Too Large**: "비디오 파일이 너무 큽니다 (최대 100MB)"
- **Copy Failed**: "비디오 파일을 저장할 수 없습니다"
- **Access Denied**: "비디오에 접근할 수 없습니다"

### Recovery Mechanisms
- Automatic fallback to default video
- Clear selected video and start fresh
- Reset to default video option
- Retry selection option in error states

## Privacy & Permissions

### Required Permissions
- **NSPhotoLibraryUsageDescription**: For video selection from photo library
- **NSCameraUsageDescription**: Existing camera permission for face detection
- **Privacy API Types**: Declared access to photo library for App Store compliance

### Data Privacy
- All video processing occurs locally on device
- No video data transmitted to external servers
- Selected videos stored securely in app sandbox
- User can clear selected videos at any time

## Testing

### Integration Test
- `VideoSelectionIntegrationTest.swift`: Comprehensive test view
- Tests default video loading, selection flow, and persistence
- Useful for development and debugging

### Testing Scenarios
1. **Default Loading**: App launches with default video
2. **Video Selection**: User selects video from library
3. **Persistence**: Selected video persists across app restarts
4. **Error Handling**: Invalid video formats handled gracefully
5. **Storage Management**: Old videos cleaned up properly

## Implementation Benefits

### User Experience
- Personalized video content for feeding sessions
- Intuitive video selection interface
- Persistent video preferences
- Clear error messages and recovery options

### Technical Benefits
- Modular, testable architecture
- Proper separation of concerns
- Memory-efficient storage management
- Robust error handling
- SwiftUI-native implementation

### Maintenance
- Protocol-based design for easy extension
- Comprehensive error handling
- Clear documentation and code organization
- Easy to add new video sources in future

## Future Enhancements

### Potential Additions
- Multiple video playlist support
- Video preview during selection
- Video editing/trimming capabilities
- Cloud storage integration
- Video format conversion
- Bulk video import

### Performance Optimizations
- Background video processing
- Thumbnail generation
- Video compression options
- Streaming video support

## Code Quality

### Swift Best Practices
- Protocol-oriented programming
- Combine framework for reactive programming
- Proper memory management with weak references
- SwiftUI state management patterns
- Async/await for modern concurrency

### Error Resilience
- Comprehensive error types
- Graceful degradation
- User-friendly error messages
- Automatic recovery mechanisms
- Logging for debugging

This implementation provides a production-ready video selection system that enhances the BobCam app's functionality while maintaining the existing eating detection and video playback features.