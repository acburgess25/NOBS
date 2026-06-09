/// NOBSApp — NotesView
///
/// MVP single-screen Encrypted Notes UI. Demonstrates the full NOBS Apple
/// thesis on TestFlight: type a note, encrypt locally, sync to Appwrite,
/// list past notes, tap to decrypt.
///
/// Wire-up:
///   - On launch, reads/creates the 256-bit master key via SyncedKeychain
///     (iCloud Keychain → syncs across the user's Apple devices).
///   - Builds an EncryptionService from that key.
///   - Hands it to a NoteRepository which orchestrates Appwrite calls.

import CryptoKit
import NOBSCore
import NOBSDatabase
import NOBSSecurity
import SwiftUI

public struct NotesView: View {
    @StateObject private var repo: NoteRepository
    @State private var draft: String = ""
    @State private var revealedNoteID: String?
    @State private var revealedText: String?

    public init() {
        // Master key: read from iCloud Keychain or generate + persist.
        let rawKey: Data
        do {
            rawKey = try SyncedKeychain.masterKey.readOrCreateMasterKey()
        } catch {
            // Last-resort ephemeral key — user will see "decryption failed" on
            // existing notes from other devices until iCloud Keychain catches up.
            rawKey = EncryptionService.generateMasterKey().rawData
        }
        let key = SymmetricKey(rawData: rawKey) ?? EncryptionService.generateMasterKey()
        let crypto = EncryptionService(masterKey: key)
        _repo = StateObject(wrappedValue: NoteRepository(crypto: crypto))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composer
                Divider().opacity(0.4)
                list
            }
            .navigationTitle("NOBS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await repo.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(repo.isSyncing)
                }
            }
            .task { await repo.refresh() }
            .alert("Error", isPresented: .constant(repo.lastError != nil), actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(repo.lastError ?? "")
            })
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New note")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $draft)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Text(privacyHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    Task {
                        let ok = await repo.create(draft)
                        if ok { draft = "" }
                    }
                } label: {
                    Label("Encrypt & sync", systemImage: "lock.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.isEmpty || repo.isSyncing)
            }
        }
        .padding(16)
    }

    private var list: some View {
        List {
            Section {
                if repo.notes.isEmpty && !repo.isSyncing {
                    ContentUnavailableView(
                        "No notes yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Type one above. It's encrypted on this device before it leaves.")
                    )
                }
                ForEach(repo.notes) { note in
                    NoteRow(
                        note: note,
                        revealed: revealedNoteID == note.id ? revealedText : nil,
                        onTap: {
                            Task {
                                if revealedNoteID == note.id {
                                    revealedNoteID = nil
                                    revealedText = nil
                                } else {
                                    let text = await repo.decrypt(note)
                                    revealedNoteID = note.id
                                    revealedText = text
                                }
                            }
                        }
                    )
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await repo.delete(note) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } header: {
                HStack {
                    Text("Synced notes (\(repo.notes.count))")
                    Spacer()
                    if repo.isSyncing {
                        ProgressView().controlSize(.mini)
                    }
                }
            } footer: {
                Text("Notes are encrypted with AES-GCM-256 using a key in your iCloud Keychain. NOBS servers only ever see ciphertext.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var privacyHint: String {
        "🔒 AES-GCM-256 · key in iCloud Keychain"
    }
}

private struct NoteRow: View {
    let note: Note
    let revealed: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: revealed == nil ? "lock.fill" : "lock.open.fill")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    Text(note.createdAt.prefix(16))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(note.size)B")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if let text = revealed {
                    Text(text)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .lineLimit(20)
                } else {
                    Text(String(repeating: "•", count: 24))
                        .font(.body.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotesView()
}
