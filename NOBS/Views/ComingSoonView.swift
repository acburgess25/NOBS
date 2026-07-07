import SwiftUI

struct ComingSoonView: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        NOBSEmptyState(symbol: symbol, title: title, detail: detail)
    }
}
