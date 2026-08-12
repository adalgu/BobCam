import SwiftUI

struct TouchBlockingView<Content: View>: View {
    let content: Content
    let allowedZones: [CGRect]

    init(allowedZones: [CGRect] = [], @ViewBuilder content: () -> Content) {
        self.allowedZones = allowedZones
        self.content = content()
    }

    var body: some View {
        GeometryReader { _ in
            content
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let isAllowed = allowedZones.contains { zone in
                                zone.contains(value.location)
                            }

                            if !isAllowed {
                                print("Touch blocked at: \(value.location)")
                            }
                        }
                )
        }
    }
}

extension View {
    func blockChildTouches(exceptIn zones: [CGRect] = []) -> some View {
        TouchBlockingView(allowedZones: zones) {
            self
        }
    }
}

struct ControlBarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
