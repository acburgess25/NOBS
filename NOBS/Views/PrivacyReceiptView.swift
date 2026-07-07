import SwiftUI

struct PrivacyReceiptView: View {
    let receipt: PrivacyReceipt

    var body: some View {
        NavigationStack {
            List {
                receiptSection("Used", values: receipt.used, empty: "Nothing")
                receiptSection("Processed", values: [receipt.processed], empty: "Unknown")
                receiptSection("Shared", values: receipt.shared, empty: "Nothing")
                receiptSection("Changed", values: receipt.changed, empty: "Nothing")
            }
            .navigationTitle("Privacy receipt")
        }
    }

    private func receiptSection(_ title: String, values: [String], empty: String) -> some View {
        Section(title) {
            if values.isEmpty { Text(empty).foregroundStyle(.secondary) }
            else { ForEach(values, id: \.self) { Text($0) } }
        }
    }
}
