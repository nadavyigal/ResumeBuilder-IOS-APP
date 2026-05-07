import SwiftUI

struct ResumePreviewCard: View {
    let snapshot: ResumeSnapshot
    var template: DesignTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.title)
                        .font(.title3.bold())
                    Text(snapshot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let matchScore = snapshot.matchScore {
                    VStack {
                        Text("\(matchScore)")
                            .font(.title2.bold())
                        Text("ATS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let template {
                Label(template.name, systemImage: "paintpalette")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if snapshot.sections.isEmpty {
                Text("Optimized resume preview will appear after applying the review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                        ForEach(section.lines.prefix(6), id: \.self) { line in
                            Text("• \(line)")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
