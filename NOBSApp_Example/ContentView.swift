import SwiftUI
import NOBSAssistant
import NOBSCore

struct ContentView: View {
    let assistant: NOBSAssistant
    
    @State private var inputText: String = ""
    @State private var messages: [(role: String, content: String)] = []
    @State private var isThinking = false

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<messages.count, id: \.self) { i in
                            let msg = messages[i]
                            HStack {
                                if msg.role == "User" { Spacer() }
                                Text(msg.content)
                                    .padding(12)
                                    .background(msg.role == "User" ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(msg.role == "User" ? .white : .primary)
                                    .cornerRadius(16)
                                if msg.role == "NOBS" { Spacer() }
                            }
                            .id(i)
                        }
                        if isThinking {
                            HStack {
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .id("thinking")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
                .onChange(of: isThinking) { _ in
                    if isThinking {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
            }

            HStack {
                TextField("Ask NOBS...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(sendMessage)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
            .padding()
        }
        .navigationTitle("NOBS")
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messages.append(("User", text))
        inputText = ""
        isThinking = true
        
        Task {
            // Send the request to the NOBSAssistant
            let response = await assistant.process(text)
            messages.append(("NOBS", response.text))
            isThinking = false
        }
    }
}
