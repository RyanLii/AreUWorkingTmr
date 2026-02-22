import SwiftUI

struct BodyLoadChartView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let now = Date()

    var body: some View {
        let data = store.bodyLoadSeries(now: now)

        ZStack {
            NightTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Load Curve")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Active std drinks in your body over time")
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
                    Text("Log a drink to see your load curve")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    BodyLoadChartCanvas(
                        series: data.points,
                        drinkTimes: data.entries.map(\.timestamp),
                        snapshot: store.sessionSnapshot,
                        now: now
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 0)

                    Text("0.8 std/hr metabolism · 30 min absorption window · estimates only")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct BodyLoadChartCanvas: View {
    let series: [(date: Date, load: Double)]
    let drinkTimes: [Date]
    let snapshot: SessionSnapshot
    let now: Date

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
                topPad: topPad
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let cp1 = CGPoint(x: (a.x + b.x) / 2, y: a.y)
            let cp2 = CGPoint(x: (a.x + b.x) / 2, y: b.y)
            path.addCurve(to: b, control1: cp1, control2: cp2)
        }
        return path
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

            // Drink ticks
            Canvas { ctx, _ in
                for t in drinkTimes where t >= minDate && t <= maxDate {
                    let tx = xPos(t)
                    var p = Path()
                    p.move(to: CGPoint(x: tx, y: baseline - 10))
                    p.addLine(to: CGPoint(x: tx, y: baseline))
                    ctx.stroke(p, with: .color(NightTheme.accentSoft.opacity(0.65)), lineWidth: 2)
                }
            }

            // "Now" line
            if now > minDate, now < maxDate {
                let nx = xPos(now)
                Path { p in
                    p.move(to: CGPoint(x: nx, y: topPad))
                    p.addLine(to: CGPoint(x: nx, y: baseline))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                Text("now")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: nx, y: topPad - 10)
            }

            // Peak dot
            if snapshot.estimatedPeakStandardDrinks > 0.05 {
                let px = xPos(snapshot.estimatedPeakTime)
                let py = yPos(snapshot.estimatedPeakStandardDrinks)

                Circle()
                    .fill(NightTheme.accentSoft)
                    .frame(width: 7, height: 7)
                    .shadow(color: NightTheme.accentSoft.opacity(0.9), radius: 6)
                    .position(x: px, y: py)

                Text("peak \(DisplayFormatter.standardDrinks(snapshot.estimatedPeakStandardDrinks))")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(NightTheme.accentSoft)
                    .position(x: px, y: py - 14)
            }

            // "Feel human" dashed line + label
            if snapshot.projectedRecoveryTime > minDate, snapshot.projectedRecoveryTime < maxDate {
                let rx = xPos(snapshot.projectedRecoveryTime)
                Path { p in
                    p.move(to: CGPoint(x: rx, y: topPad))
                    p.addLine(to: CGPoint(x: rx, y: baseline))
                }
                .stroke(NightTheme.success.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

                Text("feel human")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(NightTheme.success.opacity(0.85))
                    .position(x: rx, y: topPad - 10)
            }

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
                xPos: xPos
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let cp1 = CGPoint(x: (a.x + b.x) / 2, y: a.y)
            let cp2 = CGPoint(x: (a.x + b.x) / 2, y: b.y)
            path.addCurve(to: b, control1: cp1, control2: cp2)
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

    private func xAxisLabels(
        minDate: Date,
        maxDate: Date,
        totalSeconds: TimeInterval,
        baseline: CGFloat,
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

        return ForEach(Array(labels.enumerated()), id: \.offset) { _, date in
            Text(fmt.string(from: date))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .position(x: xPos(date), y: baseline + xLabelHeight / 2)
        }
    }
}
