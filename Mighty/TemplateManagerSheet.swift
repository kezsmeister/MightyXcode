import SwiftUI
import SwiftData

struct TemplateManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let user: User

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TemplateRow(
                        icon: "film",
                        title: "Movies & TV Shows",
                        description: "Track movies and TV shows with OMDB search integration",
                        isEnabled: user.enabledTemplates.contains("movies"),
                        onToggle: { toggleTemplate("movies") }
                    )

                    TemplateRow(
                        icon: "book.fill",
                        title: "Books",
                        description: "Track books with Open Library search integration",
                        isEnabled: user.enabledTemplates.contains("books"),
                        onToggle: { toggleTemplate("books") }
                    )
                } header: {
                    Text("Available Templates")
                } footer: {
                    Text("Templates add specialized tracking with search integration and cover images.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func toggleTemplate(_ template: String) {
        if user.enabledTemplates.contains(template) {
            // Disable template
            user.enabledTemplates.removeAll { $0 == template }
            user.tabOrder.removeAll { $0 == template }
        } else {
            // Enable template
            user.enabledTemplates.append(template)
            user.tabOrder.append(template)
        }
    }
}

struct TemplateRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(isEnabled ? Color.purple : Color(white: 0.2))
                    .foregroundColor(isEnabled ? .white : .gray)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isEnabled ? .purple : .gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
