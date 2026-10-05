import SwiftUI
import HALogik

/// "Was ist neu?": Änderungen der neuen (bzw. der letzten) Versionen und Installieren.
struct NeuigkeitenAnsicht: View {
    let akt: Aktualisierer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(akt.neueVersion.map { T("Version %1 ist da", "\($0)") } ?? T("Was ist neu?")).font(.title2.weight(.semibold))
                    Text(T("Installiert: %1", "\(akt.aktuelleVersion)")).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if akt.notizen.isEmpty {
                        Text(akt.zustand == .suche ? T("Suche nach Updates …") : T("Keine Änderungen gefunden."))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(akt.notizen) { n in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(n.titel == n.version || n.titel == "v" + n.version ? T("Version %1", "\(n.version)") : n.titel)
                                .font(.headline)
                            Text(markdown(n.text))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .karte(eckradius: 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()
            HStack(spacing: 10) {
                switch akt.zustand {
                case .laedt:
                    ProgressView().controlSize(.small)
                    Text(T("Wird geladen und geprüft …")).foregroundStyle(.secondary)
                case .installiert:
                    Text(T("Installiert – Home Assistant ToolBox startet neu …")).foregroundStyle(.secondary)
                case .fehler(let text):
                    Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                case .aktuell:
                    Label(T("Home Assistant ToolBox ist aktuell."), systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                default:
                    EmptyView()
                }
                Spacer()
                Link(T("Auf GitHub ansehen"), destination: akt.seite)
                if akt.updateDa {
                    Button(T("Installieren und neu starten")) { Task { await akt.installieren() } }
                        .glasKnopfBetont()
                        .disabled(akt.downloadURL == nil || akt.zustand == .laedt || akt.zustand == .installiert)
                } else {
                    Button(T("Nach Updates suchen")) { Task { await akt.pruefen() } }
                        .glasKnopf()
                        .disabled(akt.zustand == .suche)
                }
            }
            .font(.callout)
            .padding(14)
        }
        .frame(width: 520, height: 520)
    }

    /// Release-Text (Markdown von GitHub) mit Zeilenumbrüchen und Aufzählungen
    private func markdown(_ text: String) -> AttributedString {
        let vorbereitet = text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                let z = zeile.trimmingCharacters(in: .whitespaces)
                if z.hasPrefix("- ") || z.hasPrefix("* ") { return "•  " + z.dropFirst(2) }
                if z.hasPrefix("#") { return "**" + z.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces) + "**" }
                return String(zeile)
            }
            .joined(separator: "\n")
        let optionen = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: vorbereitet, options: optionen)) ?? AttributedString(text)
    }
}
