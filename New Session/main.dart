import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  runApp(const BobCamApp());
}

class BobCamApp extends StatelessWidget {
  const BobCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BobCam',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;
  bool _isEating = false;
  String _statusMessage = "연결 대기 중...";
  String _videoId = "dQw4w9WgXcQ"; // 기본 비디오 ID
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initializeYoutubePlayer();
    _initializeBluetooth();
  }

  void _initializeYoutubePlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: _videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );
  }

  void _initializeBluetooth() {
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
          _isConnected = false;
          _statusMessage = "블루투스 연결이 끊어졌습니다";
        });
      }
    };

    // 연결 상태 변화 감지
    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      setState(() {
        _isConnected = isConnected;
        if (isConnected) {
          _statusMessage = "기기와 연결되었습니다";
        } else {
          _statusMessage = "기기와 연결이 끊어졌습니다";
        }
      });
    };

    // 데이터 수신 처리
    UniversalBle.onValueChange = (String deviceId, String characteristicId, dynamic value) {
      // 수신된 데이터를 문자열로 변환
      String dataString = String.fromCharCodes(value);
      
      // 식사 상태 업데이트
      if (dataString.contains("eating")) {
        setState(() {
          _isEating = true;
          _statusMessage = "아이가 밥을 먹고 있어요";
        });
        _controller.play();
      } else if (dataString.contains("not_eating")) {
        setState(() {
          _isEating = false;
          _statusMessage = "아이가 밥을 먹고 있지 않아요";
        });
        _controller.pause();
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
      _statusMessage = "기기 검색 중...";
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('BobCam - 스마트 식사 모니터'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 상태 메시지 표시
              Container(
                padding: const EdgeInsets.all(16.0),
                color: _isEating ? Colors.green.shade100 : Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isEating ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 유튜브 플레이어
              Expanded(
                child: YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.blueAccent,
                  onReady: () {
                    if (_isEating) {
                      _controller.play();
                    } else {
                      _controller.pause();
                    }
                  },
                ),
              ),
              
              // 비디오 ID 입력 필드
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '유튜브 비디오 ID 또는 URL',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          String? videoId;
                          if (value.contains('youtube.com') || value.contains('youtu.be')) {
                            videoId = YoutubePlayer.convertUrlToId(value);
                          } else {
                            videoId = value;
                          }
                          
                          if (videoId != null) {
                            setState(() {
                              _videoId = videoId!;
                              _controller.load(_videoId);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _startScan,
                      child: const Text('기기 검색'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 캐릭터를 위한 공간 (화면 가장자리)
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
    );
  }
}
