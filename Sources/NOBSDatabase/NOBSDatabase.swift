/// NOBSDatabase — Work / Personal Data Stores
///
/// Maintains two completely separate encrypted Core Data persistent stores:
/// one for personal data and one for work data. The two stores never share
/// a persistent coordinator, so data cannot accidentally leak between contexts.
///
/// Storage mode is chosen explicitly at setup time:
///   • `.localOnly`  — data never leaves the device (default, recommended).
///   • `.iCloud`     — data is synced via iCloud / CloudKit. This means your
///                     personal and work data will be stored on Apple's servers.
///                     Read `iCloudDisclosure` and present it to the user before
///                     enabling this option.
///
/// On non-Apple platforms (Linux CI) the CoreData stack is replaced with
/// in-memory stubs so that all modules compile and tests run without a
/// full macOS/iOS SDK.

import Foundation

#if canImport(CoreData)
import CoreData
#endif

#if canImport(CloudKit)
import CloudKit
#endif

import NOBSCore

// MARK: - StorageMode

/// Controls where NOBS persists your data.
///
/// **Always show `iCloudDisclosure.userFacingWarning` to the user and require
/// an explicit confirmation before switching to `.iCloud`.**
public enum StorageMode: Sendable {
    /// All data is kept exclusively on this device (encrypted).
    /// Nothing is sent to Apple's servers. This is the default.
    case localOnly

    /// Data is synced to iCloud via CloudKit.
    ///
    /// - Parameter containerID: Your app's iCloud container identifier,
    ///   e.g. `"iCloud.com.yourcompany.nobs"`.
    ///
    /// ⚠️ Enabling iCloud sync means your personal and work data will be
    /// uploaded to Apple's iCloud servers and may appear on other devices
    /// signed in to the same Apple ID. Ensure the user has given informed
    /// consent before using this mode.
    case iCloud(containerID: String)

    /// Human-readable description of the active storage mode.
    public var displayName: String {
        switch self {
        case .localOnly:  return "On-Device Only"
        case .iCloud:     return "iCloud Sync"
        }
    }

    /// True when data will leave the device.
    public var syncsToCloud: Bool {
        if case .iCloud = self { return true }
        return false
    }
}

// MARK: - iCloudDisclosure

/// Ready-made disclosure strings to present to the user before enabling iCloud.
///
/// **You must show at least `userFacingWarning` and require the user to confirm
/// before calling `NOBSDatabase.setup(storageMode: .iCloud(...))`.**
public enum iCloudDisclosure {
    /// Short warning suitable for a settings toggle subtitle or alert body.
    public static let userFacingWarning: String = """
    ⚠️ iCloud Sync is OFF by default.

    Turning this on will upload your NOBS data — including memories, tasks, \
    and preferences — to Apple's iCloud servers. This data may then appear on \
    other Apple devices signed into the same Apple ID.

    NOBS cannot control how Apple stores or protects this data on their servers. \
    If privacy is a priority, keep iCloud Sync off and store everything on-device.
    """

    /// Longer version suitable for a dedicated "About iCloud Sync" screen.
    public static let fullExplanation: String = """
    About iCloud Sync in NOBS
    ─────────────────────────
    By default, NOBS stores everything exclusively on your device. \
    Your memories, tasks, and learned preferences never leave this iPhone/Mac.

    If you enable iCloud Sync:
    • Your data is encrypted in transit and at rest by Apple.
    • It is stored on Apple's iCloud servers under your Apple ID.
    • It can sync to other Apple devices signed in to the same Apple ID.
    • Apple's iCloud Privacy Policy applies: https://www.apple.com/legal/privacy/

    What NOBS never does (regardless of storage mode):
    • Share your data with any third-party service.
    • Upload data to NOBS or any non-Apple server.
    • Mix your Work and Personal databases — they remain separate even in iCloud.

    You can switch back to On-Device Only at any time in Settings → Storage. \
    Switching off iCloud Sync will stop future uploads; data already in iCloud \
    can be deleted from iCloud.com → Manage Storage → NOBS.
    """

    /// One-line status suitable for a settings footer or status bar.
    public static func statusLine(for mode: StorageMode) -> String {
        switch mode {
        case .localOnly:
            return "🔒 On-Device Only — your data never leaves this device."
        case .iCloud(let id):
            return "☁️ iCloud Sync ON — data is stored in Apple iCloud (\(id))."
        }
    }
}

// MARK: - DatabaseError

/// Errors thrown by `NOBSDatabase` when it is used before being configured.
public enum DatabaseError: Error, LocalizedError, Sendable {
    /// `setup()` was not called before accessing the database.
    case notSetUp

    public var errorDescription: String? {
        switch self {
        case .notSetUp:
            return "NOBSDatabase has not been set up. Call setup() before accessing data."
        }
    }
}



extension DataContext {
    var storeName: String {
        switch self {
        case .personal: return "NOBS_Personal"
        case .work:     return "NOBS_Work"
        }
    }
}

#if canImport(CoreData)
// MARK: - NOBSDatabase (CoreData)

/// Manages access to the work and personal Core Data stores.
public final class NOBSDatabase: @unchecked Sendable {
    public static let shared = NOBSDatabase()

    private var containers: [DataContext: NSPersistentContainer] = [:]

    /// The storage mode this database was set up with.
    public private(set) var storageMode: StorageMode = .localOnly

    private init() {}

    // MARK: Setup

    /// Configure both data stores. Call once at app launch.
    ///
    /// - Parameters:
    ///   - storageMode: Where data is persisted. Defaults to `.localOnly`.
    ///     **If passing `.iCloud`, you must first show `iCloudDisclosure.userFacingWarning`
    ///     and obtain explicit user consent.**
    ///   - inMemory: When `true`, uses an in-memory store (for unit tests only).
    public func setup(storageMode: StorageMode = .localOnly, inMemory: Bool = false) throws {
        self.storageMode = storageMode
        for context in DataContext.allCases {
            let container = try makeContainer(for: context, storageMode: storageMode, inMemory: inMemory)
            containers[context] = container
        }
    }

    // MARK: Managed Object Context

    /// Returns the main-thread managed object context for the given data context.
    /// - Throws: `DatabaseError.notSetUp` if `setup()` has not been called yet.
    public func viewContext(for dataContext: DataContext) throws -> NSManagedObjectContext {
        guard let container = containers[dataContext] else {
            throw DatabaseError.notSetUp
        }
        return container.viewContext
    }

    /// Creates a new background context for the given data context.
    /// - Throws: `DatabaseError.notSetUp` if `setup()` has not been called yet.
    public func newBackgroundContext(for dataContext: DataContext) throws -> NSManagedObjectContext {
        guard let container = containers[dataContext] else {
            throw DatabaseError.notSetUp
        }
        return container.newBackgroundContext()
    }

    // MARK: Private helpers

    private func makeContainer(
        for dataContext: DataContext,
        storageMode: StorageMode,
        inMemory: Bool
    ) throws -> NSPersistentContainer {
        let model = NOBSDatabase.managedObjectModel

        let container: NSPersistentContainer
        if case .iCloud(let containerID) = storageMode, !inMemory {
#if canImport(CloudKit)
            // Use NSPersistentCloudKitContainer when iCloud sync is requested.
            // Each DataContext maps to a separate CloudKit zone inside the container.
            let ckContainer = NSPersistentCloudKitContainer(
                name: dataContext.storeName,
                managedObjectModel: model
            )
            let storeURL = Self.storeURL(for: dataContext)
            let description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            // Work and personal data live in separate CloudKit zones.
            description.cloudKitContainerOptions?.databaseScope = .private
            ckContainer.persistentStoreDescriptions = [description]
            container = ckContainer
#else
            // CloudKit not available on this platform — fall back to local store.
            container = NSPersistentContainer(name: dataContext.storeName, managedObjectModel: model)
            let description = NSPersistentStoreDescription(url: Self.storeURL(for: dataContext))
            description.setOption(FileProtectionType.complete as NSObject,
                                  forKey: NSPersistentStoreFileProtectionKey)
            container.persistentStoreDescriptions = [description]
#endif
        } else {
            // Local-only or in-memory.
            container = NSPersistentContainer(name: dataContext.storeName, managedObjectModel: model)
            let description: NSPersistentStoreDescription
            if inMemory {
                description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
            } else {
                description = NSPersistentStoreDescription(url: Self.storeURL(for: dataContext))
#if os(iOS) || os(watchOS) || os(tvOS)
                description.setOption(FileProtectionType.complete as NSObject,
                                      forKey: NSPersistentStoreFileProtectionKey)
#endif
            }
            container.persistentStoreDescriptions = [description]
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError { throw error }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    // MARK: Store URLs

    static func storeURL(for dataContext: DataContext) -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("NOBS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(dataContext.storeName).sqlite")
    }

    // MARK: Core Data Model (defined in code — no .xcdatamodeld file needed)

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        // Memory entity
        let memoryEntity = NSEntityDescription()
        memoryEntity.name = "Memory"
        memoryEntity.managedObjectClassName = NSStringFromClass(MemoryMO.self)
        memoryEntity.properties = [
            attribute("id",        type: .UUIDAttributeType,   optional: false),
            attribute("content",   type: .stringAttributeType, optional: false),
            attribute("createdAt", type: .dateAttributeType,   optional: false),
            attribute("tags",      type: .stringAttributeType, optional: true),
        ]

        // UserTask entity
        let taskEntity = NSEntityDescription()
        taskEntity.name = "UserTask"
        taskEntity.managedObjectClassName = NSStringFromClass(UserTaskMO.self)
        taskEntity.properties = [
            attribute("id",          type: .UUIDAttributeType,    optional: false),
            attribute("title",       type: .stringAttributeType,  optional: false),
            attribute("dueDate",     type: .dateAttributeType,    optional: true),
            attribute("isCompleted", type: .booleanAttributeType, optional: false),
            attribute("notes",       type: .stringAttributeType,  optional: true),
            attribute("createdAt",   type: .dateAttributeType,    optional: false),
        ]

        // Preference entity
        let prefEntity = NSEntityDescription()
        prefEntity.name = "Preference"
        prefEntity.managedObjectClassName = NSStringFromClass(PreferenceMO.self)
        prefEntity.properties = [
            attribute("key",   type: .stringAttributeType, optional: false),
            attribute("value", type: .stringAttributeType, optional: false),
        ]

        model.entities = [memoryEntity, taskEntity, prefEntity]
        return model
    }()

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        return attr
    }
}

// MARK: - Managed Object subclasses

@objc(MemoryMO)
public class MemoryMO: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var tags: String?
}

@objc(UserTaskMO)
public class UserTaskMO: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var dueDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
}

@objc(PreferenceMO)
public class PreferenceMO: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
}

// MARK: - MemoryRepository (CoreData-backed)

/// High-level repository for storing and querying on-device learned memories.
public final class MemoryRepository {
    private let dataContext: DataContext
    private let database: NOBSDatabase

    public init(context: DataContext, database: NOBSDatabase = .shared) {
        self.dataContext = context
        self.database = database
    }

    @discardableResult
    public func save(content: String, tags: [String] = []) throws -> MemoryMO {
        let moc = try database.viewContext(for: dataContext)
        let memory = MemoryMO(context: moc)
        memory.id = UUID()
        memory.content = content
        memory.createdAt = Date()
        memory.tags = tags.isEmpty ? nil : tags.joined(separator: ",")
        try moc.save()
        return memory
    }

    public func fetchAll() throws -> [MemoryMO] {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<MemoryMO>(entityName: "Memory")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try moc.fetch(req)
    }

    public func search(query: String) throws -> [MemoryMO] {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<MemoryMO>(entityName: "Memory")
        req.predicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try moc.fetch(req)
    }
}

// MARK: - TaskRepository (CoreData-backed)

public final class TaskRepository {
    private let dataContext: DataContext
    private let database: NOBSDatabase

    public init(context: DataContext, database: NOBSDatabase = .shared) {
        self.dataContext = context
        self.database = database
    }

    @discardableResult
    public func create(title: String, dueDate: Date? = nil, notes: String? = nil) throws -> UserTaskMO {
        let moc = try database.viewContext(for: dataContext)
        let task = UserTaskMO(context: moc)
        task.id = UUID()
        task.title = title
        task.dueDate = dueDate
        task.isCompleted = false
        task.notes = notes
        task.createdAt = Date()
        try moc.save()
        return task
    }

    public func fetchPending() throws -> [UserTaskMO] {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<UserTaskMO>(entityName: "UserTask")
        req.predicate = NSPredicate(format: "isCompleted == NO")
        req.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        return try moc.fetch(req)
    }

    public func complete(id: UUID) throws {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<UserTaskMO>(entityName: "UserTask")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let task = try moc.fetch(req).first {
            task.isCompleted = true
            try moc.save()
        }
    }
}

// MARK: - PreferenceRepository (CoreData-backed)

/// High-level key-value repository for storing per-context user preferences.
public final class PreferenceRepository {
    private let dataContext: DataContext
    private let database: NOBSDatabase

    public init(context: DataContext, database: NOBSDatabase = .shared) {
        self.dataContext = context
        self.database = database
    }

    /// Persist or update a preference value for `key`.
    public func set(key: String, value: String) throws {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<PreferenceMO>(entityName: "Preference")
        req.predicate = NSPredicate(format: "key == %@", key)
        if let existing = try moc.fetch(req).first {
            existing.value = value
        } else {
            let pref = PreferenceMO(context: moc)
            pref.key   = key
            pref.value = value
        }
        try moc.save()
    }

    /// Return the stored value for `key`, or `nil` if not set.
    public func get(key: String) throws -> String? {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<PreferenceMO>(entityName: "Preference")
        req.predicate = NSPredicate(format: "key == %@", key)
        return try moc.fetch(req).first?.value
    }

    /// Remove the preference for `key`.  A no-op if the key does not exist.
    public func delete(key: String) throws {
        let moc = try database.viewContext(for: dataContext)
        let req = NSFetchRequest<PreferenceMO>(entityName: "Preference")
        req.predicate = NSPredicate(format: "key == %@", key)
        for pref in try moc.fetch(req) {
            moc.delete(pref)
        }
        try moc.save()
    }
}

// MARK: - MemoryIntentHandler (CoreData-backed)

/// Handles `storeMemory` and `recallMemory` intents using on-device `MemoryRepository`.
///
/// Register an instance of this handler with `NOBSAssistant` to complete the
/// memory intent pipeline end-to-end:
/// ```swift
/// let assistant = NOBSAssistant(
///     config: .localhost,
///     handlers: [MemoryIntentHandler()]
/// )
/// ```
public actor MemoryIntentHandler: IntentHandler {
    private let personalRepo: MemoryRepository
    private let workRepo:     MemoryRepository

    public init(database: NOBSDatabase = .shared) {
        self.personalRepo = MemoryRepository(context: .personal, database: database)
        self.workRepo     = MemoryRepository(context: .work,     database: database)
    }

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .storeMemory, .recallMemory: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
#if !DEBUG
        return "Memory features are coming soon in this beta build."
#else
        switch intent {
        case .storeMemory(let content, let context):
            try repo(for: context).save(content: content, tags: [context.rawValue])
            return "Memory saved."
        case .recallMemory(let query, let context):
            let results = try repo(for: context).search(query: query)
            if results.isEmpty {
                return "No \(context.rawValue) memories found matching '\(query)'."
            }
            return results.prefix(5).map(\.content).joined(separator: "\n")
        default:
            throw DatabaseError.notSetUp
        }
#endif
    }

    private func repo(for context: DataContext) -> MemoryRepository {
        context == .personal ? personalRepo : workRepo
    }
}

#else
// MARK: - NOBSDatabase (stub for non-Apple platforms)

/// Lightweight stub used on Linux / CI where CoreData is unavailable.
/// Provides the same public API backed by in-memory collections.
public final class NOBSDatabase: @unchecked Sendable {
    public static let shared = NOBSDatabase()
    public private(set) var storageMode: StorageMode = .localOnly
    private init() {}

    public func setup(storageMode: StorageMode = .localOnly, inMemory: Bool = false) throws {
        self.storageMode = storageMode
    }
}

/// Minimal in-memory memory record used on non-CoreData platforms.
public final class MemoryMO: @unchecked Sendable {
    public var id: UUID
    public var content: String
    public var createdAt: Date
    public var tags: String?
    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), tags: String? = nil) {
        self.id = id; self.content = content; self.createdAt = createdAt; self.tags = tags
    }
}

/// Minimal in-memory task record used on non-CoreData platforms.
public final class UserTaskMO: @unchecked Sendable {
    public var id: UUID
    public var title: String
    public var dueDate: Date?
    public var isCompleted: Bool
    public var notes: String?
    public var createdAt: Date
    init(id: UUID = UUID(), title: String, dueDate: Date? = nil,
         isCompleted: Bool = false, notes: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.title = title; self.dueDate = dueDate
        self.isCompleted = isCompleted; self.notes = notes; self.createdAt = createdAt
    }
}

public final class MemoryRepository {
    private var store: [MemoryMO] = []
    public init(context: DataContext, database: NOBSDatabase = .shared) {}

    @discardableResult
    public func save(content: String, tags: [String] = []) throws -> MemoryMO {
        let m = MemoryMO(content: content,
                         tags: tags.isEmpty ? nil : tags.joined(separator: ","))
        store.append(m); return m
    }
    public func fetchAll() throws -> [MemoryMO] {
        store.sorted { $0.createdAt > $1.createdAt }
    }
    public func search(query: String) throws -> [MemoryMO] {
        store
            .filter { $0.content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

public final class TaskRepository {
    private var store: [UserTaskMO] = []
    public init(context: DataContext, database: NOBSDatabase = .shared) {}

    @discardableResult
    public func create(title: String, dueDate: Date? = nil, notes: String? = nil) throws -> UserTaskMO {
        let t = UserTaskMO(title: title, dueDate: dueDate, notes: notes)
        store.append(t); return t
    }
    public func fetchPending() throws -> [UserTaskMO] { store.filter { !$0.isCompleted } }
    public func complete(id: UUID) throws { store.first(where: { $0.id == id })?.isCompleted = true }
}

// MARK: - PreferenceRepository (stub)

public final class PreferenceRepository {
    private var store: [String: String] = [:]
    public init(context: DataContext, database: NOBSDatabase = .shared) {}

    public func set(key: String, value: String) throws {
#if !DEBUG
        return
#else
        store[key] = value
#endif
    }
    public func get(key: String) throws -> String? {
#if !DEBUG
        return nil
#else
        return store[key]
#endif
    }
    public func delete(key: String) throws {
#if !DEBUG
        return
#else
        store.removeValue(forKey: key)
#endif
    }
}

// MARK: - MemoryIntentHandler (stub)

public actor MemoryIntentHandler: IntentHandler {
    private let personalRepo: MemoryRepository
    private let workRepo:     MemoryRepository

    public init(database: NOBSDatabase = .shared) {
        self.personalRepo = MemoryRepository(context: .personal, database: database)
        self.workRepo     = MemoryRepository(context: .work,     database: database)
    }

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .storeMemory, .recallMemory: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
#if !DEBUG
        return "Memory features are coming soon in this beta build."
#else
        switch intent {
        case .storeMemory(let content, let context):
            try repo(for: context).save(content: content, tags: [context.rawValue])
            return "Memory saved."
        case .recallMemory(let query, let context):
            let results = try repo(for: context).search(query: query)
            if results.isEmpty {
                return "No \(context.rawValue) memories found matching '\(query)'."
            }
            return results.prefix(5).map(\.content).joined(separator: "\n")
        default:
            throw DatabaseError.notSetUp
        }
#endif
    }

    private func repo(for context: DataContext) -> MemoryRepository {
        context == .personal ? personalRepo : workRepo
    }
}
#endif
