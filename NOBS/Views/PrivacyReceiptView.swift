import SwiftUI

struct PrivacyReceiptView: View {
    let receipt: PrivacyReceipt
    private let accent = Color.nobsAccent

    var body: some View {
        NavigationStack {
            List {
                receiptSection("Used", values: receipt.used, empty: "Nothing")
                receiptSection("Processed", values: [receipt.processed], empty: "Unknown")
                receiptSection("Shared", values: receipt.shared, empty: "Nothing")
                receiptSection("Changed", values: receipt.changed, empty: "Nothing")
            }
            .nobsListScreen()
            .navigationTitle("Privacy receipt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func receiptSection(_ title: String, values: [String], empty: String) -> some View {
        Section {
            if values.isEmpty {
                Text(empty).foregroundStyle(Color.nobsMuted)
            } else {
                ForEach(values, id: \.self) { Text($0) }
            }
        } header: {
            Text(title).nobsEyebrow()
        }
    }
}
