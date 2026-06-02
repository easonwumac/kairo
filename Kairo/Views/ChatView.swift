#if canImport(SwiftUI)
import SwiftUI

public struct ChatView: View {
    @State private var input: String = ""
    @State private var messages: [String] = [
        "Kairo：我會記住你選擇交給我的內容，並只使用 iOS 允許與你授權的能力。"
    ]

    private let agent = AgentCore()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack {
                List(messages, id: \.self) { message in
                    Text(message)
                }

                HStack {
                    TextField("Ask Kairo", text: $input)
                        .textFieldStyle(.roundedBorder)

                    Button("Send") {
                        send()
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Kairo")
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append("你：\(text)")

        Task {
            do {
                let response = try await agent.respond(to: text)
                await MainActor.run {
                    messages.append("Kairo：\(response.message)")
                }
            } catch {
                await MainActor.run {
                    messages.append("Kairo：發生錯誤：\(error.localizedDescription)")
                }
            }
        }
    }
}
#endif
