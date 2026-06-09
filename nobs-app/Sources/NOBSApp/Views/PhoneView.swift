import SwiftUI

struct PhoneView: View {
    @State private var phoneNumber = ""
    @State private var recentCalls: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.nobsGreen)
                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                        Button {
                            dialNumber(phoneNumber)
                        } label: {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.nobsGreen)
                        }
                        .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Enter a number").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)

                if !recentCalls.isEmpty {
                    Section {
                        ForEach(recentCalls, id: \.self) { call in
                            Button {
                                dialNumber(call)
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.backward.circle")
                                        .foregroundStyle(Color.nobsSecondary)
                                    Text(call)
                                        .foregroundStyle(Color.nobsPrimary)
                                    Spacer()
                                    Image(systemName: "phone.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.nobsGreen)
                                }
                            }
                        }
                    } header: {
                        Text("Recent").sectionOverline()
                    }
                    .listRowBackground(Color.nobsCard)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Use your own carrier plan", systemImage: "checkmark.circle")
                        Label("No Google Voice account needed", systemImage: "checkmark.circle")
                        Label("Works on any iPhone without entitlements", systemImage: "checkmark.circle")
                        Label("CallKit support requires Apple Developer account", systemImage: "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.nobsSecondary)
                }
                .listRowBackground(Color.nobsCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .navigationTitle("Phone")
            .tint(Color.nobsGreen)
        }
    }

    private func dialNumber(_ number: String) {
        let cleaned = number.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        recentCalls.insert(cleaned, at: 0)
        if recentCalls.count > 10 { recentCalls.removeLast() }
        phoneNumber = ""

        guard let url = URL(string: "tel://\(cleaned)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
