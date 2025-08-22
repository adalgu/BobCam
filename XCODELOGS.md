Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.
Type: Fault | Timestamp: 2025-08-22 10:41:12.881714+09:00 | Process: BobCamAgent | Library: SwiftUICore | Subsystem: com.apple.runtime-issues | Category: SwiftUI | TID: 0xf900
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Type: stdio
App is being debugged, do not track this hang
Type: Error | Timestamp: 2025-08-22 10:41:13.994158+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Hang detected: 0.77s (debugger attached, not reporting)
Type: Error | Timestamp: 2025-08-22 10:41:13.994268+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Type: stdio
App is being debugged, do not track this hang
Type: Error | Timestamp: 2025-08-22 10:41:14.396762+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Hang detected: 0.40s (debugger attached, not reporting)
Type: Error | Timestamp: 2025-08-22 10:41:14.396835+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Frame dropped
Type: stdio
void * _Nullable NSMapGet(NSMapTable * _Nonnull, const void * _Nullable): map table argument is NULL
Type: Notice | Timestamp: 2025-08-22 10:41:14.594221+09:00 | Process: BobCamAgent | Library: Foundation | TID: 0xf700
Frame dropped
Type: stdio
Unknown client: BobCamAgent
Type: Error | Timestamp: 2025-08-22 10:41:14.805473+09:00 | Process: BobCamAgent | Library: AXRuntime | Subsystem: com.apple.Accessibility | Category: AXRuntimeCommon | TID: 0xf700
Frame dropped
Type: stdio
App is being debugged, do not track this hang
Type: Error | Timestamp: 2025-08-22 10:41:14.914859+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Hang detected: 0.32s (debugger attached, not reporting)
Type: Error | Timestamp: 2025-08-22 10:41:14.914896+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Type: stdio
App is being debugged, do not track this hang
Type: Error | Timestamp: 2025-08-22 10:41:15.850466+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Hang detected: 0.66s (debugger attached, not reporting)
Type: Error | Timestamp: 2025-08-22 10:41:15.850500+09:00 | Process: BobCamAgent | Library: HangTracer | Subsystem: com.apple.hangtracer | Category:  | TID: 0xf700
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Type: stdio
AX Lookup problem - errorCode:1100 error:Permission denied portName:'com.apple.iphone.axserver' PID:875 (
	0   AXRuntime                           0x00000001ca7c60ac _AXGetPortFromCache + 796
	1   AXRuntime                           0x00000001ca7cab70 AXUIElementPerformFencedActionWithValue + 700
	2   UIKit                               0x000000024ea8445c EA3EC8A2-C802-395D-973F-2538FE1A8697 + 1561692
	3   libdispatch.dylib                   0x0000000103474584 _dispatch_call_block_and_release + 32
	4   libdispatch.dylib                   0x000000010348e064 _dispatch_client_callout + 16
	5   libdispatch.dylib                   0x000000010347c91c _dispatch_lane_serial_drain + 796
	6   libdispatch.dylib                   0x000000010347d5a4 _dispatch_lane_invoke + 432
	7   libdispatch.dylib                   0x0000000103489894 _dispatch_root_queue_drain_deferred_wlh + 344
	8   libdispatch.dylib                   0x0000000103488eb0 _dispatch_workloop_worker_thread + 580
	9   libsystem_pthread.dylib             0x000000021d03ca0c _pthread_wqthread + 292
	10  libsystem_pthread.dylib             0x000000021d03caac start_wqthread + 8
)
Type: Error | Timestamp: 2025-08-22 10:41:25.286418+09:00 | Process: BobCamAgent | Library: AXRuntime | Subsystem: com.apple.Accessibility | Category: AXRuntimeCommon | TID: 0xf8fa
AX Lookup problem - errorCode:1100 error:Permission denied portName:'com.apple.iphone.axserver' PID:875 (
	0   AXRuntime                           0x00000001ca7c60ac _AXGetPortFromCache + 796
	1   AXRuntime                           0x00000001ca7cab70 AXUIElementPerformFencedActionWithValue + 700
	2   UIKit                               0x000000024ea8445c EA3EC8A2-C802-395D-973F-2538FE1A8697 + 1561692
	3   libdispatch.dylib                   0x0000000103474584 _dispatch_call_block_and_release + 32
	4   libdispatch.dylib                   0x000000010348e064 _dispatch_client_callout + 16
	5   libdispatch.dylib                   0x000000010347c91c _dispatch_lane_serial_drain + 796
	6   libdispatch.dylib                   0x000000010347d5a4 _dispatch_lane_invoke + 432
	7   libdispatch.dylib                   0x0000000103489894 _dispatch_root_queue_drain_deferred_wlh + 344
	8   libdispatch.dylib                   0x0000000103488eb0 _dispatch_workloop_worker_thread + 580
	9   libsystem_pthread.dylib             0x000000021d03ca0c _pthread_wqthread + 292
	10  libsystem_pthread.dylib             0x000000021d03caac start_wqthread + 8
)
Type: Error | Timestamp: 2025-08-22 10:41:25.287788+09:00 | Process: BobCamAgent | Library: AXRuntime | Subsystem: com.apple.Accessibility | Category: AXRuntimeCommon | TID: 0xf8fa
AX Lookup problem - errorCode:1100 error:Permission denied portName:'com.apple.iphone.axserver' PID:875 (
	0   AXRuntime                           0x00000001ca7c60ac _AXGetPortFromCache + 796
	1   AXRuntime                           0x00000001ca7cab70 AXUIElementPerformFencedActionWithValue + 700
	2   UIKit                               0x000000024ea8445c EA3EC8A2-C802-395D-973F-2538FE1A8697 + 1561692
	3   libdispatch.dylib                   0x0000000103474584 _dispatch_call_block_and_release + 32
	4   libdispatch.dylib                   0x000000010348e064 _dispatch_client_callout + 16
	5   libdispatch.dylib                   0x000000010347c91c _dispatch_lane_serial_drain + 796
	6   libdispatch.dylib                   0x000000010347d5a4 _dispatch_lane_invoke + 432
	7   libdispatch.dylib                   0x0000000103489894 _dispatch_root_queue_drain_deferred_wlh + 344
	8   libdispatch.dylib                   0x0000000103488eb0 _dispatch_workloop_worker_thread + 580
	9   libsystem_pthread.dylib             0x000000021d03ca0c _pthread_wqthread + 292
	10  libsystem_pthread.dylib             0x000000021d03caac start_wqthread + 8
)
Type: Error | Timestamp: 2025-08-22 10:41:25.288319+09:00 | Process: BobCamAgent | Library: AXRuntime | Subsystem: com.apple.Accessibility | Category: AXRuntimeCommon | TID: 0xf8fa
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Frame dropped
Type: stdio