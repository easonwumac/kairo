import Foundation

public protocol AgentToolInvocationActionParsing: Sendable {
    func isEmailDraftRequest(_ normalizedText: String) -> Bool
    func isMapDirectionsRequest(_ normalizedText: String) -> Bool
    func isMessageHandoffRequest(_ normalizedText: String) -> Bool
    func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool
    func isWebSearchHandoffRequest(_ normalizedText: String) -> Bool
    func isContactWriteRequest(_ normalizedText: String) -> Bool
    func emailDraft(from userText: String) -> EmailDraft
    func mapDirectionsDraft(from userText: String, normalizedText: String) -> MapDirectionsDraft
    func messageDraft(from userText: String) -> MessageDraft
    func phoneCallDraft(from userText: String) -> PhoneCallDraft
    func webSearchDraft(from userText: String) -> WebSearchDraft
    func isPhoneToken(_ value: String) -> Bool
    func normalize(_ value: String) -> String
}

public struct DefaultAgentToolInvocationActionParser: AgentToolInvocationActionParsing {
    public init() {}

    public func isEmailDraftRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "draft an email",
            "draft email",
            "compose an email",
            "compose email",
            "write an email",
            "write email",
            "email draft",
            "草擬 email",
            "撰寫 email",
            "寫 email",
            "草擬郵件",
            "撰寫郵件",
            "寫郵件",
            "草拟邮件",
            "撰写邮件",
            "写邮件"
        ])
    }

    public func isContactWriteRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "create a contact",
            "create contact",
            "add a contact",
            "add contact",
            "new contact",
            "建立聯絡人",
            "新增聯絡人",
            "加入聯絡人",
            "建立联系人",
            "新增联系人",
            "加入联系人"
        ])
    }

    public func isMapDirectionsRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "navigate to",
            "directions to",
            "drive to",
            "walk to",
            "transit to",
            "route to",
            "map directions",
            "open maps to",
            "apple maps",
            "導航到",
            "導航去",
            "開車去",
            "走路去",
            "大眾運輸去",
            "路線到",
            "帶我去"
        ])
    }

    public func isMessageHandoffRequest(_ normalizedText: String) -> Bool {
        let explicitPrefixes = [
            "text ",
            "message ",
            "sms ",
            "傳訊息",
            "發訊息",
            "寫訊息",
            "傳簡訊",
            "發簡訊",
            "寫簡訊"
        ]
        if explicitPrefixes.contains(where: { normalizedText.hasPrefix(normalize($0)) }) {
            return true
        }

        return containsAny(normalizedText, [
            "send a text",
            "draft a text",
            "send sms",
            "write a message",
            "send message",
            "傳 sms",
            "發 sms",
            "傳 message",
            "發 message"
        ])
    }

    public func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool {
        let explicitPrefixes = [
            "call ",
            "phone ",
            "dial ",
            "tel ",
            "打電話",
            "撥號",
            "致電"
        ]
        if explicitPrefixes.contains(where: { normalizedText.hasPrefix(normalize($0)) }) {
            return true
        }

        return containsAny(normalizedText, [
            "phone call",
            "make a call",
            "place a call",
            "call number",
            "call alex",
            "撥打電話",
            "打給"
        ])
    }

    public func isWebSearchHandoffRequest(_ normalizedText: String) -> Bool {
        let explicitPrefixes = [
            "search web ",
            "search the web ",
            "web search ",
            "google ",
            "duckduckgo ",
            "搜尋網路",
            "查網路",
            "網路搜尋"
        ]
        if explicitPrefixes.contains(where: { normalizedText.hasPrefix(normalize($0)) }) {
            return true
        }

        return containsAny(normalizedText, [
            "search web for",
            "search the web for",
            "web search for",
            "look up online",
            "搜尋網路",
            "查網路",
            "網路搜尋"
        ])
    }

    public func emailDraft(from userText: String) -> EmailDraft {
        var content = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Draft an email",
            "Draft email",
            "Compose an email",
            "Compose email",
            "Write an email",
            "Write email",
            "草擬 email",
            "撰寫 email",
            "寫 email",
            "草擬郵件",
            "撰寫郵件",
            "寫郵件",
            "草拟邮件",
            "撰写邮件",
            "写邮件"
        ]

        for prefix in prefixes where content.lowercased().hasPrefix(prefix.lowercased()) {
            content.removeFirst(prefix.count)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.first == ":" || content.first == "：" {
                content.removeFirst()
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
        }

        let recipients = content
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .appIntegrationContactTokenBoundary) }
            .filter(isEmailToken)

        let subject = section(
            in: content,
            after: ["subject ", "subject:", "subject：", "主旨 ", "主旨:", "主旨：", "標題 ", "標題:", "標題："],
            until: [" body ", " body:", " body：", "內容 ", "內容:", "內容：", "內文 ", "內文:", "內文："]
        ) ?? "Kairo email draft"
        let body = section(
            in: content,
            after: ["body ", "body:", "body：", "內容 ", "內容:", "內容：", "內文 ", "內文:", "內文："],
            until: []
        ) ?? "Drafted from a Kairo chat request."

        return EmailDraft(
            to: Array(Set(recipients)).sorted(),
            subject: subject,
            body: body
        )
    }

    public func mapDirectionsDraft(from userText: String, normalizedText: String) -> MapDirectionsDraft {
        var destination = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Navigate to",
            "Directions to",
            "Drive to",
            "Walk to",
            "Transit to",
            "Route to",
            "Map directions to",
            "Open maps to",
            "Apple Maps to",
            "導航到",
            "導航去",
            "開車去",
            "走路去",
            "大眾運輸去",
            "路線到",
            "帶我去"
        ]

        for prefix in prefixes where destination.lowercased().hasPrefix(prefix.lowercased()) {
            destination.removeFirst(prefix.count)
            destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            if destination.first == ":" || destination.first == "：" {
                destination.removeFirst()
                destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
        }

        let mode: MapDirectionsMode
        if containsAny(normalizedText, ["walk", "walking", "by foot", "走路", "步行"]) {
            mode = .walking
        } else if containsAny(normalizedText, ["transit", "public transit", "bus", "train", "大眾運輸", "捷運", "公車"]) {
            mode = .transit
        } else {
            mode = .driving
        }

        return MapDirectionsDraft(
            destinationQuery: destination.isEmpty ? "Current map destination" : destination,
            mode: mode
        )
    }

    public func messageDraft(from userText: String) -> MessageDraft {
        var content = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Text",
            "Send a text",
            "Draft a text",
            "Message",
            "SMS",
            "Send SMS",
            "Write a message",
            "Send message",
            "傳訊息",
            "發訊息",
            "寫訊息",
            "傳簡訊",
            "發簡訊",
            "寫簡訊"
        ]

        for prefix in prefixes where content.lowercased().hasPrefix(prefix.lowercased()) {
            content.removeFirst(prefix.count)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.first == ":" || content.first == "：" {
                content.removeFirst()
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
        }

        let recipients = content
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .appIntegrationContactTokenBoundary) }
            .filter(isPhoneToken)

        let body = section(
            in: content,
            after: [
                " body ",
                " body:",
                " body：",
                " message ",
                " message:",
                " message：",
                "內容 ",
                "內容:",
                "內容：",
                "訊息 ",
                "訊息:",
                "訊息：",
                "簡訊 ",
                "簡訊:",
                "簡訊："
            ],
            until: []
        ) ?? "Drafted from a Kairo chat request."

        return MessageDraft(
            recipients: Array(Set(recipients)).sorted(),
            body: body
        )
    }

    public func phoneCallDraft(from userText: String) -> PhoneCallDraft {
        var content = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Call",
            "Phone",
            "Dial",
            "Tel",
            "Make a call",
            "Place a call",
            "打電話",
            "撥號",
            "致電",
            "打給"
        ]

        for prefix in prefixes where content.lowercased().hasPrefix(prefix.lowercased()) {
            content.removeFirst(prefix.count)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.first == ":" || content.first == "：" {
                content.removeFirst()
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
        }

        let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
        let phoneNumber = tokens
            .map { $0.trimmingCharacters(in: .appIntegrationContactTokenBoundary) }
            .first(where: isPhoneToken) ?? ""
        let phoneIndex = tokens.firstIndex { token in
            isPhoneToken(token.trimmingCharacters(in: .appIntegrationContactTokenBoundary))
        }
        let labelTokens: [String]
        if let phoneIndex {
            labelTokens = tokens[..<phoneIndex].map { String($0) }
        } else {
            labelTokens = []
        }
        let label = labelTokens
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return PhoneCallDraft(
            phoneNumber: phoneNumber,
            label: label.isEmpty ? nil : label,
            notes: content.isEmpty ? nil : content
        )
    }

    public func webSearchDraft(from userText: String) -> WebSearchDraft {
        var query = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Search web for",
            "Search the web for",
            "Search web",
            "Search the web",
            "Web search for",
            "Web search",
            "Google",
            "DuckDuckGo",
            "Look up online",
            "搜尋網路",
            "查網路",
            "網路搜尋"
        ]

        for prefix in prefixes where query.lowercased().hasPrefix(prefix.lowercased()) {
            query.removeFirst(prefix.count)
            query = query.trimmingCharacters(in: CharacterSet(charactersIn: " \t:-："))
            break
        }

        return WebSearchDraft(query: query.isEmpty ? "Kairo search" : query)
    }

    public func isPhoneToken(_ token: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "+-().")
            .union(.decimalDigits)
        let scalars = token.unicodeScalars
        let digitCount = scalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return digitCount >= 3 && scalars.allSatisfy { allowed.contains($0) }
    }

    public func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(normalize($0)) }
    }

    private func isEmailToken(_ token: String) -> Bool {
        token.contains("@") && token.contains(".")
    }

    private func section(in text: String, after startMarkers: [String], until endMarkers: [String]) -> String? {
        guard let startRange = firstRange(of: startMarkers, in: text) else {
            return nil
        }
        let afterStart = String(text[startRange.upperBound...])
        let endRange = firstRange(of: endMarkers, in: afterStart)
        let raw: String
        if let endRange {
            raw = String(afterStart[..<endRange.lowerBound])
        } else {
            raw = afterStart
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func firstRange(of markers: [String], in text: String) -> Range<String.Index>? {
        markers
            .compactMap { text.range(of: $0, options: [.caseInsensitive]) }
            .sorted { $0.lowerBound < $1.lowerBound }
            .first
    }
}

extension AgentToolInvocationPlanner: AgentToolInvocationActionParsing {}

private extension CharacterSet {
    static let appIntegrationContactTokenBoundary = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "+-@._")))
}
