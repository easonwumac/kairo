import Foundation

public protocol AgentToolInvocationActionParsing: Sendable {
    func isCalendarWriteRequest(_ normalizedText: String) -> Bool
    func isReminderWriteRequest(_ normalizedText: String) -> Bool
    func isEmailDraftRequest(_ normalizedText: String) -> Bool
    func isMapDirectionsRequest(_ normalizedText: String) -> Bool
    func isMessageHandoffRequest(_ normalizedText: String) -> Bool
    func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool
    func isWebSearchHandoffRequest(_ normalizedText: String) -> Bool
    func isContactWriteRequest(_ normalizedText: String) -> Bool
    func isNotificationRequest(_ normalizedText: String) -> Bool
    func calendarDraft(from userText: String) -> CalendarEventDraft
    func reminderTitle(from userText: String) -> String
    func contactDraft(from userText: String) -> ContactDraft
    func notificationBody(from userText: String) -> String
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

    public func isCalendarWriteRequest(_ normalizedText: String) -> Bool {
        if containsAny(normalizedText, [
            "create a calendar event",
            "create calendar event",
            "add a calendar event",
            "add calendar event",
            "create an event",
            "add an event",
            "schedule event",
            "schedule a meeting",
            "schedule meeting",
            "calendar event",
            "建立行程",
            "新增行程",
            "加入行程",
            "建立日曆",
            "新增日曆",
            "加入日曆",
            "安排會議",
            "安排会议",
            "新增會議",
            "新增会议",
            "建立會議",
            "建立会议"
        ]) {
            return true
        }

        return (normalizedText.contains("meeting") && containsAny(normalizedText, ["schedule", "create", "add"]))
            || (normalizedText.contains("會議") && containsAny(normalizedText, ["安排", "新增", "建立", "開"]))
            || (normalizedText.contains("会议") && containsAny(normalizedText, ["安排", "新增", "建立", "开"]))
    }

    public func isReminderWriteRequest(_ normalizedText: String) -> Bool {
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

    public func isNotificationRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "notify me",
            "notification",
            "send notification",
            "remind me",
            "reminder alert",
            "通知我",
            "通知",
            "提醒我",
            "提醒"
        ])
    }

    public func calendarDraft(from userText: String) -> CalendarEventDraft {
        calendarDraft(from: userText, now: Date())
    }

    public func reminderTitle(from userText: String) -> String {
        var title = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a reminder to",
            "Create reminder to",
            "Create reminder:",
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

    public func contactDraft(from userText: String) -> ContactDraft {
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
            let trimmed = token.trimmingCharacters(in: .appIntegrationContactTokenBoundary)
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

    public func notificationBody(from userText: String) -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Kairo notification requested by the user."
        }
        return trimmed
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

    private func calendarTitle(from userText: String) -> String {
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
            "新增日曆:",
            "Schedule a meeting:",
            "Schedule meeting:",
            "安排會議：",
            "安排會議:",
            "安排会议：",
            "安排会议:",
            "新增會議：",
            "新增會議:",
            "新增会议：",
            "新增会议:"
        ]

        for prefix in prefixes where title.lowercased().hasPrefix(prefix.lowercased()) {
            title.removeFirst(prefix.count)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        title = strippingCalendarDateTokens(from: title)
        title = strippingCalendarMeetingWords(from: title)
        return title.isEmpty ? "Kairo calendar event" : title
    }

    private func calendarDraft(from userText: String, now: Date) -> CalendarEventDraft {
        let startDate = calendarStartDate(from: userText, now: now) ?? now.addingTimeInterval(3_600)
        return CalendarEventDraft(
            title: calendarTitle(from: userText),
            notes: "Drafted from a Kairo chat request.",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3_600)
        )
    }

    private func calendarStartDate(from userText: String, now: Date) -> Date? {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let timeMatch = firstMatch(
            pattern: #"(?<!\d)([01]?\d|2[0-3])[:：點时時]([0-5]\d)?"#,
            in: text
        ), let hour = Int(timeMatch.groups[0]) else {
            return nil
        }
        let minuteText = timeMatch.groups.indices.contains(1) ? timeMatch.groups[1] : ""
        let minute = minuteText.isEmpty ? 0 : Int(minuteText) ?? 0

        let calendar = Calendar.current
        let weekday = calendarWeekday(from: text)
        return weekday.flatMap { nextDate(for: $0, hour: hour, minute: minute, after: now, calendar: calendar) }
            ?? nextDate(hour: hour, minute: minute, after: now, calendar: calendar)
    }

    private func strippingCalendarDateTokens(from text: String) -> String {
        let patterns = [
            #"(週|星期|禮拜|礼拜)[一二三四五六日天1-7]\s*([01]?\d|2[0-3])[:：點时時]([0-5]\d)?"#,
            #"(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+([01]?\d|2[0-3])[:：]([0-5]\d)?"#,
            #"(?<!\d)([01]?\d|2[0-3])[:：點时時]([0-5]\d)?"#
        ]
        return patterns.reduce(text) { value, pattern in
            replacingMatches(pattern: pattern, in: value, with: " ")
        }
        .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-：，,"))
    }

    private func strippingCalendarMeetingWords(from text: String) -> String {
        let patterns = [
            #"^(幫我|請幫我|麻煩幫我|請)?\s*(安排|新增|建立|加入|開|开)\s*"#,
            #"\s*(會議|会议|行程|日曆|日历|meeting|calendar event)$"#
        ]
        return patterns.reduce(text) { value, pattern in
            replacingMatches(pattern: pattern, in: value, with: " ")
        }
        .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-：，,"))
    }

    private func calendarWeekday(from text: String) -> Int? {
        if let match = firstMatch(pattern: #"(週|星期|禮拜|礼拜)([一二三四五六日天1-7])"#, in: text) {
            return weekdayNumber(from: match.groups[1])
        }
        if let match = firstMatch(pattern: #"(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, in: text.lowercased()) {
            return weekdayNumber(fromEnglish: match.groups[0])
        }
        return nil
    }

    private func weekdayNumber(from value: String) -> Int? {
        switch value {
        case "日", "天", "7":
            return 1
        case "一", "1":
            return 2
        case "二", "2":
            return 3
        case "三", "3":
            return 4
        case "四", "4":
            return 5
        case "五", "5":
            return 6
        case "六", "6":
            return 7
        default:
            return nil
        }
    }

    private func weekdayNumber(fromEnglish value: String) -> Int? {
        switch value {
        case "sunday":
            return 1
        case "monday":
            return 2
        case "tuesday":
            return 3
        case "wednesday":
            return 4
        case "thursday":
            return 5
        case "friday":
            return 6
        case "saturday":
            return 7
        default:
            return nil
        }
    }

    private func nextDate(for weekday: Int, hour: Int, minute: Int, after now: Date, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime, direction: .forward)
    }

    private func nextDate(hour: Int, minute: Int, after now: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let today = calendar.date(from: components) else {
            return nil
        }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
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

    private func firstMatch(pattern: String, in text: String) -> (range: Range<String.Index>, groups: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        let groups = (1..<match.numberOfRanges).map { index -> String in
            guard let groupRange = Range(match.range(at: index), in: text) else {
                return ""
            }
            return String(text[groupRange])
        }
        return (range, groups)
    }

    private func replacingMatches(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

private extension CharacterSet {
    static let appIntegrationContactTokenBoundary = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "+-@._")))
}
