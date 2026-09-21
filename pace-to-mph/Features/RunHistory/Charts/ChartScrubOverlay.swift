import Charts
import SwiftUI

/// Drag-to-inspect overlay shared by every trend chart. Each chart supplies how
/// to turn a scrubbed date into a selection and how to clear it, so the plot
/// frame math and gesture wiring live in exactly one place.
struct ChartScrubOverlay: View {
    let proxy: ChartProxy
    let onScrub: (Date) -> Void
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            if let plotFrameAnchor = proxy.plotFrame {
                let plotFrame = geometry[plotFrameAnchor]
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - plotFrame.origin.x
                                guard x >= 0, x <= plotFrame.width,
                                      let date: Date = proxy.value(atX: x) else { return }
                                onScrub(date)
                            }
                            .onEnded { _ in onEnd() }
                    )
            }
        }
    }
}

extension Collection {
    /// Element whose date sits closest to `date` — the shared "snap the scrub to
    /// a real data point" rule behind every trend chart's selection.
    func nearest(to date: Date, by dateKey: (Element) -> Date) -> Element? {
        self.min {
            abs(dateKey($0).timeIntervalSince(date)) < abs(dateKey($1).timeIntervalSince(date))
        }
    }
}
