import Foundation

public actor ShortcutNodeRuntime {
    private let memoryStore: MemoryStore

    public init(memoryStore: MemoryStore) {
        self.memoryStore = memoryStore
    }

    public static func live(paths: KairoPaths = KairoSharedAppStorage.paths()) async throws -> ShortcutNodeRuntime {
        let store = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        return ShortcutNodeRuntime(memoryStore: store)
    }

    public func run(_ kind: ShortcutNodeKind, input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        switch kind {
        case .saveMemory:
            return try await saveMemory(input)
        case .searchMemory:
            return try await searchMemory(input)
        case .extractTasks:
            return try extractTasks(input)
        case .createReminderDraft:
            return try createReminderDrafts(input)
        case .createCalendarDraft:
            return try createCalendarDraft(input)
        case .createContactDraft:
            return try createContactDraft(input)
        case .createEmailDraft:
            return try createEmailDraft(input)
        case .prepareMessageHandoff:
            return try prepareMessageHandoff(input)
        case .preparePhoneCallHandoff:
            return try preparePhoneCallHandoff(input)
        case .prepareWebSearchHandoff:
            return try prepareWebSearchHandoff(input)
        case .createRecipeDraft:
            return try createRecipeDraft(input)
        case .draftReply:
            return try draftReply(input)
        case .summarize:
            return try summarize(input)
        case .dailyBriefing:
            return try dailyBriefing(input)
        case .previewHomeAction:
            return try previewHomeAction(input)
        case .ask:
            return try await ask(input)
        }
    }

    private func saveMemory(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let memory = MemoryRecord(
            title: title(for: text),
            summary: String(text.prefix(160)),
            content: text,
            source: .appIntent,
            tags: input.sourceName.map { ["shortcut", $0] } ?? ["shortcut"]
        )
        try await memoryStore.save(memory)

        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["memoryID"] = memory.id.uuidString
        fields["taskCount"] = String(tasks.count)

        return ShortcutNodeOutput(
            kind: .saveMemory,
            displayText: "Saved memory. Extracted \(tasks.count) tasks.",
            fields: fields,
            memoryID: memory.id,
            tasks: tasks
        )
    }

    private func searchMemory(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let query = try validatedText(input.query ?? input.text)
        let limit = max(input.limit, 1)
        let memories = try await memoryStore.search(query: query, limit: limit)
        let matches = memories.map { memory in
            ShortcutMemoryMatch(id: memory.id, title: memory.title, summary: memory.summary)
        }

        var fields = baseFields(for: input)
        fields["query"] = query
        fields["matchCount"] = String(matches.count)

        return ShortcutNodeOutput(
            kind: .searchMemory,
            displayText: "Found \(matches.count) memory matches.",
            fields: fields,
            memoryMatches: matches
        )
    }

    private func extractTasks(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["taskCount"] = String(tasks.count)
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .extractTasks,
            displayText: "Extracted \(tasks.count) tasks.",
            fields: fields,
            tasks: tasks,
            reminderDrafts: tasks.map { ReminderDraft(title: $0.title, notes: $0.notes, dueDate: nil) }
        )
    }

    private func createReminderDrafts(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        let reminderDrafts = tasks.isEmpty
            ? [ReminderDraft(title: title(for: text), notes: text, dueDate: nil)]
            : tasks.map { ReminderDraft(title: $0.title, notes: $0.notes, dueDate: nil) }
        var fields = baseFields(for: input)
        fields["reminderDraftCount"] = String(reminderDrafts.count)
        fields["reminderRequiresConfirmation"] = "true"
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .createReminderDraft,
            displayText: "Prepared \(reminderDrafts.count) reminder drafts. Review before writing to EventKit.",
            fields: fields,
            reminderDrafts: reminderDrafts
        )
    }

    private func createCalendarDraft(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let draft = CalendarEventDraft(
            title: calendarTitle(from: text),
            notes: text,
            startDate: calendarDate(named: "startDateISO", from: input.variables)
                ?? calendarDate(from: text, prefixes: ["start:", "starts:", "start time:", "開始:"])
                ?? Self.defaultCalendarStartDate,
            endDate: calendarDate(named: "endDateISO", from: input.variables)
                ?? calendarDate(from: text, prefixes: ["end:", "ends:", "end time:", "結束:"])
                ?? Self.defaultCalendarStartDate.addingTimeInterval(3_600)
        )
        var fields = baseFields(for: input)
        fields["calendarDraftCount"] = "1"
        fields["calendarTitle"] = draft.title
        fields["calendarRequiresConfirmation"] = "true"
        fields["calendarStartDate"] = iso8601String(from: draft.startDate)
        fields["calendarEndDate"] = iso8601String(from: draft.endDate)
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .createCalendarDraft,
            displayText: "Prepared 1 calendar draft. Review before writing to EventKit.",
            fields: fields,
            calendarDrafts: [draft]
        )
    }

    private func createContactDraft(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let nameParts = contactNameParts(from: input, text: text)
        let draft = ContactDraft(
            givenName: nameParts.given,
            familyName: nameParts.family,
            phoneNumbers: uniqueStrings(
                contactValues(from: input.variables, keys: ["phone", "phoneNumber", "mobile", "contactPhone"])
                    + contactValues(from: text, prefixes: ["phone:", "tel:", "mobile:", "電話:", "手機:"])
            ),
            emailAddresses: uniqueStrings(
                contactValues(from: input.variables, keys: ["email", "emailAddress", "contactEmail"])
                    + contactValues(from: text, prefixes: ["email:", "mail:", "電子郵件:", "信箱:"])
            ),
            notes: contactNotes(from: input, text: text)
        )
        let action = AgentAction(
            kind: .createContactDraft,
            title: "Review Contact Draft",
            rationale: "Shortcut requested a Contacts.framework draft. Kairo returns structured draft data and requires visible confirmation before any Contacts write.",
            payload: .contact(draft),
            riskTier: .tier2LowRiskWrite
        )

        var fields = baseFields(for: input)
        fields["contactDraftCount"] = "1"
        fields["contactDisplayName"] = draft.displayName
        fields["contactPhoneCount"] = String(draft.phoneNumbers.count)
        fields["contactEmailCount"] = String(draft.emailAddresses.count)
        fields["contactRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["chainText"] = draft.displayName

        return ShortcutNodeOutput(
            kind: .createContactDraft,
            displayText: "Prepared 1 contact draft. Review before writing to Contacts.",
            fields: fields,
            contactDrafts: [draft],
            proposedActions: [action]
        )
    }

    private func createEmailDraft(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let body = emailBody(from: text)
        let draft = EmailDraft(
            to: emailRecipients(from: input.variables, keys: ["recipient", "to", "emailTo"])
                + emailRecipients(from: text, prefixes: ["to:", "recipient:", "收件人:"]),
            cc: emailRecipients(from: input.variables, keys: ["cc", "emailCC"]),
            bcc: emailRecipients(from: input.variables, keys: ["bcc", "emailBCC"]),
            subject: emailSubject(from: input, text: text, body: body),
            body: body
        )
        let action = AgentAction(
            kind: .composeEmailDraft,
            title: "Review Email Draft",
            rationale: "Shortcut requested an email draft. Kairo only returns structured draft data for visible review and does not send mail.",
            payload: .email(draft),
            riskTier: .tier1Draft
        )

        var fields = baseFields(for: input)
        fields["emailDraftCount"] = "1"
        fields["emailSubject"] = draft.subject
        fields["emailRecipientCount"] = String(draft.to.count)
        fields["emailRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["chainText"] = draft.body

        return ShortcutNodeOutput(
            kind: .createEmailDraft,
            displayText: "Prepared 1 email draft. Review before opening Mail or sending.",
            fields: fields,
            emailDrafts: [draft],
            proposedActions: [action]
        )
    }

    private func prepareMessageHandoff(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let body = messageBody(from: input, text: text)
        let recipients = uniqueStrings(
            messageRecipients(from: input.variables, keys: ["recipient", "to", "phone", "smsTo", "messageTo"])
                + messageRecipients(from: text, prefixes: ["to:", "recipient:", "phone:", "sms:", "收件人:", "給:"])
        )
        let draft = MessageDraft(recipients: recipients, body: body)
        let action = AgentAction(
            kind: .openMessageHandoff,
            title: "Review Messages Handoff",
            rationale: "Shortcut requested a visible Messages recipient handoff. Kairo keeps the body in preview because Apple's SMS link does not carry body text.",
            payload: .message(draft),
            riskTier: .tier1Draft
        )

        var fields = baseFields(for: input)
        fields["messageHandoffCount"] = "1"
        fields["messageRecipient"] = draft.recipients.first ?? ""
        fields["messageRecipientCount"] = String(draft.recipients.count)
        fields["messageBody"] = draft.body
        fields["messageBodyInURL"] = "false"
        fields["messageRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["messageHandoffURL"] = messageHandoffURLPreview(for: draft.recipients)
        fields["chainText"] = draft.body

        return ShortcutNodeOutput(
            kind: .prepareMessageHandoff,
            displayText: "Messages handoff ready. Review in Kairo before opening Messages. No message has been sent.",
            fields: fields,
            proposedActions: [action]
        )
    }

    private func preparePhoneCallHandoff(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let phoneNumber = phoneNumber(from: input, text: text)
        let draft = PhoneCallDraft(
            phoneNumber: phoneNumber,
            label: phoneCallLabel(from: input, text: text),
            notes: text
        )
        let action = AgentAction(
            kind: .openPhoneCallHandoff,
            title: "Review Phone Call Handoff",
            rationale: "Shortcut requested a visible Phone handoff. Kairo opens only a tel: URL after user confirmation and does not place calls silently.",
            payload: .phoneCall(draft),
            riskTier: .tier1Draft
        )

        var fields = baseFields(for: input)
        fields["phoneCallHandoffCount"] = "1"
        fields["phoneCallLabel"] = draft.label ?? ""
        fields["phoneCallNumber"] = draft.phoneNumber
        fields["phoneCallURL"] = phoneCallURLPreview(for: draft.phoneNumber)
        fields["phoneCallRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["chainText"] = [draft.label, draft.phoneNumber]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " ")

        return ShortcutNodeOutput(
            kind: .preparePhoneCallHandoff,
            displayText: "Phone handoff ready. Review before opening Phone. No call has been placed.",
            fields: fields,
            phoneCallDrafts: [draft],
            proposedActions: [action]
        )
    }

    private func prepareWebSearchHandoff(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let query = webSearchQuery(from: input, text: text)
        let urlString = webSearchURLString(for: query)
        let draft = WebSearchDraft(query: query, searchURL: urlString)
        let action = AgentAction(
            kind: .openWebSearchHandoff,
            title: "Review Safari Search Handoff",
            rationale: "Shortcut requested a visible web search handoff. Kairo only prepares a URL preview and does not browse, scrape, or read web content silently.",
            payload: .webSearch(draft),
            riskTier: .tier1Draft
        )

        var fields = baseFields(for: input)
        fields["webSearchHandoffCount"] = "1"
        fields["webSearchQuery"] = draft.query
        fields["webSearchURL"] = draft.searchURL
        fields["webSearchRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["chainText"] = draft.query

        return ShortcutNodeOutput(
            kind: .prepareWebSearchHandoff,
            displayText: "Safari handoff ready. Review before opening Safari. No browsing has happened.",
            fields: fields,
            webSearchDrafts: [draft],
            proposedActions: [action]
        )
    }

    private func createRecipeDraft(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let recipes = KairoRecipePlanner().suggestRecipes(
            for: text,
            now: Date(timeIntervalSince1970: 0)
        )
        let primaryRecipe = recipes[0]
        var fields = baseFields(for: input)
        fields["recipeCount"] = String(recipes.count)
        fields["recipeID"] = primaryRecipe.id
        fields["recipeTitle"] = primaryRecipe.title
        fields["recipeStepCount"] = String(primaryRecipe.steps.count)
        fields["recipeRiskTier"] = primaryRecipe.riskTier.rawValue
        fields["recipeRequiresReview"] = "true"
        fields["chainText"] = primaryRecipe.summary
        fields["recipePreviewJSON"] = recipePreviewJSONString(primaryRecipe)

        return ShortcutNodeOutput(
            kind: .createRecipeDraft,
            displayText: "Prepared Kairo recipe draft: \(primaryRecipe.title). Review and enable in Kairo; this does not create Apple Shortcuts.",
            fields: fields,
            recipeDrafts: recipes
        )
    }

    private func draftReply(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tone = input.variables["tone"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "polite"
        let context = deterministicSummary(for: text)
        let replyDraft = """
        Thanks for the context. Kairo can help with this: \(context)

        I will review the details and follow up with the next step. No message has been sent automatically.
        """

        var fields = baseFields(for: input)
        fields["replyDraftTone"] = tone
        fields["replyDraft"] = replyDraft
        fields["chainText"] = replyDraft

        return ShortcutNodeOutput(
            kind: .draftReply,
            displayText: "Draft reply ready. Review before sending.",
            fields: fields
        )
    }

    private func summarize(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let summary = deterministicSummary(for: text)
        var fields = baseFields(for: input)
        fields["summary"] = summary
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .summarize,
            displayText: summary,
            fields: fields
        )
    }

    private func dailyBriefing(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["briefing"] = deterministicSummary(for: text)
        fields["taskCount"] = String(tasks.count)

        return ShortcutNodeOutput(
            kind: .dailyBriefing,
            displayText: "Briefing ready with \(tasks.count) suggested actions.",
            fields: fields,
            tasks: tasks
        )
    }

    private func previewHomeAction(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let request = homeControlRequest(from: input, fallbackText: text)
        let action = AgentAction(
            kind: .controlHome,
            title: homeActionTitle(for: request),
            rationale: "Shortcut requested a HomeKit preview. Kairo must show confirmation before any home write.",
            payload: .homeControl(request),
            riskTier: .tier3HighRiskExternal
        )

        var fields = baseFields(for: input)
        fields["homeActionCount"] = "1"
        fields["homeActionRiskTier"] = action.riskTier.rawValue
        fields["homeActionRequiresConfirmation"] = String(action.requiresConfirmation)
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .previewHomeAction,
            displayText: "Home action preview ready. Review in Kairo before any HomeKit write.",
            fields: fields,
            proposedActions: [action]
        )
    }

    private func ask(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let memories = try await memoryStore.search(query: text, limit: max(input.limit, 1))
        let memorySummary = memories.first?.summary
        let answer = memorySummary ?? deterministicSummary(for: text)
        var fields = baseFields(for: input)
        fields["answer"] = answer

        return ShortcutNodeOutput(
            kind: .ask,
            displayText: answer,
            fields: fields,
            memoryMatches: memories.map { ShortcutMemoryMatch(id: $0.id, title: $0.title, summary: $0.summary) }
        )
    }

    private func homeControlRequest(from input: ShortcutNodeInput, fallbackText: String) -> HomeControlRequest {
        let variables = input.variables
        let targetName = variables["targetName"]?.nilIfEmpty ?? inferredHomeTarget(from: fallbackText)
        let command = HomeControlCommand(rawValue: variables["command"]?.nilIfEmpty ?? "") ?? inferredHomeCommand(from: fallbackText)
        return HomeControlRequest(
            homeName: variables["homeName"]?.nilIfEmpty,
            roomName: variables["roomName"]?.nilIfEmpty,
            targetName: targetName,
            command: command,
            value: homeControlValue(from: variables["value"], command: command, text: fallbackText)
        )
    }

    private func inferredHomeTarget(from text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("lock") || lowercased.contains("door") {
            return "Front Door Lock"
        }
        if lowercased.contains("garage") {
            return "Garage Door"
        }
        if lowercased.contains("thermostat") || lowercased.contains("temperature") {
            return "Thermostat"
        }
        return "Desk Lamp"
    }

    private func inferredHomeCommand(from text: String) -> HomeControlCommand {
        let lowercased = text.lowercased()
        if lowercased.contains("scene") {
            return .runScene
        }
        if lowercased.contains("temperature") || lowercased.contains("thermostat") {
            return .setTargetTemperature
        }
        return .setPower
    }

    private func homeControlValue(from rawValue: String?, command: HomeControlCommand, text: String) -> HomeControlValue? {
        guard command != .runScene else { return nil }
        if let rawValue = rawValue?.nilIfEmpty {
            if let bool = Bool(rawValue.lowercased()) {
                return .bool(bool)
            }
            if let double = Double(rawValue) {
                return .double(double)
            }
            return .string(rawValue)
        }
        if command == .setTargetTemperature {
            return .double(22)
        }
        return .bool(!text.localizedCaseInsensitiveContains("off"))
    }

    private func homeActionTitle(for request: HomeControlRequest) -> String {
        switch request.command {
        case .runScene:
            return "Preview Home Scene: \(request.targetName)"
        case .setPower:
            return "Preview Home Power: \(request.targetName)"
        case .setBrightness:
            return "Preview Home Brightness: \(request.targetName)"
        case .setTargetTemperature:
            return "Preview Home Temperature: \(request.targetName)"
        }
    }

    private func baseFields(for input: ShortcutNodeInput) -> [String: String] {
        var fields = input.variables
        if let sourceName = input.sourceName {
            fields["sourceName"] = sourceName
        }
        return fields
    }

    private func validatedText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ShortcutNodeRuntimeError.emptyInput
        }
        return trimmed
    }

    private func title(for text: String) -> String {
        String(text.prefix(40))
    }

    private func calendarTitle(from text: String) -> String {
        let prefixes = [
            "event:",
            "meeting:",
            "calendar:",
            "create calendar event:",
            "add calendar event:",
            "行程:",
            "會議:"
        ]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0) }) else {
                continue
            }
            let title = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-"))
            if !title.isEmpty {
                return title
            }
        }
        return title(for: text)
    }

    private func calendarDate(named key: String, from variables: [String: String]) -> Date? {
        variables[key].flatMap(Self.iso8601Formatter.date(from:))
    }

    private func calendarDate(from text: String, prefixes: [String]) -> Date? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0) }) else {
                continue
            }
            let value = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = Self.iso8601Formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func emailSubject(from input: ShortcutNodeInput, text: String, body: String) -> String {
        input.variables["subject"]?.nilIfEmpty
            ?? input.variables["emailSubject"]?.nilIfEmpty
            ?? lineValue(from: text, prefixes: ["subject:", "主旨:"])
            ?? title(for: body.isEmpty ? text : body)
    }

    private func emailBody(from text: String) -> String {
        let metadataPrefixes = [
            "to:",
            "recipient:",
            "收件人:",
            "cc:",
            "bcc:",
            "subject:",
            "主旨:"
        ]
        let body = text
            .components(separatedBy: .newlines)
            .filter { line in
                let lowercased = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !metadataPrefixes.contains { lowercased.hasPrefix($0) }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? text : body
    }

    private func emailRecipients(from variables: [String: String], keys: [String]) -> [String] {
        keys
            .compactMap { variables[$0]?.nilIfEmpty }
            .flatMap(splitRecipients)
    }

    private func emailRecipients(from text: String, prefixes: [String]) -> [String] {
        guard let value = lineValue(from: text, prefixes: prefixes) else {
            return []
        }
        return splitRecipients(value)
    }

    private func contactNameParts(from input: ShortcutNodeInput, text: String) -> (given: String, family: String) {
        if let given = input.variables["givenName"]?.nilIfEmpty {
            return (given, input.variables["familyName"]?.nilIfEmpty ?? "")
        }

        let rawName = input.variables["name"]?.nilIfEmpty
            ?? input.variables["contactName"]?.nilIfEmpty
            ?? lineValue(from: text, prefixes: ["name:", "contact:", "姓名:", "名字:"])
            ?? title(for: text)
        let parts = rawName
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else {
            return (rawName, "")
        }
        return (first, parts.dropFirst().joined(separator: " "))
    }

    private func contactValues(from variables: [String: String], keys: [String]) -> [String] {
        keys
            .compactMap { variables[$0]?.nilIfEmpty }
            .flatMap(splitRecipients)
    }

    private func contactValues(from text: String, prefixes: [String]) -> [String] {
        guard let value = lineValue(from: text, prefixes: prefixes) else {
            return []
        }
        return splitRecipients(value)
    }

    private func contactNotes(from input: ShortcutNodeInput, text: String) -> String? {
        input.variables["notes"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? input.variables["contactNotes"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? lineValue(from: text, prefixes: ["notes:", "note:", "備註:"])
    }

    private func messageBody(from input: ShortcutNodeInput, text: String) -> String {
        if let body = input.variables["body"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? input.variables["messageBody"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? input.variables["reply"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return body
        }

        if let body = lineValue(from: text, prefixes: ["body:", "message:", "reply:", "正文:", "訊息:"]) {
            return body
        }

        let metadataPrefixes = [
            "to:",
            "recipient:",
            "phone:",
            "sms:",
            "收件人:",
            "給:"
        ]
        let body = text
            .components(separatedBy: .newlines)
            .filter { line in
                let lowercased = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !metadataPrefixes.contains { lowercased.hasPrefix($0) }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? text : body
    }

    private func messageRecipients(from variables: [String: String], keys: [String]) -> [String] {
        keys
            .compactMap { variables[$0]?.nilIfEmpty }
            .flatMap(splitRecipients)
    }

    private func messageRecipients(from text: String, prefixes: [String]) -> [String] {
        guard let value = lineValue(from: text, prefixes: prefixes) else {
            return []
        }
        return splitRecipients(value)
    }

    private func phoneNumber(from input: ShortcutNodeInput, text: String) -> String {
        input.variables["phoneNumber"]?.nilIfEmpty
            ?? input.variables["phone"]?.nilIfEmpty
            ?? input.variables["tel"]?.nilIfEmpty
            ?? input.variables["callTo"]?.nilIfEmpty
            ?? lineValue(from: text, prefixes: ["phone:", "tel:", "call:", "電話:", "手機:"])
            ?? inferredPhoneNumber(from: text)
            ?? ""
    }

    private func phoneCallLabel(from input: ShortcutNodeInput, text: String) -> String? {
        input.variables["label"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? input.variables["name"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? input.variables["contactName"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? lineValue(from: text, prefixes: ["name:", "contact:", "label:", "姓名:"])
    }

    private func inferredPhoneNumber(from text: String) -> String? {
        let allowedScalars = CharacterSet(charactersIn: "+-(). ")
            .union(.decimalDigits)
        let candidates = text
            .components(separatedBy: allowedScalars.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { candidate in
                let digitCount = candidate.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
                return digitCount >= 7
            }
        return candidates.first
    }

    private func splitRecipients(_ value: String) -> [String] {
        value
            .split { [",", ";", "\n"].contains(String($0)) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []
        for value in values {
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            unique.append(value)
        }
        return unique
    }

    private func messageHandoffURLPreview(for recipients: [String]) -> String {
        guard let rawRecipient = recipients.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawRecipient.isEmpty else {
            return "sms:"
        }

        let allowedScalars = CharacterSet(charactersIn: "+-().").union(.decimalDigits)
        let recipient = String(rawRecipient.unicodeScalars.filter { allowedScalars.contains($0) })
        return recipient.isEmpty ? "sms:" : "sms:\(recipient)"
    }

    private func phoneCallURLPreview(for phoneNumber: String) -> String {
        let sanitized = sanitizedDialString(from: phoneNumber)
        return sanitized.isEmpty ? "tel:" : "tel:\(sanitized)"
    }

    private func webSearchQuery(from input: ShortcutNodeInput, text: String) -> String {
        let explicitQuery = input.variables["query"]?.nilIfEmpty
            ?? input.variables["searchQuery"]?.nilIfEmpty
            ?? input.variables["q"]?.nilIfEmpty
            ?? input.query?.nilIfEmpty
            ?? lineValue(from: text, prefixes: ["query:", "search:", "搜尋:", "查詢:"])
        if let explicitQuery {
            return explicitQuery
        }

        let prefixes = [
            "search web for ",
            "search for ",
            "google ",
            "搜尋",
            "查詢"
        ]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        for prefix in prefixes where lowercased.hasPrefix(prefix) {
            let query = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-"))
            if !query.isEmpty {
                return query
            }
        }

        return trimmed
    }

    private func webSearchURLString(for query: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "duckduckgo.com"
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url?.absoluteString ?? "https://duckduckgo.com/"
    }

    private func sanitizedDialString(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                output.unicodeScalars.append(scalar)
            } else if scalar == "+", output.isEmpty {
                output.unicodeScalars.append(scalar)
            }
        }
        return output
    }

    private func lineValue(from text: String, prefixes: [String]) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0) }) else {
                continue
            }
            let value = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-"))
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func iso8601String(from date: Date) -> String {
        Self.iso8601Formatter.string(from: date)
    }

    private func deterministicSummary(for text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 180 else { return normalized }
        return "\(normalized.prefix(177))..."
    }

    private func extractTaskDrafts(from text: String) -> [ShortcutTaskDraft] {
        let prefixes = [
            "todo:",
            "action:",
            "reminder:",
            "task:",
            "- [ ]",
            "☐"
        ]

        return text
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased = trimmed.lowercased()
                guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0) }) else {
                    return nil
                }
                let title = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-"))
                guard !title.isEmpty else { return nil }
                return ShortcutTaskDraft(title: title, notes: "Extracted from Shortcut input.")
            }
    }

    private func recipePreviewJSONString(_ recipe: KairoRecipe) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(recipe),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static let defaultCalendarStartDate = Date(timeIntervalSince1970: 1_767_258_000)
    private static let iso8601Formatter = ISO8601DateFormatter()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
