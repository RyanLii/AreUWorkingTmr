import SwiftUI

struct SessionSummaryCard: View {
    let summary: PreviousSessionSummary
    let onDismiss: () -> Void

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: summary.sessionDate)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let hInset = max(16, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 8)
                let topInset = max(16, proxy.safeAreaInsets.top + 10)
                let botInset = max(24, proxy.safeAreaInsets.bottom + 16)

                ZStack(alignment: .topLeading) {
                    NightBackdrop()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Headline
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last night")
                                    .font(NightTheme.titleFont)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text(dateLabel)
                                    .font(NightTheme.subtitleFont)
                                    .foregroundStyle(NightTheme.accentSoft)
                            }

                            // Total drinks big stat
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(DisplayFormatter.standardDrinks(summary.totalStandardDrinks))
                                        .font(NightTheme.statFont)
                                        .foregroundStyle(.white)
                                    Text("\(summary.drinkCount) drink\(summary.drinkCount == 1 ? "" : "s")")
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(NightTheme.label)
                                }
                                Text("standard drinks logged")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(.high)

                            // Body load curve
                            if !summary.bodyLoadPoints.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Session trend")
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.label)
                                    PreviousSessionMiniChart(
                                        points: summary.bodyLoadPoints
                                    )
                                    .frame(height: 158)
                                    Text("Trend estimates from your log entries.")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.35))
                                }
                                .glassCard()
                            }

                            // Stats rows
                            VStack(alignment: .leading, spacing: 10) {
                                summaryRow("Highest trend point", DisplayFormatter.standardDrinks(summary.peakStandardDrinks))
                                summaryRow("Session load", DisplayFormatter.standardDrinks(summary.totalStandardDrinks))
                                summaryRow("Hydration goal", "\(summary.hydrationPlanMl) ml")
                                // REVIEW_SAFE_MODE: previous timed summary rows kept for future internal builds.
                                // summaryRow("Peak load", DisplayFormatter.standardDrinks(summary.peakStandardDrinks) + " at " + DisplayFormatter.eta(summary.peakTime))
                                // summaryRow("Settling window", DisplayFormatter.eta(summary.projectedZeroTime))
                                // summaryRow("Low load threshold", DisplayFormatter.eta(summary.projectedRecoveryTime))
                                Text("Hydration goal is an estimate and not medical advice.")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundStyle(NightTheme.label.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .glassCard()

                            Button(action: onDismiss) {
                                Text("Got it")
                                    .font(NightTheme.bodyFont.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(NightTheme.accent)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, hInset)
                        .padding(.top, topInset)
                        .padding(.bottom, botInset)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { onDismiss() }
                        .font(NightTheme.captionFont.weight(.bold))
                        .foregroundStyle(NightTheme.accent)
                }
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.label)
            Spacer(minLength: 8)
            Text(value)
                .font(NightTheme.captionFont.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Mini chart

private struct PreviousSessionMiniChart: View {
    let points: [(date: Date, load: Double)]

    var body: some View {
        GeometryReader { geo in
            MiniChartContent(
                points: points,
                size: geo.size
            )
        }
    }
}

private struct MiniChartContent: View {
    let points: [(date: Date, load: Double)]
    let size: CGSize

    private let topPad: CGFloat = 20
    private let botPad: CGFloat = 22

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var chartH: CGFloat { h - topPad - botPad }
    private var minDate: Date { points.first!.date }
    private var maxDate: Date { points.last!.date }
    private var totalSeconds: TimeInterval { maxDate.timeIntervalSince(minDate) }
    private var maxLoad: Double { max((points.map(\.load).max() ?? 1.0), 0.5) * 1.18 }

    private func xPos(_ date: Date) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(minDate) / totalSeconds) * w
    }

    private func yPos(_ load: Double) -> CGFloat {
        topPad + chartH * (1 - CGFloat(min(load / maxLoad, 1.0)))
    }

    private var baseline: CGFloat { yPos(0) }

    private var cgPoints: [CGPoint] {
        points.map { CGPoint(x: xPos($0.date), y: yPos($0.load)) }
    }

    private var xLabelDates: [Date] {
        let hourStep: TimeInterval = totalSeconds > 6 * 3600 ? 2 * 3600 : 3600
        let cal = Calendar.current
        var labels: [Date] = []
        guard let rounded = cal.date(bySetting: .minute, value: 0, of: minDate),
              var t = cal.date(byAdding: .hour, value: 1, to: rounded) else { return [] }
        while t <= maxDate {
            if t > minDate { labels.append(t) }
            t = t.addingTimeInterval(hourStep)
        }
        return labels
    }

    // Stride-filtered labels that fit the mini chart width without crowding.
    private var visibleXLabelDates: [Date] {
        let dates = xLabelDates
        guard !dates.isEmpty else { return [] }
        let maxVisible = max(2, Int(w / 44))
        let stride = max(1, Int(ceil(Double(dates.count) / Double(maxVisible))))
        return dates.enumerated().compactMap { i, d in i % stride == 0 ? d : nil }
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Area fill
            areaPath(points: cgPoints, baseline: baseline)
                .fill(LinearGradient(
                    colors: [NightTheme.accentSoft.opacity(0.32), .clear],
                    startPoint: .top, endPoint: .bottom
                ))

            // Glow
            linePath(points: cgPoints)
                .stroke(NightTheme.accentSoft.opacity(0.38), lineWidth: 6)
                .blur(radius: 5)

            // Line
            linePath(points: cgPoints)
                .stroke(NightTheme.accentSoft, lineWidth: 2)

            // X-axis time labels
            ForEach(Array(visibleXLabelDates.enumerated()), id: \.offset) { _, date in
                Text(timeFmt.string(from: date))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .position(x: xPos(date), y: baseline + botPad / 2)
            }
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        catmullRomPath(points: points)
    }

    private func areaPath(points: [CGPoint], baseline: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        // Start on the baseline so the fill closes along the baseline, not vertically.
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
}

// MARK: - Catmull-Rom spline

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
