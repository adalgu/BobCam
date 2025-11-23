# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Run Commands

### Python Development
- Install dependencies: `pip install -e .` or `uv add -e .`
- Run main application: `cd backend && python main_stable.py`
- Run tests: `pytest backend/tests/`
- Run single test: `pytest backend/tests/test_file.py::test_function -v`
- Lint: `ruff check backend/`
- Format: `ruff format backend/`
- Type check: `mypy backend/`

### iOS Development
- Open project: `open BobCamAgent.xcworkspace` (recommended) or `open BobCamAgent.xcodeproj`
- Build and run: Use Xcode or `xcodebuild -workspace BobCamAgent.xcworkspace -scheme BobCamAgent -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- Run tests: `xcodebuild test -workspace BobCamAgent.xcworkspace -scheme BobCamAgent -destination 'platform=iOS Simulator,name=iPhone 15 Pro'`

### Development Environment
- Docker: `docker-compose up -d`
- UV package manager: See `uv-setup.md` for setup instructions

### Troubleshooting & Build Notes
- **CocoaPods & Workspace**: Always use `.xcworkspace` instead of `.xcodeproj` for builds when CocoaPods are involved.
  - *Error*: `ld: framework 'Pods_BobCamAgent' not found`
  - *Fix*: Use `xcodebuild -workspace BobCamAgent.xcworkspace ...`
- **SwiftUI Dependency Injection**: Ensure `@ObservedObject` properties are passed as instances, not types.
  - *Error*: `Cannot convert value of type 'DebugSettings.Type' to expected argument type 'DebugSettings'`
  - *Fix*: Check view initializations (e.g., `StatusBar(..., debugSettings: debugSettings)`) to ensure the instance is passed correctly.

## Project Architecture

### High-Level Structure
BobCam is a smart eating monitor that uses computer vision to track lip movements and automatically control video playback based on eating behavior. The project has two main implementations:

1. **Python Backend** (`backend/`): Original OpenCV + MediaPipe implementation with Tkinter GUI
2. **iOS Native App** (root level): Swift/SwiftUI implementation with Vision Framework

### Project Structure
```
BobCam/
├── BobCamAgent/              # iOS source code
├── BobCamAgent.xcodeproj     # Xcode project
├── BobCamAgent.xcworkspace   # Xcode workspace (CocoaPods)
├── BobCamAgentTests/         # iOS unit tests
├── BobCamAgentUITests/       # iOS UI tests
├── Podfile                   # CocoaPods configuration
├── fastlane/                 # Fastlane deployment scripts
├── ios-scripts/              # iOS build scripts
├── ios-docs/                 # iOS documentation
├── backend/                  # Python backend code
│   ├── main.py               # Integrated version
│   ├── main_stable.py        # Stable version
│   ├── tests/                # Python tests
│   └── legacy/               # Archived scripts
├── docs/                     # Project documentation
└── dev/                      # Development utilities
```

### Core Components

#### iOS Application (Root Level)
- **BobCamAgent/VisionService.swift**: Real-time lip tracking using Vision Framework with optimized 15fps processing
- **BobCamAgent/CameraService.swift**: AVFoundation-based camera capture with memory optimization (CVPixelBufferPool)
- **BobCamAgent/VideoService.swift**: AVPlayer-based video control with automatic play/pause and fade effects
- **BobCamAgent/ContentView.swift**: SwiftUI dual-view interface (camera 40% + video 60%)
- **BobCamAgent/StatusBar.swift**: Real-time sensitivity control and manual override system
- **BobCamAgent/Monitoring/**: Real-time performance and accuracy monitoring infrastructure
- **BobCamAgent/Utils/**: Supporting utilities including `CircularBuffer` for data management
- **BobCamAgent/ParameterTuning/**: Algorithm parameter optimization framework
- **BobCamAgent/DebugOverlay/**: Debug visualization tools

#### Python Backend (`backend/`)
- **backend/main.py**: Integrated version with all features
- **backend/main_stable.py**: Stable version for production use
- **backend/main_enhanced.py**: Advanced features version
- **backend/tests/**: Python test files
- **backend/legacy/**: Archived legacy scripts

### Key Architecture Patterns

#### Protocol-Oriented Design
```swift
protocol FaceTrackingServiceProtocol: ObservableObject {
    var isEating: Bool { get }
    var serviceState: VisionServiceState { get }
    func processFrame(_ pixelBuffer: CVPixelBuffer)
}
```

#### Configuration-Based System
- `LipDetectionConfiguration`: Externalized parameters for algorithm tuning
- Supports A/B testing and dynamic parameter adjustment
- Removes magic numbers and hardcoded values

#### Memory Optimization
- CVPixelBufferPool for efficient memory management
- VNSequenceRequestHandler reuse for Vision Framework
- Frame throttling (60fps input → 15fps processing)

### Performance Characteristics
- Target latency: 200ms (realistic for Vision Framework)
- Processing rate: 15fps (optimized from 60fps input)
- Memory usage: Optimized with buffer pooling
- Battery efficiency: Adaptive frame rate based on device state

## Development Guidelines

### Code Style
- Swift: Follow Apple Swift API guidelines
- Python: Use Python 3.8+ with type hints, follow PEP 8
- Naming: snake_case for Python, camelCase for Swift
- Documentation: Comprehensive docstrings and inline comments

### Testing Strategy
- Unit tests for core algorithms (lip movement detection)
- Integration tests for camera/vision pipeline
- Performance benchmarks for real-time processing
- UI tests for user interactions

### Error Handling
- Comprehensive error recovery mechanisms
- State-based error propagation
- Graceful degradation for hardware limitations
- User-friendly error messages

## Project Status & Development Phases

### Phase 1: Core Vision Framework Implementation (✅ Complete)
- Real-time lip tracking with Vision Framework
- Complete iOS app with SwiftUI interface
- Memory-optimized camera pipeline
- Protocol-based architecture for extensibility

### Phase 2: Algorithm Accuracy Improvement (🔄 In Progress)
- Enhanced lip movement detection algorithms
- A/B testing framework for parameter optimization
- Real-time accuracy monitoring system
- Environmental adaptation (lighting, distance)

### Phase 3: System Integration & UX (📋 Planned)
- Advanced UI/UX features and settings
- Performance optimization with Metal
- Comprehensive testing and validation

### Phase 4: Deployment & Monitoring (📋 Planned)
- App Store deployment preparation
- Real-world usage monitoring
- Performance analytics and optimization

## Important Files & Dependencies

### Core Algorithm Files
- `BobCam-iOS/VisionService.swift`: Main lip tracking implementation
- `BobCam-iOS/LipDetectionImproved.swift`: Enhanced detection algorithms
- `BobCam-iOS/Monitoring/`: Accuracy and performance monitoring utilities

### Configuration Files
- `pyproject.toml`: Python dependencies and project metadata
- `BobCam-iOS/Info.plist`: iOS app configuration and permissions
- `iOS-Development-TODO.md`: Detailed development roadmap

### Documentation
- `README.md`: Project overview and setup instructions
- `iOS-Architecture-Plan.md`: Detailed iOS architecture design
- `memory-bank/`: Project context and development history

## Expert Review Notes

The codebase has undergone expert technical review with all critical issues resolved:
- Magic numbers replaced with configuration system
- Error handling enhanced with state-based propagation
- Memory optimization through buffer pooling
- Thread safety ensured across all services
- Frame rate independence achieved through internal throttling

## Security & Privacy

- All processing occurs locally on device
- No data transmission to external servers
- Camera permissions properly handled
- Child privacy protection compliant with App Store guidelines
- Secure coding practices followed throughout

## Subagent Collaboration Framework

### Available Subagents
The project utilizes a multi-agent CLI system for parallel development and diverse problem-solving approaches:

1. **🤖 Gemini CLI** (`gemini -p "prompt" -m "gemini-2.5-pro"`)
   - Strengths: Creative thinking, multimodal processing, rapid responses
   - Role: Content generation, innovative ideas, architectural brainstorming

2. **🎭 Claude CLI** (`claude -p "prompt"`)
   - Strengths: Software engineering, code analysis, debugging
   - Role: Code review, architecture design, development workflows

3. **🧠 Zen Agent (MCP)** (`zen:chat`)
   - Strengths: Advanced reasoning, technical decision support
   - Role: Collaborative thinking, verification, practical solutions

4. **⚡ Codex CLI** (`codex exec "prompt" --model "o4-mini" --full-auto`)
   - Strengths: Code generation, automation, rapid development
   - Role: Fast prototyping, automation scripts, basic implementations

### Collaboration Patterns

#### Pattern 1: Perspective-Based Distribution
```bash
# Analyze problem from different angles
gemini -p "Creative perspective on [problem]" &
claude -p "Engineering perspective on [problem]" &
codex exec "Efficiency perspective on [problem]" --model "o4-mini" &
```

#### Pattern 2: Sequential Pipeline
1. **Gemini**: Idea generation and conceptual design
2. **Claude**: Technical validation and architecture
3. **Codex**: Implementation and automation
4. **Zen**: Final review and decision support

#### Pattern 3: Specialized Domain Assignment
- **Gemini**: User experience improvements, creative solutions
- **Claude**: Core algorithm development, system integration
- **Codex**: Rapid prototyping, test automation
- **Zen**: Quality assurance, architectural decisions

### Project-Specific Usage Examples

#### Phase 2 Algorithm Improvement
```bash
# Parallel accuracy improvement approach
gemini -p "Innovative lip tracking accuracy improvement ideas" &
claude -p "Technical implementation of accuracy monitoring system" &
codex exec "Generate accuracy testing automation scripts" --model "o4-mini" &
# zen:planner for strategic coordination
```

#### Performance Optimization
```bash
# Distributed performance analysis
gemini -p "User experience impact of performance changes" &
claude -p "Memory optimization strategies for Vision Framework" &
codex exec "Automated performance benchmarking tools" --model "o4-mini" &
```

## MANDATORY: Expert Subagent Usage

**CRITICAL REQUIREMENT**: All development tasks MUST utilize expert subagents through the Task tool or Zen MCP tools. This is a non-negotiable project requirement.

### Required Workflow Pattern
1. **Initial Analysis**: Use appropriate expert agents to analyze tasks
2. **Implementation**: Coordinate through multiple specialized agents
3. **Quality Assurance**: Always validate with expert review agents
4. **Integration**: Use collaborative agents for system-wide changes

### Subagent Selection Guidelines
- **Complex algorithms**: Use `typescript-pro`, `ios-developer`, or `python-pro`
- **Architecture decisions**: Use `backend-architect` or `architect-reviewer`
- **Testing**: Use `test-automator` or `debugger`
- **Code quality**: Always use `code-reviewer` after implementation
- **Performance**: Use `performance-engineer` for optimization
- **Planning**: Use Zen MCP `planner` or `consensus` tools

## Handoff Context & Next Tasks

### Current Phase: Phase 2 - Algorithm Accuracy Improvement (Priority: HIGHEST)
Based on handoff document `handoff_20250821_phase2_development_start.md`, the project is focused on:

#### Immediate Priorities (70% Accuracy Goal)
1. **Algorithm Tuning System** - Build test harness with pre-recorded videos
2. **Data Collection Pipeline** - Gather diverse children's eating videos with ground truth labels
3. **Parameter Optimization** - Tune `LipDetectionConfiguration` parameters systematically
4. **Debug UI Implementation** - Visual overlay for real-time algorithm debugging

#### Core Development Tasks
1. **Video Selection Feature** - Replace hardcoded `sample_video.mp4` with `PHPickerViewController`
2. **Settings Screen** - Complete `SettingsView` with video selection and privacy settings
3. **Polish & Testing** - Final UI/UX refinement and exception handling
4. **App Store Preparation** - Ensure production-ready stability

### Key Architecture Updates Since Phase 1
- **`OptimizedLipDetectionService`**: Advanced algorithm with EMA smoothing and `CircularBuffer`
- **Monitoring Integration**: `AccuracyMonitor` and `PerformanceMonitor` for real-time metrics
- **Enhanced UI Controls**: `StatusBar` with user sensitivity controls and manual overrides
- **Validation Framework**: `Phase2ValidationTest` for integration testing

### Critical Files for Phase 2
- `BobCam-iOS/VisionService.swift`: Core service requiring algorithm integration
- `BobCam-iOS/LipDetectionImproved.swift`: Algorithm needing 70% accuracy tuning
- `BobCam-iOS/VideoService.swift`: Needs video selection capability
- `BobCam-iOS/SettingsView.swift`: Currently placeholder, needs full implementation
- `BobCam-iOS/Monitoring/`: Real-time performance tracking infrastructure

## Common Development Tasks

### Adding New Lip Detection Algorithm
1. Implement `FaceTrackingServiceProtocol`
2. Add configuration parameters to `LipDetectionConfiguration`
3. Update `VisionService` to use new implementation
4. Add comprehensive unit tests

### Performance Optimization
1. Use Instruments to profile performance bottlenecks
2. Optimize frame processing pipeline
3. Adjust `frameSkipInterval` in CameraService
4. Monitor memory usage with buffer pools

### UI/UX Improvements
1. Follow SwiftUI best practices
2. Ensure VoiceOver accessibility compliance
3. Test across different device sizes
4. Maintain consistent design language

### Multi-Agent Development Workflow (MANDATORY)
**IMPORTANT**: Every development task requires expert subagent involvement. No exceptions.

1. **Task Initiation**: Always start with Task tool to select appropriate expert agent
2. **Parallel Execution**: Use multiple specialized agents for independent analysis
3. **Sequential Validation**: Implement review pipelines with expert validation
4. **Quality Gates**: Use `code-reviewer`, `architect-reviewer` for all code changes
5. **Strategic Coordination**: Coordinate complex decisions through Zen MCP tools

### Phase 2 Specific Workflows
- **Algorithm Tuning**: Use `ios-developer` + `performance-engineer` + Zen `consensus`
- **UI Implementation**: Use `frontend-developer` + `ui-ux-designer` + `code-reviewer`
- **Testing Framework**: Use `test-automator` + `debugger` + validation agents
- **Integration Tasks**: Always use `architect-reviewer` for system-wide changes

## Acceptance Criteria & Quality Gates

### Phase 2 Success Metrics
- **Primary Goal**: Lip detection algorithm achieves 70%+ accuracy across diverse test videos
- **User Experience**: Video selection from photo library with persistent settings
- **Debug Capability**: Real-time performance/accuracy metrics display in debug mode
- **Stability**: All settings screen functions operational and stable
- **Production Ready**: App Store submission quality with comprehensive error handling

### Quality Validation Process
1. **Algorithm Accuracy**: Validated against ground truth labeled dataset
2. **Performance Benchmarks**: Meets target 15fps processing with <200ms latency
3. **User Interface**: Complete settings functionality with proper navigation
4. **Error Handling**: Graceful degradation for all edge cases
5. **Privacy Compliance**: Local processing with no external data transmission

### Technical Debt Resolution
- No hardcoded video paths (`sample_video.mp4` replacement)
- Complete settings screen implementation (currently placeholder)
- Debug UI overlay system for development and tuning
- Comprehensive test coverage for new algorithm components