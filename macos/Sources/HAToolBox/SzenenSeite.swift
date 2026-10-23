import SwiftUI
import HALogik

/// Reiter "Szenen": Szenen und Skripte als Kacheln – ein Klick startet sie.
struct SzenenSeite: View {
    let ha: HaVerbindung
    @State private var gestartet: String?
    @State private var haekchenTask: Task<Void, Never>?

    private let spalten = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            // Uhrzeit für „zuletzt vor 3 h“ – jede Minute neu
            TimelineView(.everyMinute) { kontext in
                LazyVStack(spacing: 8) {
                    UebersichtKarte(symbol: "wand.and.stars",
                                    titel: T("%1 Szenen · %2 Skripte", "\(ha.szenen.count)", "\(ha.skripte.count)"),
                                    untertitel: T("Ein Klick startet sie"),
                                    anteil: 0, farbe: .accentColor) { EmptyView() }
                    if !ha.szenen.isEmpty {
                        Abschnitt(titel: T("Szenen"), symbol: "wand.and.stars", anzahl: ha.szenen.count)
                        LazyVGrid(columns: spalten, spacing: 8) {
                            ForEach(ha.szenen) { s in kachel(s, symbol: "wand.and.stars", untertitel: szenenText(s, kontext.date)) }
                        }
                    }
                    if !ha.skripte.isEmpty {
                        Abschnitt(titel: T("Skripte"), symbol: "play.circle", anzahl: ha.skripte.count)
                        LazyVGrid(columns: spalten, spacing: 8) {
                            ForEach(ha.skripte) { s in
                                let laeuft = Logik.istAn(ha.zustaende[s.id])
                                kachel(s, symbol: "play.fill", untertitel: verfuegbar(s) ? (laeuft ? T("läuft …") : "") : T("nicht erreichbar"), aktiv: laeuft)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 2)
            }
        }
    }

    private func verfuegbar(_ s: Startbar) -> Bool { Logik.istVerfuegbar(ha.zustaende[s.id]) }

    /// Der Zustand einer Szene ist der Zeitpunkt, zu dem sie zuletzt aktiviert wurde.
    private func szenenText(_ s: Startbar, _ jetzt: Date) -> String {
        guard verfuegbar(s) else { return T("nicht erreichbar") }
        let vor = Logik.formatVor(Logik.datum(ha.zustaende[s.id]?.state ?? ""), jetzt: jetzt)
        return vor.isEmpty ? "" : T("zuletzt %1", vor)
    }

    private func kachel(_ s: Startbar, symbol: String, untertitel: String, aktiv: Bool = false) -> some View {
        let fertig = gestartet == s.id
        return Button {
            ha.starte(s.id)
            withAnimation(.snappy) { gestartet = s.id }
            haekchenTask?.cancel()
            haekchenTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                if !Task.isCancelled { withAnimation(.snappy) { gestartet = nil } }
            }
        } label: {
            HStack(spacing: 10) {
                SymbolKreis(symbol: fertig ? "checkmark" : symbol, farbe: fertig || aktiv ? .accentColor : nil, verfuegbar: verfuegbar(s))
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.name).font(.callout.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    if !untertitel.isEmpty {
                        Text(untertitel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!verfuegbar(s))
        .karte(farbe: fertig || aktiv ? Color.accentColor.opacity(0.2) : nil)
        .anheben()
        .help(T("%1 starten", s.name))
        .accessibilityLabel(T("%1 starten", s.name))
    }
}
