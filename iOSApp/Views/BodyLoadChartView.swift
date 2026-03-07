import SwiftUI

struct BodyLoadChartView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let now = Date()

    @State private var peakTapCount = 0
    @State private var showEasterEgg = false
    @State private var screenScale: CGFloat = 1.0

    // Session-only counter — resets every app launch
    private static var sessionEasterEggCount = 0

    private let peakHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        let data = store.bodyLoadSeries(now: now)

        ZStack(alignment: .topLeading) {
            NightTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Trend")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Session trend over time")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                if data.points.isEmpty {
                    Spacer()
                    Text("Log a drink to see your session trend")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    BodyLoadChartCanvas(
                        series: data.points,
                        drinkTimes: data.entries.map(\.timestamp),
                        snapshot: store.sessionSnapshot,
                        now: now,
                        onPeakTap: handlePeakTap
                    )
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text("Trend estimates from your log entries.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scaleEffect(screenScale)

            if showEasterEgg {
                PeakEasterEggOverlay(
                    triggerCount: Self.sessionEasterEggCount,
                    onDismiss: { showEasterEgg = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showEasterEgg)
    }

    private func handlePeakTap() {
        peakHaptic.impactOccurred()

        // Screen pulse: 1.0 → 1.02 → 1.0
        withAnimation(.easeOut(duration: 0.1)) { screenScale = 1.02 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) { screenScale = 1.0 }

        peakTapCount += 1
        if peakTapCount >= 3 {
            peakTapCount = 0
            Self.sessionEasterEggCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showEasterEgg = true
            }
        }
    }
}

private struct BodyLoadChartCanvas: View {
    let series: [(date: Date, load: Double)]
    let drinkTimes: [Date]
    let snapshot: SessionSnapshot
    let now: Date
    let onPeakTap: () -> Void

    private let yLabelWidth: CGFloat = 38
    private let xLabelHeight: CGFloat = 26
    private let topPad: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ChartContent(
                series: series,
                drinkTimes: drinkTimes,
                snapshot: snapshot,
                now: now,
                geo: geo,
                yLabelWidth: yLabelWidth,
                xLabelHeight: xLabelHeight,
                topPad: topPad,
                onPeakTap: onPeakTap
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        catmullRomPath(points: points)
    }
}

// MARK: - Chart content helper (keeps func/guard/return out of @ViewBuilder)

private struct ChartContent: View {
    let series: [(date: Date, load: Double)]
    let drinkTimes: [Date]
    let snapshot: SessionSnapshot
    let now: Date
    let geo: GeometryProxy
    let yLabelWidth: CGFloat
    let xLabelHeight: CGFloat
    let topPad: CGFloat
    let onPeakTap: () -> Void

    // Derived geometry
    private var chartW: CGFloat { geo.size.width - yLabelWidth }
    private var chartH: CGFloat { geo.size.height - xLabelHeight - topPad }

    private var minDate: Date { series.first!.date }
    private var maxDate: Date { series.last!.date }
    private var totalSeconds: TimeInterval { maxDate.timeIntervalSince(minDate) }
    private var maxLoad: Double {
        let rawMax = series.map(\.load).max() ?? 1.0
        return max(rawMax, 0.5) * 1.18
    }

    private func xPos(_ date: Date) -> CGFloat {
        guard totalSeconds > 0 else { return yLabelWidth }
        return yLabelWidth + CGFloat(date.timeIntervalSince(minDate) / totalSeconds) * chartW
    }

    private func yPos(_ load: Double) -> CGFloat {
        topPad + chartH * (1 - CGFloat(min(load / maxLoad, 1.0)))
    }

    private var baseline: CGFloat { yPos(0) }
    private var cgPoints: [CGPoint] { series.map { CGPoint(x: xPos($0.date), y: yPos($0.load)) } }
    private var nowMarkerX: CGFloat? {
        guard now > minDate, now < maxDate else { return nil }
        return xPos(now)
    }
    private var peakMarker: (x: CGFloat, y: CGFloat)? {
        guard snapshot.estimatedPeakStandardDrinks > 0.05 else { return nil }
        return (xPos(snapshot.estimatedPeakTime), yPos(snapshot.estimatedPeakStandardDrinks))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Grid lines
            Canvas { ctx, size in
                for i in 0...4 {
                    let load = maxLoad * Double(4 - i) / 4.0
                    let yy = topPad + chartH * (1 - CGFloat(min(load / maxLoad, 1.0)))
                    var p = Path()
                    p.move(to: CGPoint(x: yLabelWidth, y: yy))
                    p.addLine(to: CGPoint(x: size.width, y: yy))
                    ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1)
                }
            }

            // Area fill
            areaPath(points: cgPoints, baseline: baseline)
                .fill(
                    LinearGradient(
                        colors: [NightTheme.accentSoft.opacity(0.38), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Glow
            linePath(points: cgPoints)
                .stroke(NightTheme.accentSoft.opacity(0.4), lineWidth: 7)
                .blur(radius: 6)

            // Line
            linePath(points: cgPoints)
                .stroke(NightTheme.accentSoft, lineWidth: 2)

            // "Now" line
            if let nx = nowMarkerX {
                Path { p in
                    p.move(to: CGPoint(x: nx, y: topPad))
                    p.addLine(to: CGPoint(x: nx, y: baseline))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                Text("now")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(nowLabelPosition(for: nx))
            }

            // High-point dot
            if let peak = peakMarker {
                let px = peak.x
                let py = peak.y

                Circle()
                    .fill(NightTheme.accentSoft)
                    .frame(width: 7, height: 7)
                    .shadow(color: NightTheme.accentSoft.opacity(0.9), radius: 6)
                    .position(x: px, y: py)

                Text("peak logged")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(NightTheme.accentSoft)
                    .position(highPointLabelPosition(for: peak))

                // Invisible tap target (44pt for easy tapping)
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { onPeakTap() }
                    .position(x: px, y: py)
            }

            // REVIEW_SAFE_MODE: previous timed markers kept for future internal builds.
            // Text("peak \(DisplayFormatter.standardDrinks(snapshot.estimatedPeakStandardDrinks))")
            // if snapshot.projectedRecoveryTime > minDate, snapshot.projectedRecoveryTime < maxDate {
            //     let rx = xPos(snapshot.projectedRecoveryTime)
            //     Path { p in
            //         p.move(to: CGPoint(x: rx, y: topPad))
            //         p.addLine(to: CGPoint(x: rx, y: baseline))
            //     }
            //     .stroke(NightTheme.success.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            // }

            // Y labels
            ForEach(0...4, id: \.self) { i in
                let load = maxLoad * Double(4 - i) / 4.0
                let yy = topPad + chartH * (1 - CGFloat(min(load / maxLoad, 1.0)))
                Text(String(format: "%.1f", load))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: yLabelWidth - 4, alignment: .trailing)
                    .position(x: (yLabelWidth - 4) / 2, y: yy)
            }

            // Y axis unit
            Text("std drinks")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .rotationEffect(.degrees(-90))
                .position(x: 10, y: topPad + chartH / 2)

            // X labels
            xAxisLabels(
                minDate: minDate,
                maxDate: maxDate,
                totalSeconds: totalSeconds,
                baseline: baseline,
                chartWidth: chartW,
                xPos: xPos
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        catmullRomPath(points: points)
    }

    private func areaPath(points: [CGPoint], baseline: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        // Start on the baseline so closeSubpath closes horizontally along the baseline
        // instead of drawing a visible vertical edge back to the first data point.
        path.move(to: CGPoint(x: first.x, y: baseline))
        path.addLine(to: first)

        if points.count > 1 {
            let n = points.count
            for i in 1..<n {
                let p0 = points[max(i - 2, 0)]
                let p1 = points[i - 1]
                let p2 = points[i]
                let p3 = points[min(i + 1, n - 1)]
                if i == 1 || i == n - 1 {
                    // Avoid endpoint overshoot hooks on sharp ramps.
                    path.addLine(to: p2)
                    continue
                }

                let xMin = min(p1.x, p2.x)
                let xMax = max(p1.x, p2.x)
                let yMin = min(p1.y, p2.y)
                let yMax = max(p1.y, p2.y)
                let rawCP1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                     y: p1.y + (p2.y - p0.y) / 6)
                let rawCP2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                     y: p2.y - (p3.y - p1.y) / 6)
                let cp1 = CGPoint(x: min(max(rawCP1.x, xMin), xMax),
                                  y: min(max(rawCP1.y, yMin), yMax))
                let cp2 = CGPoint(x: min(max(rawCP2.x, xMin), xMax),
                                  y: min(max(rawCP2.y, yMin), yMax))
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }

        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.closeSubpath()
        return path
    }

    private func xAxisLabels(
        minDate: Date,
        maxDate: Date,
        totalSeconds: TimeInterval,
        baseline: CGFloat,
        chartWidth: CGFloat,
        xPos: @escaping (Date) -> CGFloat
    ) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let hourStep: TimeInterval = totalSeconds > 6 * 3600 ? 2 * 3600 : 3600
        let cal = Calendar.current

        var labels: [Date] = []
        if let rounded = cal.date(bySetting: .minute, value: 0, of: minDate),
           var t = cal.date(byAdding: .hour, value: 1, to: rounded) {
            while t <= maxDate {
                if t > minDate { labels.append(t) }
                t = t.addingTimeInterval(hourStep)
            }
        }

        // Keep time labels readable across device widths and long sessions.
        let maxVisible = max(2, Int(chartWidth / 48))
        let strideValue = max(1, Int(ceil(Double(max(labels.count, 1)) / Double(maxVisible))))
        var visible = labels.enumerated().compactMap { index, date in
            index % strideValue == 0 ? date : nil
        }
        // Only force-append last label if it won't crowd the previous visible label.
        if let last = labels.last, visible.last != last,
           let prevVisible = visible.last {
            let gap = xPos(last) - xPos(prevVisible)
            if gap >= 44 {
                visible.append(last)
            }
        }

        return ForEach(Array(visible.enumerated()), id: \.offset) { _, date in
            Text(fmt.string(from: date))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .position(x: xPos(date), y: baseline + xLabelHeight / 2)
        }
    }

    private func nowLabelPosition(for x: CGFloat) -> CGPoint {
        CGPoint(x: clampedLabelX(x), y: topPad + 10)
    }

    private func highPointLabelPosition(for peak: (x: CGFloat, y: CGFloat)) -> CGPoint {
        let clampedPeakX = clampedLabelX(peak.x)
        var labelY = max(topPad + 10, peak.y - 14)

        if let nx = nowMarkerX {
            let nowPos = nowLabelPosition(for: nx)
            // Use generous thresholds: "high point" text ≈ 50pt wide, "now" ≈ 18pt wide.
            // Extra headroom accounts for font-metric differences across OS versions.
            if abs(nowPos.x - clampedPeakX) < 80, abs(nowPos.y - labelY) < 22 {
                labelY = min(baseline - 20, peak.y + 18)
            }
        }

        return CGPoint(x: clampedPeakX, y: labelY)
    }

    private func clampedLabelX(_ x: CGFloat) -> CGFloat {
        let minX = yLabelWidth + 18
        let maxX = max(minX, yLabelWidth + chartW - 18)
        return min(max(x, minX), maxX)
    }
}

// MARK: - Catmull-Rom spline

/// Converts a polyline into a smooth Catmull-Rom cubic Bézier path.
/// Control points are derived from neighboring points so tangents are
/// continuous at every data point — no kinks.
private func catmullRomPath(points: [CGPoint]) -> Path {
    var path = Path()
    guard points.count > 1 else { return path }
    path.move(to: points[0])
    let n = points.count
    for i in 1..<n {
        let p0 = points[max(i - 2, 0)]
        let p1 = points[i - 1]
        let p2 = points[i]
        let p3 = points[min(i + 1, n - 1)]
        if i == 1 || i == n - 1 {
            // Avoid endpoint overshoot hooks on sharp ramps.
            path.addLine(to: p2)
            continue
        }

        let xMin = min(p1.x, p2.x)
        let xMax = max(p1.x, p2.x)
        let yMin = min(p1.y, p2.y)
        let yMax = max(p1.y, p2.y)
        let rawCP1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                             y: p1.y + (p2.y - p0.y) / 6)
        let rawCP2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                             y: p2.y - (p3.y - p1.y) / 6)
        // Clamp control points to the segment bounds to prevent loops/overshoot.
        let cp1 = CGPoint(x: min(max(rawCP1.x, xMin), xMax),
                          y: min(max(rawCP1.y, yMin), yMax))
        let cp2 = CGPoint(x: min(max(rawCP2.x, xMin), xMax),
                          y: min(max(rawCP2.y, yMin), yMax))
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
    return path
}
