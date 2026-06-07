import Foundation

public enum InfoPageHTMLRenderer {
    private static let css = """
    :root{--c1:#1a1a2e;--c2:#16213e;--c3:#0f3460;--c4:#e94560;--c5:#f5f5f5;--c6:#fff;--c7:#7f8c8d}
    *{box-sizing:border-box;margin:0;padding:0}body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:linear-gradient(135deg,var(--c1),var(--c2));color:var(--c5);padding:20px;min-height:100vh}
    .container{max-width:700px;margin:0 auto}
    .hdr{padding:30px;border-radius:16px 16px 0 0;text-align:center}
    .hdr h1{font-size:24px;margin-bottom:6px;color:var(--c6)}
    .hdr .sub{font-size:13px;opacity:.8}
    .badge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:600;margin-top:8px}
    .badge-c{background:rgba(46,204,113,.2);color:#2ecc71;border:1px solid #2ecc71}
    .badge-p{background:rgba(241,196,15,.2);color:#f1c40f;border:1px solid #f1c40f}
    .card{background:var(--c2);padding:20px;border-radius:0}
    .card:last-child{border-radius:0 0 16px 16px}
    .card+.card{border-top:1px solid rgba(255,255,255,.05)}
    .card h3{font-size:13px;color:var(--c7);text-transform:uppercase;letter-spacing:1px;margin-bottom:12px}
    .row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid rgba(255,255,255,.04)}
    .lbl{color:var(--c7);font-size:12px}.val{font-size:13px;font-weight:500;text-align:right;color:var(--c6)}
    .price{font-size:24px;font-weight:700;text-align:center;margin:10px 0}
    .fb{background:rgba(15,52,96,.5);border-radius:8px;padding:14px;margin:8px 0}
    .fr{display:flex;justify-content:space-between;align-items:center;gap:10px}
    .rc{text-align:center}.rc .ct{font-size:16px;font-weight:700;color:var(--c6)}.rc .tm{font-size:11px;color:var(--c7);margin-top:2px}
    .rl{flex:1;height:2px;position:relative}
    .rl::after{content:'\\2708';position:absolute;top:-12px;right:-10px;font-size:16px}
    .tl{position:relative;padding-left:20px}.tl::before{content:'';position:absolute;left:6px;top:0;bottom:0;width:2px;background:var(--c3)}
    .ti{position:relative;padding:6px 0}.ti::before{content:'';position:absolute;left:-18px;top:10px;width:8px;height:8px;border-radius:50%}
    .td{font-size:10px;color:var(--c7)}.te{font-size:13px;margin-top:1px}
    .sb{background:rgba(233,69,96,.1);border:1px solid rgba(233,69,96,.2);border-radius:8px;padding:12px;margin-top:10px;font-size:12px;color:var(--c6);line-height:1.5}
    .tag{display:inline-block;padding:2px 8px;border-radius:4px;font-size:10px;margin:2px;background:var(--c3);color:var(--c5)}
    .items{font-size:12px;color:var(--c6);padding:4px 0;line-height:1.6}
    """

    private static let accentColors: [InfoPageCategory: String] = [
        .travel: "linear-gradient(135deg,#e94560,#ff6b6b)",
        .order: "linear-gradient(135deg,#3498db,#2ecc71)",
        .event: "linear-gradient(135deg,#9b59b6,#e74c3c)",
        .medical: "linear-gradient(135deg,#2ecc71,#27ae60)",
        .project: "linear-gradient(135deg,#f39c12,#e67e22)",
        .finance: "linear-gradient(135deg,#1abc9c,#16a085)",
        .warranty: "linear-gradient(135deg,#34495e,#2c3e50)",
        .identityDocument: "linear-gradient(135deg,#8e44ad,#6c3483)",
        .homeDevice: "linear-gradient(135deg,#e67e22,#d35400)",
        .subscription: "linear-gradient(135deg,#2980b9,#1a5276)",
        .recipeOrInstruction: "linear-gradient(135deg,#27ae60,#1e8449)",
        .generalNote: "linear-gradient(135deg,#7f8c8d,#636e72)",
    ]

    private static let timelineDotColors: [InfoPageCategory: String] = [
        .travel: "#e94560", .order: "#2ecc71", .event: "#e74c3c",
        .medical: "#2ecc71", .finance: "#16a085", .project: "#e67e22",
    ]

    public static func render(_ page: InfoPage) -> String {
        let headerGradient = accentColors[page.category] ?? accentColors[.generalNote]!
        let dotColor = timelineDotColors[page.category] ?? "#e94560"
        let tlGradient = "linear-gradient(90deg,\(dotColor),transparent)"
        let badgeClass = ["confirmed", "shipped", "delivered", "completed"].contains(page.status ?? "") ? "badge-c" : "badge-p"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let factsHTML = page.facts.map { fact in
            "<div class=\"row\"><span class=\"lbl\">\(escaping(fact.label))</span><span class=\"val\">\(escaping(fact.value))</span></div>"
        }.joined()

        let timelineHTML: String
        if page.timeline.isEmpty {
            timelineHTML = ""
        } else {
            let items = page.timeline.map { item in
                let dateStr = item.date.map { dateFormatter.string(from: $0) } ?? ""
                let desc = item.note ?? item.title
                return "<div class=\"ti\"><div class=\"td\">\(escaping(dateStr))</div><div class=\"te\">\(escaping(desc))</div></div>"
            }.joined()
            timelineHTML = "<h3>Timeline</h3><div class=\"tl\">\(items)</div>"
        }

        let flightBlock: String
        if page.category == .travel {
            let depFact = page.facts.first(where: { $0.label.lowercased().contains("depart") })
            let arrFact = page.facts.first(where: { $0.label.lowercased().contains("arriv") })
            if depFact != nil || arrFact != nil {
                let origin = depFact?.value ?? "Origin"
                let dest = arrFact?.value ?? "Destination"
                let deptime = page.facts.first(where: { $0.label.lowercased() == "departure" })?.value ?? ""
                let arrtime = page.facts.first(where: { $0.label.lowercased() == "arrival" })?.value ?? ""
                flightBlock = """
                <div class=\"fb\"><div class=\"fr\">
                <div class=\"rc\"><div class=\"ct\">\(escaping(origin))</div><div class=\"tm\">\(escaping(deptime))</div></div>
                <div class=\"rl\" style=\"background:\(tlGradient)\"></div>
                <div class=\"rc\"><div class=\"ct\">\(escaping(dest))</div><div class=\"tm\">\(escaping(arrtime))</div></div>
                </div></div>
                """
            } else {
                flightBlock = ""
            }
        } else {
            flightBlock = ""
        }

        let priceBlock: String
        if page.category == .order, let amountFact = page.facts.first(where: { $0.label.lowercased() == "amount" || $0.label.lowercased().contains("total") }) {
            priceBlock = "<div class=\"price\">\(escaping(amountFact.value))</div>"
        } else {
            priceBlock = ""
        }

        let tagsHTML: String
        let tags = [
            page.category.rawValue,
            page.templateID.rawValue,
            page.status.map { $0 }
        ].compactMap { $0 }
        tagsHTML = tags.map { "<span class=\"tag\">\(escaping($0))</span>" }.joined()

        let reminderHTML: String
        if page.reminderLinks.isEmpty {
            reminderHTML = ""
        } else {
            let items = page.reminderLinks.map { link in
                let dueStr = link.dueDate.map { " · Due \(dateFormatter.string(from: $0))" } ?? ""
                return "<div class=\"ti\"><div class=\"te\">\(escaping(link.title))\(escaping(dueStr))</div></div>"
            }.joined()
            reminderHTML = "<h3>Reminders</h3><div class=\"tl\">\(items)</div>"
        }

        return """
        <!DOCTYPE html><html lang="en">
        <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(escaping(page.title))</title>
        <style>\(css)</style></head><body>
        <div class="container">
        <div class="hdr" style="background:\(headerGradient)"><h1>\(escaping(page.title))</h1><div class="sub">\(escaping(page.subtitle))</div><div class="badge \(badgeClass)">\(escaping(page.status ?? "draft"))</div></div>
        <div class="card">\(flightBlock)\(priceBlock)\(factsHTML)\(tagsHTML.isEmpty ? "" : "<div style=\"margin-top:10px\">\(tagsHTML)</div>")</div>
        <div class="card">\(timelineHTML)</div>
        \(reminderHTML.isEmpty ? "" : "<div class=\"card\">\(reminderHTML)</div>")
        <div class="card"><div class="sb">\(escaping(page.summary))</div></div>
        </div></body></html>
        """
    }

    private static func escaping(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private extension InfoPage {
    var subtitle: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let count = assetIDs.count
        let assetLabel = count == 1 ? "asset" : "assets"
        return "\(count) \(assetLabel) · Created \(dateFormatter.string(from: createdAt))"
    }

    var status: String? {
        reminderLinks.first?.status.rawValue
    }
}
