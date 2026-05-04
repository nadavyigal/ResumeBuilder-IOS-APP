import SwiftUI

struct PreRunView: View {
    var metrics: [MetricTile]
    var plannedWorkout: WorkoutSummary?
    var onStart: () -> Void
    var onCoach: () -> Void
    var onRoute: () -> Void
    var onAudio: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                RunSmartTopBar(title: "Run")

                RunCoachPanel(coachCue: preRunCue, onCoach: onCoach)

                HStack(spacing: 10) {
                    RunOptionButton(title: "Route", symbol: "map.fill", tint: .accentRecovery, action: onRoute)
                    RunOptionButton(title: "Audio", symbol: "speaker.wave.2.fill", tint: .accentPrimary, action: onAudio)
                }

                RunSmartPanel(cornerRadius: 22, padding: 16, accent: .accentPrimary) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "Ready to run")
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plannedWorkout?.title ?? "Free Run")
                                    .font(.headingLG)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                Text(workoutDetail)
                                    .font(.metricSM)
                                    .foregroundStyle(Color.accentPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                            Spacer()
                            Button(action: onStart) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 30, weight: .black))
                                    .foregroundStyle(Color.black)
                                    .frame(width: 86, height: 86)
                                    .background(Color.accentPrimary, in: Circle())
                                    .shadow(color: Color.accentPrimary.opacity(0.48), radius: 24)
                                    .runSmartPulse(scale: 1.035)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: onRoute) {
                            RunSmartRoutePreview(title: "Select route", showGPS: true, height: 148)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !metrics.isEmpty {
                    RunSmartPanel(cornerRadius: 22, padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Last run")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                                ForEach(metrics.prefix(4)) { metric in
                                    MetricTileView(metric: metric)
                                        .padding(12)
                                }
                            }
                        }
                    }
                }

                WeatherConditionsCard()
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }

    private var workoutDetail: String {
        guard let workout = plannedWorkout else { return "GPS tracking - pace - route" }
        var parts = [workout.distance]
        if let pace = StructuredWorkoutFactory.derivedPaceLabel(workout: workout) {
            parts.append(pace)
        }
        if !workout.detail.isEmpty {
            parts.append(workout.detail)
        }
        return parts.joined(separator: " - ")
    }

    private var preRunCue: String {
        if let plannedWorkout {
            return "Ease into \(plannedWorkout.title.lowercased()). Keep the first minutes smooth and let the coach adjust from there."
        }
        return "Start a GPS run when you are ready. Coach will track route, pace, and effort."
    }
}

private struct RunOptionButton: View {
    var title: String
    var symbol: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RunSmartPanel(cornerRadius: 18, padding: 14) {
                HStack {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.bodyMD.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RunCoachPanel: View {
    var coachCue: String
    var onCoach: () -> Void

    var body: some View {
        RunSmartPanel(cornerRadius: 22, padding: 16, accent: .accentPrimary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    CoachGlowBadge(symbol: "waveform", size: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(title: "Live Coach")
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.accentPrimary)
                                .frame(width: 8, height: 8)
                            Text("Coach is listening")
                                .font(.bodyMD)
                                .foregroundStyle(Color.textPrimary)
                        }
                        MetricBars(values: [0.18, 0.36, 0.62, 0.28, 0.72, 0.48, 0.58, 0.34, 0.44], tint: .accentPrimary)
                    }
                    Spacer()
                    Button(action: onCoach) {
                        Label("Tap to talk", systemImage: "mic.fill")
                            .font(.bodyMD.weight(.semibold))
                            .foregroundStyle(Color.accentPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(Color.surfaceCard.opacity(0.82), in: Capsule())
                            .overlay(Capsule().stroke(Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Text(coachCue)
                    .font(.bodyLG)
                    .foregroundStyle(Color.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentPrimary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.accentPrimary.opacity(0.28), lineWidth: 1))
            }
        }
    }
}
