import SwiftUI

struct LiveRunView: View {
    var metrics: [MetricTile]
    var routePoints: [RunRoutePoint]
    var phase: RunRecordingPhase
    var coachCue: String
    var onCoach: () -> Void
    var onAudio: () -> Void
    var onPauseResume: () -> Void
    var onLap: () -> Void
    var onLock: () -> Void
    var onFinish: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                RunSmartTopBar(title: "Run")

                RunCoachPanel(coachCue: coachCue, onCoach: onCoach)

                RunSmartPanel(cornerRadius: 22, padding: 0, accent: .accentPrimary) {
                    ZStack {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                            ForEach(metrics) { metric in
                                LiveMetricCard(metric: metric, isPrimary: metric.title == "Distance")
                                    .padding(16)
                                    .frame(minHeight: 116)
                            }
                        }
                        Circle()
                            .fill(Color.surfaceElevated)
                            .frame(width: 94, height: 94)
                            .overlay(ProgressRing(value: phase == .paused ? 0.68 : 0.82, lineWidth: 7, icon: "figure.run", tint: .accentPrimary).padding(13))
                            .shadow(color: Color.accentPrimary.opacity(0.34), radius: 20)
                    }
                }

                if routePoints.isEmpty {
                    RunSmartRoutePreview(title: "GPS", showGPS: true, height: 154)
                } else {
                    RunSmartPanel(cornerRadius: 20, padding: 8) {
                        RouteMapView(points: routePoints, title: "GPS")
                            .frame(height: 142)
                    }
                }

                HStack(spacing: 0) {
                    RunSmartPanel(cornerRadius: 18, padding: 12, accent: .accentPrimary) {
                        HStack(spacing: 10) {
                            CoachGlowBadge(size: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(title: "Coach Cue")
                                Text(coachCue)
                                    .font(.bodyMD)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                    }
                    RunSmartPanel(cornerRadius: 18, padding: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(title: "Cadence")
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("172")
                                        .font(.metric)
                                    Text("spm")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                            Spacer()
                            MetricBars(values: [0.35, 0.62, 0.48, 0.78, 0.42, 0.68], tint: .accentPrimary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    LiveInsightTile(title: "Elevation", value: "28", unit: "m", symbol: "mountain.2", tint: .accentPrimary)
                    LiveInsightTile(title: "Zone", value: "4", unit: "Threshold", symbol: "heart", tint: .accentHeart)
                    LiveInsightTile(title: "Pace Trend", value: "-0:03", unit: "/km", symbol: "speedometer", tint: .accentPrimary)
                }

                HStack(spacing: 24) {
                    LiveControlButton(title: "Audio", symbol: "speaker.wave.2.fill", tint: .textSecondary, action: onAudio)
                    LiveControlButton(title: "Lap", symbol: "flag.fill", tint: .textSecondary, action: onLap)
                    LiveControlButton(title: phase == .paused ? "Resume" : "Pause", symbol: phase == .paused ? "play.fill" : "pause.fill", tint: .accentPrimary, prominent: true, action: onPauseResume)
                    LiveControlButton(title: "Finish", symbol: "stop.fill", tint: .accentHeart, action: onFinish)
                }
                .padding(.top, 4)
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .foregroundStyle(Color.textPrimary)
        .background(Color.black.opacity(0.52).ignoresSafeArea())
    }
}

private struct LiveMetricCard: View {
    var metric: MetricTile
    var isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
                Label(metric.title.uppercased(), systemImage: metric.symbol)
                    .font(.labelSM)
                    .tracking(1.1)
                    .foregroundStyle(Color.textSecondary)
                Text(metric.value)
                    .font(isPrimary ? .displayLG : .metric)
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(metric.unit)
                    .font(.labelSM)
                    .foregroundStyle(metric.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LiveInsightTile: View {
    var title: String
    var value: String
    var unit: String
    var symbol: String
    var tint: Color

    var body: some View {
        RunSmartPanel(cornerRadius: 16, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title.uppercased(), systemImage: symbol)
                    .font(.labelSM)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.metric)
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
                RunSmartSparkline(values: [2, 3, 2.5, 5, 4.2, 6, 5.4], tint: tint)
                    .frame(height: 22)
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        }
    }
}

private struct LiveControlButton: View {
    var title: String
    var symbol: String
    var tint: Color
    var prominent = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: prominent ? 24 : 18, weight: .bold))
                    .foregroundStyle(prominent ? Color.black : tint)
                    .frame(width: prominent ? 72 : 56, height: prominent ? 72 : 56)
                    .background(prominent ? tint : Color.surfaceCard)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
    }
}
