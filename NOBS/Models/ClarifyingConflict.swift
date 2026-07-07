import Foundation

struct ClarifyingConflict: Codable, Hashable, Sendable {
    struct Option: Codable, Hashable, Sendable {
        var id: String
        var label: String
        var eventID: String
    }

    var question: String
    var optionA: Option
    var optionB: Option
}
