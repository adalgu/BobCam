import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:camera/camera.dart';
import 'package:universal_ble/universal_ble.dart';
import 'dart:convert';
import 'dart:async';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  bool _isEating = false;
  List<Face>? _faces;
  Timer? _statusTimer;
  int _eatingFrames = 0;
  int _notEatingFrames = 0;
  final int _frameThreshold = 10; // 상태 변경을 위한 프레임 임계값
  String _connectedDeviceId = '';
  String _statusMessage = '카메라 초기화 중...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
    _initializeBluetoothConnection();
    
    // 상태 업데이트 타이머 설정 (1초마다)
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateEatingStatus();
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {
        _statusMessage = '카메라가 준비되었습니다';
      });
      _startImageStream();
    }
  }

  void _initializeFaceDetector() {
    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  void _initializeBluetoothConnection() {
    // 블루투스 가용성 확인
    UniversalBle.getBluetoothAvailabilityState().then((state) {
      if (state == AvailabilityState.poweredOn) {
        _startScan();
      } else {
        setState(() {
          _statusMessage = "블루투스를 활성화해주세요";
        });
      }
    });

    // 블루투스 상태 변화 감지
    UniversalBle.onAvailabilityChange = (state) {
      if (state == AvailabilityState.poweredOn) {
        _startScan();
      } else {
        setState(() {
          _connectedDeviceId = '';
          _statusMessage = "블루투스 연결이 끊어졌습니다";
        });
      }
    };

    // 연결 상태 변화 감지
    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      if (isConnected) {
        setState(() {
          _connectedDeviceId = deviceId;
          _statusMessage = "태블릿과 연결되었습니다";
        });
      } else {
        setState(() {
          _connectedDeviceId = '';
          _statusMessage = "태블릿과 연결이 끊어졌습니다";
        });
      }
    };
  }

  void _startScan() {
    // 스캔 결과 처리
    UniversalBle.onScanResult = (bleDevice) {
      // BobCam 기기 이름으로 필터링 (실제 구현 시 기기 이름 변경 필요)
      if (bleDevice.name?.contains("BobCam") ?? false) {
        // 스캔 중지
        UniversalBle.stopScan();
        
        // 기기 연결
        UniversalBle.connect(bleDevice.deviceId);
      }
    };

    // 스캔 시작
    UniversalBle.startScan();
    setState(() {
      _statusMessage = "태블릿 검색 중...";
    });
  }

  void _startImageStream() {
    _cameraController!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    final inputImage = _convertCameraImageToInputImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);
      if (mounted) {
        setState(() {
          _faces = faces;
          if (faces.isNotEmpty) {
            _analyzeEatingBehavior(faces.first);
          } else {
            // 얼굴이 감지되지 않음
            _notEatingFrames++;
            _eatingFrames = 0;
          }
        });
      }
    } catch (e) {
      print('Face detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    // 이 부분은 실제 구현 시 카메라 이미지 포맷에 따라 변환 로직이 필요합니다.
    // 간단한 구현을 위해 null을 반환하고 실제 구현 시 수정이 필요합니다.
    return null;
  }

  void _analyzeEatingBehavior(Face face) {
    // 입 움직임 분석 (실제 구현 시 더 정교한 알고리즘 필요)
    final mouth = face.contours[FaceContourType.lowerLipBottom];
    if (mouth != null && mouth.points.isNotEmpty) {
      // 입이 열려 있는지 확인 (간단한 예시)
      final mouthOpen = face.smilingProbability != null && face.smilingProbability! > 0.5;
      
      if (mouthOpen) {
        _eatingFrames++;
        _notEatingFrames = 0;
      } else {
        _notEatingFrames++;
        _eatingFrames = 0;
      }
    }
  }

  void _updateEatingStatus() {
    bool previousStatus = _isEating;
    
    // 상태 업데이트
    if (_eatingFrames > _frameThreshold) {
      _isEating = true;
    } else if (_notEatingFrames > _frameThreshold) {
      _isEating = false;
    }
    
    // 상태가 변경되었고 블루투스가 연결되어 있으면 메시지 전송
    if (previousStatus != _isEating && _connectedDeviceId.isNotEmpty) {
      _sendEatingStatus();
    }
    
    // UI 업데이트
    setState(() {
      if (_isEating) {
        _statusMessage = "아이가 밥을 먹고 있어요";
      } else {
        _statusMessage = "아이가 밥을 먹고 있지 않아요";
      }
    });
  }

  void _sendEatingStatus() {
    if (_connectedDeviceId.isEmpty) return;
    
    // 상태 메시지 생성
    final message = {
      'status': _isEating ? 'eating' : 'not_eating',
      'confidence': 0.95,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    // JSON 문자열로 변환
    final jsonMessage = jsonEncode(message);
    
    // 블루투스로 전송 (실제 구현 시 서비스 및 특성 UUID 필요)
    // 이 부분은 실제 기기와 통신 시 수정이 필요합니다
    // UniversalBle.writeValue(_connectedDeviceId, serviceUuid, characteristicUuid, Uint8List.fromList(jsonMessage.codeUnits));
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BobCam - 카메라'),
        backgroundColor: _isEating ? Colors.green : Colors.red,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 카메라 미리보기
                CameraPreview(_cameraController!),
                
                // 얼굴 감지 표시
                if (_faces != null)
                  CustomPaint(
                    painter: FacePainter(_faces!, Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    )),
                  ),
                
                // 상태 메시지
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: _isEating ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                // 캐릭터 영역
                Positioned(
                  right: 0,
                  top: 100,
                  child: Container(
                    width: 80,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '캐릭터\n영역',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 컨트롤 영역
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _startScan,
                  child: const Text('태블릿 검색'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isEating = !_isEating;
                      if (_connectedDeviceId.isNotEmpty) {
                        _sendEatingStatus();
                      }
                    });
                  },
                  child: Text(_isEating ? '식사 중지' : '식사 시작'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    for (var face in faces) {
      // 얼굴 바운딩 박스 그리기
      final rect = Rect.fromLTRB(
        face.boundingBox.left * size.width / imageSize.width,
        face.boundingBox.top * size.height / imageSize.height,
        face.boundingBox.right * size.width / imageSize.width,
        face.boundingBox.bottom * size.height / imageSize.height,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
