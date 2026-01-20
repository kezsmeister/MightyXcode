import SwiftUI
import UIKit

struct FamilySharingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var members: [FamilyMember] = []
    @State private var invitations: [FamilyInvitation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showInviteSheet = false
    @State private var showRemoveConfirmation = false
    @State private var memberToRemove: FamilyMember?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await loadData() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    List {
                        // Family Members Section
                        Section {
                            ForEach(members) { member in
                                FamilyMemberRow(
                                    member: member,
                                    canRemove: !(member.isOwner ?? false) && members.count > 1,
                                    onRemove: {
                                        memberToRemove = member
                                        showRemoveConfirmation = true
                                    }
                                )
                            }
                        } header: {
                            Text("Family Members")
                        } footer: {
                            Text("Admins can view and edit all data. Viewers can only view.")
                        }

                        // Pending Invitations Section
                        if !invitations.isEmpty {
                            Section("Pending Invitations") {
                                ForEach(invitations) { invitation in
                                    InvitationRow(
                                        invitation: invitation,
                                        onRevoke: { revokeInvitation(invitation) }
                                    )
                                }
                            }
                        }

                        // Invite Button Section
                        Section {
                            Button {
                                showInviteSheet = true
                            } label: {
                                Label("Invite Family Member", systemImage: "person.badge.plus")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Family Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                InviteMemberSheet(onInviteSent: {
                    Task { await loadData() }
                })
            }
            .confirmationDialog(
                "Remove Member",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let member = memberToRemove {
                        removeMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let member = memberToRemove {
                    Text("Remove \(member.email) from your family? They will no longer be able to view your activities.")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let membersResponse = FamilySharingService.shared.getMembers()
            async let invitationsResponse = FamilySharingService.shared.getPendingInvitations()

            let (membersResult, invitationsResult) = try await (membersResponse, invitationsResponse)

            await MainActor.run {
                members = membersResult.members
                invitations = invitationsResult.invitations
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func revokeInvitation(_ invitation: FamilyInvitation) {
        Task {
            do {
                try await FamilySharingService.shared.revokeInvitation(invitationId: invitation.id)
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeMember(_ member: FamilyMember) {
        Task {
            do {
                try await FamilySharingService.shared.removeMember(memberId: member.id)
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Family Member Row

struct FamilyMemberRow: View {
    let member: FamilyMember
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(member.isOwner == true ? Color.purple : Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: member.familyRole.icon)
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.email)
                        .font(.body)

                    if member.isOwner == true {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 4) {
                    Text(member.familyRole.displayName)
                        .font(.caption)
                        .foregroundColor(member.familyRole == .admin ? .purple : .orange)
                }
            }

            Spacer()

            if canRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invitation Row

struct InvitationRow: View {
    let invitation: FamilyInvitation
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "envelope")
                        .foregroundColor(.orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.email)
                    .font(.body)

                Text("Pending \(invitation.familyRole.displayName)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            Button(role: .destructive) {
                onRevoke()
            } label: {
                Text("Revoke")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invite Member Sheet

struct InviteMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shareLink: String?
    @State private var showShareSheet = false

    let onInviteSent: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)

                // Title
                Text("Invite Family Member")
                    .font(.title2)
                    .fontWeight(.bold)

                // Description
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                            .foregroundColor(.orange)
                        Text("Viewer Access")
                            .fontWeight(.medium)
                    }
                    Text("They can see all activities but cannot make changes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                // Action area
                if let link = shareLink {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("Invite Link Created!")
                            .font(.headline)

                        Button {
                            showShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Invite Link")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .padding()
                } else {
                    Button {
                        createInvite()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "link.badge.plus")
                            }
                            Text("Create Invite Link")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isLoading)
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(shareLink != nil ? "Done" : "Cancel") {
                        if shareLink != nil {
                            onInviteSent()
                        }
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let link = shareLink {
                    ShareSheet(items: [
                        "Join my family on Mighty to view our kids' activities! \(link)"
                    ])
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func createInvite() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Use a placeholder email - the link works for anyone
                let response = try await FamilySharingService.shared.sendInvitation(email: "invite@mighty-app.com")
                await MainActor.run {
                    isLoading = false
                    shareLink = response.shareLink
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FamilySharingView()
}
