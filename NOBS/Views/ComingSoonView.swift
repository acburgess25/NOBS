import SwiftUI

struct ComingSoonView: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }
}
