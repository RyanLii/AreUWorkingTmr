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
                                    Text("Body load curve")
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.label)
                                    PreviousSessionMiniChart(
                                        points: summary.bodyLoadPoints,
                                        drinkTimes: summary.drinkTimestamps,
                                        peakStandardDrinks: summary.peakStandardDrinks,
                                        peakTime: summary.peakTime,
                                        recoveryTime: summary.projectedRecoveryTime
                                    )
                                    .frame(height: 158)
                                    Text("0.8 std/hr metabolism · estimates only")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.35))
                                }
                                .glassCard()
                            }

                            // Stats rows
                            VStack(alignment: .leading, spacing: 10) {
                                summaryRow(
                                    "Peak load",
                                    DisplayFormatter.standardDrinks(summary.peakStandardDrinks)
                                        + " at " + DisplayFormatter.eta(summary.peakTime)
                                )
                                summaryRow("Projected clear", DisplayFormatter.eta(summary.projectedZeroTime))
                                summaryRow("Low load threshold", DisplayFormatter.eta(summary.projectedRecoveryTime))
                                summaryRow("Hydration goal", "\(summary.hydrationPlanMl) ml")
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
    let drinkTimes: [Date]
    let peakStandardDrinks: Double
    let peakTime: Date
    let recoveryTime: Date

    var body: some View {
        GeometryReader { geo in
            MiniChartContent(
                points: points,
                drinkTimes: drinkTimes,
                peakStandardDrinks: peakStandardDrinks,
                peakTime: peakTime,
                recoveryTime: recoveryTime,
                size: geo.size
            )
        }
    }
}

private struct MiniChartContent: View {
    let points: [(date: Date, load: Double)]
    let drinkTimes: [Date]
    let peakStandardDrinks: Double
    let peakTime: Date
    let recoveryTime: Date
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

            // Drink tick marks
            Canvas { ctx, _ in
                for t in drinkTimes where t >= minDate && t <= maxDate {
                    let tx = xPos(t)
                    var p = Path()
                    p.move(to: CGPoint(x: tx, y: baseline - 8))
                    p.addLine(to: CGPoint(x: tx, y: baseline))
                    ctx.stroke(p, with: .color(NightTheme.accentSoft.opacity(0.55)), lineWidth: 2)
                }
            }

            // Low load dashed line
            if recoveryTime > minDate && recoveryTime < maxDate {
                let rx = xPos(recoveryTime)
                Path { p in
                    p.move(to: CGPoint(x: rx, y: topPad))
                    p.addLine(to: CGPoint(x: rx, y: baseline))
                }
                .stroke(NightTheme.success.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

                Text("Low load threshold")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(NightTheme.success.opacity(0.8))
                    .position(x: xPos(recoveryTime), y: topPad - 10)
            }

            // Peak dot + label
            if peakStandardDrinks > 0.05 {
                let px = xPos(peakTime)
                let py = yPos(peakStandardDrinks)

                Circle()
                    .fill(NightTheme.accentSoft)
                    .frame(width: 7, height: 7)
                    .shadow(color: NightTheme.accentSoft.opacity(0.9), radius: 5)
                    .position(x: px, y: py)

                Text("peak \(DisplayFormatter.standardDrinks(peakStandardDrinks))")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(NightTheme.accentSoft)
                    .position(x: px, y: py - 12)
            }

            // X-axis time labels
            ForEach(Array(xLabelDates.enumerated()), id: \.offset) { _, date in
                Text(timeFmt.string(from: date))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .position(x: xPos(date), y: baseline + botPad / 2)
            }
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            path.addCurve(
                to: b,
                control1: CGPoint(x: (a.x + b.x) / 2, y: a.y),
                control2: CGPoint(x: (a.x + b.x) / 2, y: b.y)
            )
        }
        return path
    }

    private func areaPath(points: [CGPoint], baseline: CGFloat) -> Path {
        var path = linePath(points: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.addLine(to: CGPoint(x: first.x, y: baseline))
        path.closeSubpath()
        return path
    }
}
