/// NOBSDatabase — NoteRepository
///
/// The MVP's only feature: write a text note, encrypt locally, sync ciphertext
/// to Appwrite, list past notes, decrypt on tap. This file is the orchestration
/// layer between SwiftUI views and the crypto + remote-storage primitives.
///
/// Wire-up dependencies (passed in via init for testability):
///   - AppwriteClient   (NOBSCore)
///   - EncryptionService (NOBSSecurity)
///
/// Bucket: `e2ee-blobs` (provisioned on Appwrite project 6a1585e80002d494c9b2).
/// Server sees: opaque file IDs, byte size, mtime. Nothing else.

import CryptoKit
import Foundation
import NOBSCore
import NOBSSecurity

public struct Note: Identifiable, Hashable, Sendable {
    public let id: String          // Appwrite file ID = our opaque ID
    public let createdAt: String
    public let size: Int
    public let plaintext: String?  // populated only after decrypt
}

@MainActor
public final class NoteRepository: ObservableObject {
    @Published public private(set) var notes: [Note] = []
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastError: String?

    private let appwrite: AppwriteClient
    private let crypto: EncryptionService
    private let bucketId: String

    public init(
        appwrite: AppwriteClient = AppwriteClient(),
        crypto: EncryptionService,
        bucketId: String = "e2ee-blobs"
    ) {
        self.appwrite = appwrite
        self.crypto = crypto
        self.bucketId = bucketId
    }

    public func refresh() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await appwrite.ensureSession()
            let files = try await appwrite.listFiles(bucketId: bucketId)
            // Sort newest first.
            let sorted = files.sorted { $0.createdAt > $1.createdAt }
            notes = sorted.map { Note(id: $0.id, createdAt: $0.createdAt, size: $0.size, plaintext: nil) }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Encrypt the given text and sync. On success the notes list is refreshed.
    @discardableResult
    public func create(_ text: String) async -> Bool {
        guard !text.isEmpty else { return false }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await appwrite.ensureSession()
            let envelope = try crypto.encrypt(Data(text.utf8))
            let id = "note_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(28)
            _ = try await appwrite.uploadFile(
                bucketId: bucketId,
                fileId: String(id),
                name: "note.bin",
                data: envelope
            )
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Download + decrypt a single note.
    public func decrypt(_ note: Note) async -> String? {
        do {
            try await appwrite.ensureSession()
            let cipher = try await appwrite.downloadFile(bucketId: bucketId, fileId: note.id)
            let plain = try crypto.decrypt(cipher)
            return String(data: plain, encoding: .utf8)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    public func delete(_ note: Note) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await appwrite.ensureSession()
            try await appwrite.deleteFile(bucketId: bucketId, fileId: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
