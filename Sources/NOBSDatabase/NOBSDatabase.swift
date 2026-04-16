/// NOBSDatabase — Work / Personal Data Stores
///
/// Maintains two completely separate encrypted Core Data persistent stores:
/// one for personal data and one for work data. The two stores never share
/// a persistent coordinator, so data cannot accidentally leak between contexts.
///
/// On non-Apple platforms (Linux CI) the CoreData stack is replaced with
/// in-memory stubs so that all modules compile and tests run without a
/// full macOS/iOS SDK.

import Foundation

#if canImport(CoreData)
import CoreData
#endif

import NOBSCore

// MARK: - DataContext → store name mapping

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

    private init() {}

    // MARK: Setup

    /// Call once at app launch (or in tests) to configure both stores.
    public func setup(inMemory: Bool = false) throws {
        for context in DataContext.allCases {
            let container = try makeContainer(for: context, inMemory: inMemory)
            containers[context] = container
        }
    }

    // MARK: Managed Object Context

    /// Returns the main-thread managed object context for the given data context.
    public func viewContext(for dataContext: DataContext) -> NSManagedObjectContext {
        guard let container = containers[dataContext] else {
            fatalError("NOBSDatabase has not been set up. Call setup() first.")
        }
        return container.viewContext
    }

    /// Creates a new background context for the given data context.
    public func newBackgroundContext(for dataContext: DataContext) -> NSManagedObjectContext {
        guard let container = containers[dataContext] else {
            fatalError("NOBSDatabase has not been set up. Call setup() first.")
        }
        return container.newBackgroundContext()
    }

    // MARK: Private helpers

    private func makeContainer(for dataContext: DataContext, inMemory: Bool) throws -> NSPersistentContainer {
        let model = NOBSDatabase.managedObjectModel
        let container = NSPersistentContainer(name: dataContext.storeName, managedObjectModel: model)

        let description: NSPersistentStoreDescription
        if inMemory {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        } else {
            let storeURL = Self.storeURL(for: dataContext)
            description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }
        container.persistentStoreDescriptions = [description]

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
        let moc = database.viewContext(for: dataContext)
        let memory = MemoryMO(context: moc)
        memory.id = UUID()
        memory.content = content
        memory.createdAt = Date()
        memory.tags = tags.isEmpty ? nil : tags.joined(separator: ",")
        try moc.save()
        return memory
    }

    public func fetchAll() throws -> [MemoryMO] {
        let moc = database.viewContext(for: dataContext)
        let req = NSFetchRequest<MemoryMO>(entityName: "Memory")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try moc.fetch(req)
    }

    public func search(query: String) throws -> [MemoryMO] {
        let moc = database.viewContext(for: dataContext)
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
        let moc = database.viewContext(for: dataContext)
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
        let moc = database.viewContext(for: dataContext)
        let req = NSFetchRequest<UserTaskMO>(entityName: "UserTask")
        req.predicate = NSPredicate(format: "isCompleted == NO")
        req.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        return try moc.fetch(req)
    }

    public func complete(id: UUID) throws {
        let moc = database.viewContext(for: dataContext)
        let req = NSFetchRequest<UserTaskMO>(entityName: "UserTask")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let task = try moc.fetch(req).first {
            task.isCompleted = true
            try moc.save()
        }
    }
}

#else
// MARK: - NOBSDatabase (stub for non-Apple platforms)

/// Lightweight stub used on Linux / CI where CoreData is unavailable.
/// Provides the same public API backed by in-memory dictionaries.
public final class NOBSDatabase: @unchecked Sendable {
    public static let shared = NOBSDatabase()
    private init() {}
    public func setup(inMemory: Bool = false) throws {}
}

/// Minimal in-memory memory record used on non-CoreData platforms.
public final class MemoryMO: @unchecked Sendable {
    public var id: UUID
    public var content: String
    public var createdAt: Date
    public var tags: String?
    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), tags: String? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.tags = tags
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
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.createdAt = createdAt
    }
}

public final class MemoryRepository {
    private let dataContext: DataContext
    private var store: [MemoryMO] = []

    public init(context: DataContext, database: NOBSDatabase = .shared) {
        self.dataContext = context
    }

    @discardableResult
    public func save(content: String, tags: [String] = []) throws -> MemoryMO {
        let m = MemoryMO(
            content: content,
            tags: tags.isEmpty ? nil : tags.joined(separator: ",")
        )
        store.append(m)
        return m
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
        store.append(t)
        return t
    }

    public func fetchPending() throws -> [UserTaskMO] {
        store.filter { !$0.isCompleted }
    }

    public func complete(id: UUID) throws {
        store.first(where: { $0.id == id })?.isCompleted = true
    }
}
#endif
