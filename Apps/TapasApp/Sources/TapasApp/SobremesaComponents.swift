import AppKit
import SwiftUI
import TapasCore

// MARK: - Buttons (Sobremesa: printed buttons sink when pressed)

struct PrintedButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, ink }
    var kind: Kind = .primary
    var small = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let shape = CutShape(tight: small ? 4 : 5, round: small ? 14 : 18)
        let offset = small ? CGSize(width: 2, height: 3) : CGSize(width: 3, height: 4)
        return Group {
            if kind == .quiet {
                configuration.label
                    .font(.system(size: small ? 12.5 : 14, weight: .semibold))
                    .padding(.vertical, small ? 3 : 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(Sobremesa.ink).frame(height: 1.6) }
                    .foregroundStyle(Sobremesa.ink)
                    .opacity(pressed ? 0.6 : 1)
            } else {
                configuration.label
                    .font(.system(size: small ? 12.5 : 14, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, small ? 12 : 18).padding(.vertical, small ? 7 : 11)
                    .foregroundStyle(kind == .ink ? Sobremesa.paperOnInk : Sobremesa.ink)
                    .background(shape.fill(fill))
                    .overlay(shape.inkBorder(kind == .ink ? .clear : Sobremesa.ink, lineWidth: small ? 1.4 : Sobremesa.outline))
                    .offset(pressed ? offset : .zero)
                    .background(shape.fill(kind == .ink ? Sobremesa.deepInk : Sobremesa.ink).offset(offset))
            }
        }
        .opacity(isEnabled ? 1 : 0.42)
        .contentShape(Rectangle())
    }

    private var fill: Color {
        switch kind {
        case .primary: Sobremesa.saffron
        case .secondary, .quiet: Sobremesa.paper
        case .ink: Sobremesa.ink
        }
    }
}

extension ButtonStyle where Self == PrintedButtonStyle {
    static func printed(_ kind: PrintedButtonStyle.Kind = .primary, small: Bool = false) -> PrintedButtonStyle {
        PrintedButtonStyle(kind: kind, small: small)
    }
}

// MARK: - Pick toggle: a piece slides onto its pick when on

struct PickToggle: View {
    @Binding var isOn: Bool
    var color: Color = Sobremesa.olive
    var label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(Sobremesa.ink).frame(width: 42, height: 2)
                let piece = CutShape(tight: 3, round: 8)
                piece.fill(Sobremesa.ink).frame(width: 22, height: 17).offset(x: 2, y: 3)
                    .rotationEffect(.degrees(isOn ? -19 : 0)).offset(x: isOn ? 18 : 0)
                piece.fill(isOn ? color : Sobremesa.paper).frame(width: 22, height: 17)
                    .overlay(piece.inkBorder(Sobremesa.ink, lineWidth: 1.4))
                    .rotationEffect(.degrees(isOn ? -19 : 0)).offset(x: isOn ? 18 : 0)
            }
            .frame(width: 44, height: 26, alignment: .leading)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55), value: isOn)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: - Keycaps: a shortcut shown as printed keys, with a menu to change it

struct Keycaps: View {
    var label: String
    var recording = false
    var large = false
    var body: some View {
        if recording {
            Text("Press new keys · esc")
                .font(.system(size: large ? 14 : 12.5, weight: .semibold))
                .padding(.horizontal, 11).padding(.vertical, large ? 9 : 6)
                .printed(CutShape(tight: 3, round: 10), fill: Sobremesa.saffron, offset: CGSize(width: 2, height: 3))
                .foregroundStyle(Sobremesa.ink)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(Self.keys(label).enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.system(size: large ? 16 : 12.5, weight: .semibold))
                        .frame(minWidth: large ? 34 : 26, minHeight: large ? 34 : 26)
                        .padding(.horizontal, key.count > 2 ? 6 : 0)
                        .printed(CutShape(tight: 3, round: large ? 11 : 9), offset: CGSize(width: 2, height: 3))
                        .foregroundStyle(Sobremesa.ink)
                }
            }
        }
    }

    /// "⌃⌥" → ["⌃", "⌥"]; "Right ⌘" stays one key; "⌃⇧M" → ["⌃", "⇧", "M"].
    static func keys(_ label: String) -> [String] {
        if label.hasPrefix("Right ") || label.contains(" ") { return [label] }
        let modifiers = Set("⌃⌥⇧⌘")
        var result: [String] = []
        var rest = ""
        for character in label {
            if modifiers.contains(character) { result.append(String(character)) } else { rest.append(character) }
        }
        if !rest.isEmpty { result.append(rest) }
        return result.isEmpty ? [label] : result
    }
}

/// Keycaps that open a small menu: record a new shortcut, or pick a known one.
struct ShortcutMenu: View {
    var label: String
    var recording: Bool
    var accessibilityName: String
    var presets: [(String, () -> Void)]
    var record: () -> Void
    var large = false

    var body: some View {
        Menu {
            Button("Record a new shortcut…", action: record)
            if !presets.isEmpty { Divider() }
            ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                Button(preset.0, action: preset.1)
            }
        } label: {
            Keycaps(label: label, recording: recording, large: large)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel("\(accessibilityName) shortcut, \(label)")
        .accessibilityHint("Opens choices to change it")
    }
}

// MARK: - Labels and rows

struct GroupLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.3)
            .foregroundStyle(Sobremesa.muted)
    }
}

/// A settings sentence: optional switch, the sentence in Fraunces, and anything below it.
struct RuleRow<Sentence: View, Below: View, Trailing: View>: View {
    var toggle: Binding<Bool>?
    var toggleColor: Color = Sobremesa.olive
    var toggleLabel = ""
    @ViewBuilder var sentence: () -> Sentence
    @ViewBuilder var below: () -> Below
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let toggle { PickToggle(isOn: toggle, color: toggleColor, label: toggleLabel) }
                else { Spacer(minLength: 0) }
            }.frame(width: 44, height: 26)
            VStack(alignment: .leading, spacing: 8) {
                sentence()
                    .font(Sobremesa.display(17))
                    .foregroundStyle(Sobremesa.ink)
                    .opacity(toggle?.wrappedValue == false ? 0.45 : 1)
                    .fixedSize(horizontal: false, vertical: true)
                below()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Sobremesa.ink.opacity(0.14)).frame(height: 1) }
    }
}

extension RuleRow where Below == EmptyView, Trailing == EmptyView {
    init(toggle: Binding<Bool>? = nil, toggleColor: Color = Sobremesa.olive, toggleLabel: String = "", @ViewBuilder sentence: @escaping () -> Sentence) {
        self.init(toggle: toggle, toggleColor: toggleColor, toggleLabel: toggleLabel, sentence: sentence, below: { EmptyView() }, trailing: { EmptyView() })
    }
}

struct Notice: View {
    var text: String
    var error = false
    var body: some View {
        Text(text).font(.system(size: 12.5)).foregroundStyle(Sobremesa.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .printed(CutShape(tight: 3, round: 12), fill: error ? Sobremesa.paprikaTint : Sobremesa.oliveTint, offset: CGSize(width: 2, height: 3))
    }
}

struct DoneMark: View {
    var text: String
    var body: some View {
        HStack(spacing: 8) {
            CutShape(tight: 2, round: 4).fill(Sobremesa.olive)
                .overlay(CutShape(tight: 2, round: 4).inkBorder(Sobremesa.ink, lineWidth: 1.3))
                .frame(width: 14, height: 9).rotationEffect(.degrees(-19))
            Text(text).font(.system(size: 13, weight: .semibold))
        }.foregroundStyle(Sobremesa.ink)
    }
}

extension Sobremesa {
    static let cobaltTint = Color(red: 0xC9 / 255, green: 0xD1 / 255, blue: 0xF0 / 255)
    static let paprikaTint = Color(red: 0xF6 / 255, green: 0xC4 / 255, blue: 0xB2 / 255)
    static let oliveTint = Color(red: 0xD8 / 255, green: 0xDD / 255, blue: 0xBA / 255)
}

// MARK: - What you kept: recordings without titles

/// One saved recording, described by what it is: when, first words, kind, length, languages, shape.
struct KeptItem: Identifiable, Equatable {
    var entry: HistoryEntry
    var id: URL { entry.url }
    var isMeeting: Bool
    var duration: Double?
    var languages: [String]
    var firstWords: String
    var turns: [RecordingTurn]

    init(_ entry: HistoryEntry) {
        self.entry = entry
        let front = Self.frontmatter(entry.markdown)
        isMeeting = front["tool"] == "acta"
        duration = front["duration_seconds"].flatMap(Double.init)
        languages = (front["languages"] ?? front["language"] ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")).uppercased() }
            .filter { !$0.isEmpty }
        turns = Self.turns(entry.text, isMeeting: isMeeting)
        firstWords = turns.first(where: { !$0.text.isEmpty })?.text ?? entry.title
    }

    var meta: String {
        var parts = [isMeeting ? "Meeting" : "Take"]
        if let duration { parts.append(Self.length(duration)) }
        if !languages.isEmpty { parts.append(languages.prefix(3).joined(separator: " ")) }
        return parts.joined(separator: " · ")
    }

    static func length(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s) s" }
        if s < 3600 { return s % 60 == 0 || s >= 600 ? "\(s / 60) min" : "\(s / 60) min \(s % 60) s" }
        return "\(s / 3600) h \(s % 3600 / 60) min"
    }

    static func frontmatter(_ markdown: String) -> [String: String] {
        guard markdown.hasPrefix("---\n"), let end = markdown.range(of: "\n---\n", range: markdown.index(markdown.startIndex, offsetBy: 4)..<markdown.endIndex) else { return [:] }
        var values: [String: String] = [:]
        for line in markdown[markdown.index(markdown.startIndex, offsetBy: 4)..<end.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            values[String(line[..<colon]).trimmingCharacters(in: .whitespaces)] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return values
    }

    /// Acta lines look like `[00:00:10] **Microphone**: text`. Dictado text is a single voice.
    static func turns(_ text: String, isMeeting: Bool) -> [RecordingTurn] {
        guard isMeeting else {
            let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return words.isEmpty ? [] : [RecordingTurn(start: 0, mine: true, text: words)]
        }
        return text.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return nil }
            let stamp = line[line.index(after: line.startIndex)..<close].split(separator: ":").compactMap { Double($0) }
            let start = stamp.reduce(0) { $0 * 60 + $1 }
            let rest = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard rest.hasPrefix("**"), let labelEnd = rest.range(of: "**:", range: rest.index(rest.startIndex, offsetBy: 2)..<rest.endIndex) else { return nil }
            let label = rest[rest.index(rest.startIndex, offsetBy: 2)..<labelEnd.lowerBound]
            let words = rest[labelEnd.upperBound...].trimmingCharacters(in: .whitespaces)
            return RecordingTurn(start: start, mine: label.lowercased().contains("microphone"), text: words)
        }
    }

    /// Columns for the shape: how much you and others said in each slice of the recording.
    func shape(columns requested: Int? = nil) -> [(mine: Double, others: Double)] {
        let total = max(duration ?? 0, (turns.last?.start ?? 0) + 5, 1)
        let columns = requested ?? Int(min(30, max(4, (4 + 26 * log10(1 + total / 60) / log10(61)).rounded())))
        var bins = Array(repeating: (mine: 0.0, others: 0.0), count: columns)
        for (index, turn) in turns.enumerated() {
            let end = index + 1 < turns.count ? turns[index + 1].start : total
            let words = Double(turn.text.split(separator: " ").count)
            let first = min(columns - 1, Int(turn.start / total * Double(columns)))
            let last = min(columns - 1, max(first, Int(max(turn.start, end - 0.001) / total * Double(columns))))
            let share = words / Double(last - first + 1)
            for column in first...last {
                if turn.mine { bins[column].mine += share } else { bins[column].others += share }
            }
        }
        let peak = max(1, bins.map { max($0.mine, $0.others) }.max() ?? 1)
        return bins.map { ($0.mine / peak, $0.others / peak) }
    }
}

struct RecordingTurn: Equatable {
    var start: Double
    var mine: Bool
    var text: String
}

/// The recording's shape on a thin ink pick: you above, others below.
struct RecordingShapeView: View {
    var columns: [(mine: Double, others: Double)]
    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            let step: CGFloat = 4
            context.fill(Path(roundedRect: CGRect(x: 0, y: mid - 0.8, width: CGFloat(columns.count) * step, height: 1.6), cornerRadius: 0.8), with: .color(Sobremesa.ink))
            for (i, column) in columns.enumerated() {
                let x = CGFloat(i) * step
                if column.mine > 0.02 {
                    let h = max(2, CGFloat(column.mine) * (mid - 3))
                    context.fill(Path(roundedRect: CGRect(x: x, y: mid - 2 - h, width: 2.6, height: h), cornerRadius: 1.3), with: .color(Sobremesa.cobalt))
                }
                if column.others > 0.02 {
                    let h = max(2, CGFloat(column.others) * (mid - 3))
                    context.fill(Path(roundedRect: CGRect(x: x, y: mid + 2, width: 2.6, height: h), cornerRadius: 1.3), with: .color(Sobremesa.paprika))
                }
            }
        }
        .frame(width: CGFloat(columns.count) * 4, height: 32)
        .accessibilityHidden(true)
    }
}

/// Assistant skill presence: an assistant counts as on this Mac when its home folder exists.
enum AssistantPresence {
    static func folder(for host: AssistantHost, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        switch host {
        case .claude: home.appendingPathComponent(".claude")
        case .codex: home.appendingPathComponent(".codex")
        case .cursor: home.appendingPathComponent(".cursor")
        }
    }
    static func isPresent(_ host: AssistantHost, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        FileManager.default.fileExists(atPath: folder(for: host, home: home).path)
    }
}
