import SwiftUI

enum SecondaryDestination: Hashable, Identifiable {
    case workoutDetail(WorkoutSummary)
    case planAdjustment
    case postRunSummary
    case audioCues
    case lapMarker
    case voiceCoaching
    case coachingTone
    case goalFocus
    case reminders
    case connectedService(String)

    var id: String {
        switch self {
        case .workoutDetail(let w): "workoutDetail-\(w.id)"
        case .planAdjustment: "planAdjustment"
        case .postRunSummary: "postRunSummary"
        case .audioCues: "audioCues"
        case .lapMarker: "lapMarker"
        case .voiceCoaching: "voiceCoaching"
        case .coachingTone: "coachingTone"
        case .goalFocus: "goalFocus"
        case .reminders: "reminders"
        case .connectedService(let name): "connectedService-\(name)"
        }
    }

    var title: String {
        switch self {
        case .workoutDetail(let w): w.title
        case .planAdjustment: "Plan Adjustment"
        case .postRunSummary: "Post-Run Summary"
        case .audioCues: "Audio Cues"
        case .lapMarker: "Lap Marker"
        case .voiceCoaching: "Voice Coaching"
        case .coachingTone: "Coaching Tone"
        case .goalFocus: "Goal Focus"
        case .reminders: "Reminders"
        case .connectedService(let name): name
        }
    }
}

struct SecondaryFlowView: View {
    var destination: SecondaryDestination

    var body: some View {
        ZStack {
            RunSmartBackground()
            VStack(alignment: .leading, spacing: RunSmartSpacing.md) {
                Text(destination.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "Scaffolded Flow")
                        Text(copy)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.84))
                        Button("Ask Coach About This") {}
                            .buttonStyle(NeonButtonStyle())
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Next integration step")
                            .font(.headline)
                        Text("Connect this surface to the service protocol named in the integration gaps doc, then replace mock data with live API mapping.")
                            .font(.subheadline)
                            .foregroundStyle(Color.mutedText)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private var copy: String {
        switch destination {
        case .workoutDetail:
            "Explain the session purpose, warm-up, target effort, common mistakes, and completion cues."
        case .planAdjustment:
            "Collect feedback, recent run data, and recovery context before proposing a safe reshuffle."
        case .postRunSummary:
            "Summarize distance, pace, effort, notes, and coach follow-up before saving the run."
        case .connectedService:
            "Show connection status, permissions, last sync, reconnect, and disconnect controls."
        default:
            "This native flow is intentionally present as a thin shell so the navigation contract is ready before live integrations land."
        }
    }
}
