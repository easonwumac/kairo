import Foundation

extension AgentToolInvocationPlanner {
    func isCalendarWriteRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "create a calendar event",
            "create calendar event",
            "add a calendar event",
            "add calendar event",
            "create an event",
            "add an event",
            "schedule event",
            "calendar event",
            "建立行程",
            "新增行程",
            "加入行程",
            "建立日曆",
            "新增日曆",
            "加入日曆"
        ])
    }

    func isReminderWriteRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "create a reminder",
            "create reminder",
            "add a reminder",
            "add reminder",
            "reminder to",
            "task reminder",
            "提醒事項",
            "建立提醒",
            "新增提醒",
            "加入提醒",
            "建立待辦",
            "新增待辦",
            "加入待辦"
        ])
    }

    func isEmailDraftRequest(_ normalizedText: String) -> Bool {
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

    func isContactWriteRequest(_ normalizedText: String) -> Bool {
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

    func isMapDirectionsRequest(_ normalizedText: String) -> Bool {
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

    func isMessageHandoffRequest(_ normalizedText: String) -> Bool {
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

    func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool {
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

    func calendarTitle(from userText: String) -> String {
        var title = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a calendar event:",
            "Create calendar event:",
            "Add a calendar event:",
            "Add calendar event:",
            "Create an event:",
            "Add an event:",
            "Schedule event:",
            "Calendar event:",
            "建立行程：",
            "建立行程:",
            "新增行程：",
            "新增行程:",
            "加入行程：",
            "加入行程:",
            "建立日曆：",
            "建立日曆:",
            "新增日曆：",
            "新增日曆:"
        ]

        for prefix in prefixes where title.lowercased().hasPrefix(prefix.lowercased()) {
            title.removeFirst(prefix.count)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return title.isEmpty ? "Kairo calendar event" : title
    }

    func reminderTitle(from userText: String) -> String {
        var title = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a reminder to",
            "Create reminder to",
            "Add a reminder to",
            "Add reminder to",
            "Reminder:",
            "Todo:",
            "TODO:",
            "建立提醒事項：",
            "建立提醒事項:",
            "建立提醒：",
            "建立提醒:",
            "新增提醒事項：",
            "新增提醒事項:",
            "待辦：",
            "待辦:"
        ]

        for prefix in prefixes where title.lowercased().hasPrefix(prefix.lowercased()) {
            title.removeFirst(prefix.count)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return title.isEmpty ? "Kairo reminder" : title
    }

    func emailDraft(from userText: String) -> EmailDraft {
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
            .map { String($0).trimmingCharacters(in: .contactTokenBoundary) }
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

    func mapDirectionsDraft(from userText: String, normalizedText: String) -> MapDirectionsDraft {
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

    func messageDraft(from userText: String) -> MessageDraft {
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
            .map { String($0).trimmingCharacters(in: .contactTokenBoundary) }
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

    func phoneCallDraft(from userText: String) -> PhoneCallDraft {
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
            .map { $0.trimmingCharacters(in: .contactTokenBoundary) }
            .first(where: isPhoneToken) ?? ""
        let phoneIndex = tokens.firstIndex { token in
            isPhoneToken(token.trimmingCharacters(in: .contactTokenBoundary))
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

    func contactDraft(from userText: String) -> ContactDraft {
        var content = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a contact:",
            "Create contact:",
            "Add a contact:",
            "Add contact:",
            "New contact:",
            "建立聯絡人：",
            "建立聯絡人:",
            "新增聯絡人：",
            "新增聯絡人:",
            "加入聯絡人：",
            "加入聯絡人:",
            "建立联系人：",
            "建立联系人:",
            "新增联系人：",
            "新增联系人:",
            "加入联系人：",
            "加入联系人:"
        ]

        for prefix in prefixes where content.lowercased().hasPrefix(prefix.lowercased()) {
            content.removeFirst(prefix.count)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
        var nameTokens: [String] = []
        var phoneNumbers: [String] = []
        var emailAddresses: [String] = []

        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .contactTokenBoundary)
            if isEmailToken(trimmed) {
                emailAddresses.append(trimmed)
            } else if isPhoneToken(trimmed) {
                phoneNumbers.append(trimmed)
            } else if !trimmed.isEmpty {
                nameTokens.append(trimmed)
            }
        }

        let name = nameTokens.joined(separator: " ")
        let fallbackName = name.isEmpty ? "Kairo Contact" : name
        let shouldSplitASCIIName = nameTokens.count >= 2 && nameTokens.allSatisfy { $0.unicodeScalars.allSatisfy(\.isASCII) }
        let givenName: String
        let familyName: String
        if shouldSplitASCIIName {
            givenName = nameTokens.dropLast().joined(separator: " ")
            familyName = nameTokens.last ?? ""
        } else {
            givenName = fallbackName
            familyName = ""
        }

        return ContactDraft(
            givenName: givenName,
            familyName: familyName,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            notes: "Drafted from a Kairo chat request."
        )
    }

    func isEmailToken(_ token: String) -> Bool {
        token.contains("@") && token.contains(".")
    }

    func isPhoneToken(_ token: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "+-().")
            .union(.decimalDigits)
        let scalars = token.unicodeScalars
        let digitCount = scalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return digitCount >= 3 && scalars.allSatisfy { allowed.contains($0) }
    }

    func section(in text: String, after startMarkers: [String], until endMarkers: [String]) -> String? {
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

    func firstRange(of markers: [String], in text: String) -> Range<String.Index>? {
        markers
            .compactMap { text.range(of: $0, options: [.caseInsensitive]) }
            .sorted { $0.lowerBound < $1.lowerBound }
            .first
    }

    func notificationBody(from userText: String) -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Kairo notification requested by the user."
        }
        return trimmed
    }

    func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(normalize($0)) }
    }

    func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func uniqueCandidates(_ candidates: [AgentToolInvocationCandidate]) -> [AgentToolInvocationCandidate] {
        var seen: Set<String> = []
        var result: [AgentToolInvocationCandidate] = []

        for candidate in candidates where !seen.contains(candidate.id) {
            seen.insert(candidate.id)
            result.append(candidate)
        }

        return result
    }
}

private extension CharacterSet {
    static let contactTokenBoundary = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "+-@._")))
}
