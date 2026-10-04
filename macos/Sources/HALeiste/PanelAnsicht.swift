import SwiftUI
import HALogik

enum Reiter: Int, CaseIterable, Identifiable {
    case lampen, steckdosen, heizung, energie, personen
    var id: Int { rawValue }
    var titel: String {
        switch self {
        case .lampen: "Lampen"
        case .steckdosen: "Steckdosen"
        case .heizung: "Heizung"
        case .energie: "Energie"
        case .personen: "Personen"
        }
    }
    var symbol: String {
        switch self {
        case .lampen: "lightbulb.fill"
        case .steckdosen: "poweroutlet.type.f.fill"
        case .heizung: "heater.vertical.fill"
        case .energie: "bolt.fill"
        case .personen: "person.2.fill"
        }
    }
}

/// Was im Panel gerade offen ist – bleibt beim Schließen und Öffnen erhalten.
@MainActor
@Observable
final class PanelZustand {
    var reiter: Reiter = .lampen
    var offen: Set<String> = []
    var einzelneLampenOffen = true
    var einzelneSteckdosenOffen = false

    func umschalten(_ schluessel: String) {
        if offen.contains(schluessel) { offen.remove(schluessel) } else { offen.insert(schluessel) }
    }
}

/// Das Fenster unter dem Menüleisten-Symbol.
struct PanelAnsicht: View {
    let kern: Kern
    var einrichten: () -> Void
    var neuigkeiten: () -> Void = {}
    private var ha: HaVerbindung { kern.ha }
    private var einstellungen: Einstellungen { kern.einstellungen }
    private var zustand: PanelZustand { kern.panel }

    /// Sichtbare Reiter (Heizung/Personen nur, wenn es etwas zu zeigen gibt)
    private var reiter: [Reiter] {
        Reiter.allCases.filter { r in
            switch r {
            case .heizung: einstellungen.zeigeHeizung && !ha.heizungen.isEmpty
            case .personen: einstellungen.zeigePersonen && !ha.personen.isEmpty
            default: true
            }
        }
    }

    @Namespace private var reiterRaum

    var body: some View {
        VStack(spacing: 0) {
            kopf
            // Update verfügbar
            if let v = kern.aktualisierer.neueVersion {
                Button(action: neuigkeiten) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
                        Text("Version \(v) ist verfügbar").font(.callout.weight(.medium))
                        Spacer()
                        Text("Was ist neu?").font(.callout).foregroundStyle(Color.accentColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .karte(farbe: Color.accentColor.opacity(0.18), eckradius: 12)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if !ha.meldung.isEmpty {
                Label(ha.meldung, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .karte(farbe: .orange.opacity(0.6), eckradius: 12)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Group {
                if !ha.eingerichtet {
                    platzhalter(symbol: "house.and.flag", titel: "Mit Home Assistant verbinden",
                                text: "Adresse und Zugriffstoken in den Einstellungen eintragen.",
                                knopf: "Einrichten …", aktion: einrichten)
                } else if !ha.verbunden && ha.zustaende.isEmpty {
                    if ha.laedt && ha.fehler.isEmpty {
                        ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        platzhalter(symbol: ha.abgelehnt ? "key.slash" : "wifi.exclamationmark",
                                    titel: ha.abgelehnt ? "Zugriff verweigert" : "Keine Verbindung",
                                    text: ha.abgelehnt ? "Home Assistant hat den Token abgelehnt. Bitte in den Einstellungen einen neuen eintragen."
                                        : ha.fehler.isEmpty ? "Home Assistant antwortet nicht." : ha.fehler,
                                    knopf: ha.abgelehnt ? "Einstellungen …" : "Erneut versuchen",
                                    aktion: ha.abgelehnt ? einrichten : { ha.erneutVersuchen() })
                    }
                } else {
                    switch reiter.contains(zustand.reiter) ? zustand.reiter : .lampen {
                    case .lampen: LampenSeite(ha: ha, einstellungen: einstellungen, zustand: zustand)
                    case .steckdosen: SteckdosenSeite(ha: ha, zustand: zustand)
                    case .heizung: HeizungSeite(kern: kern)
                    case .energie: EnergieSeite(ha: ha, einstellungen: einstellungen, instanz: kern.aktiv)
                    case .personen: PersonenSeite(ha: ha)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            fuss
        }
        .frame(width: 470, height: 700)
        .environment(\.locale, Locale(identifier: "de_DE"))
        .animation(.snappy, value: ha.meldung)
        .onAppear { ha.sichtbar = true }
        .onDisappear { ha.sichtbar = false }
    }

    // MARK: Kopf: Reiter als Glasleiste + Knöpfe

    private var kopf: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(reiter) { r in reiterKnopf(r) }
            }
            .padding(3)
            .glas(Capsule())

            Spacer(minLength: 4)

            GlasGruppe(abstand: 6) {
                HStack(spacing: 6) {
                    Menu {
                        if einstellungen.instanzen.count > 1 {
                            Menu("Instanz wechseln") {
                                ForEach(einstellungen.instanzen) { i in
                                    Button {
                                        kern.wechseln(i.id)
                                    } label: {
                                        if i.id == kern.aktiv?.id { Label(i.anzeigename + (i.favorit ? "  ★" : ""), systemImage: "checkmark") }
                                        else { Text(i.anzeigename + (i.favorit ? "  ★" : "")) }
                                    }
                                }
                            }
                            Divider()
                        }
                        Button("Aktualisieren") { ha.erneutVersuchen() }
                            .keyboardShortcut("r")
                        Divider()
                        Button("Home Assistant öffnen") { if let u = URL(string: ha.basis) { NSWorkspace.shared.open(u) } }
                            .disabled(!ha.eingerichtet)
                        Button("Alle Lampen aus") { ha.alleLichterAus() }
                            .disabled(ha.lichterAn == 0)
                        Divider()
                        Button(kern.aktualisierer.neueVersion.map { "Update auf \($0) …" } ?? "Was ist neu?") {
                            if kern.aktualisierer.notizen.isEmpty { Task { await kern.aktualisierer.pruefen() } }
                            neuigkeiten()
                        }
                        Button("Nach Updates suchen") {
                            Task { await kern.aktualisierer.pruefen() }
                            neuigkeiten()
                        }
                        Divider()
                        Button("Einstellungen …", action: einrichten)
                            .keyboardShortcut(",")
                        Divider()
                        Button("HA Leiste beenden") { NSApp.terminate(nil) }
                            .keyboardShortcut("q")
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuIndicator(.hidden)
                    .help("Mehr")
                }
                .labelStyle(.iconOnly)
                .glasKnopf()
                .buttonBorderShape(.circle)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func reiterKnopf(_ r: Reiter) -> some View {
        let gewaehlt = zustand.reiter == r
        let anzahl: Int? = switch r {
        case .lampen: ha.lichterAn
        case .steckdosen: ha.schalterAn
        case .heizung: ha.heizungen.filter { Logik.raumKlima($0, ha.zustaende).heizt }.count
        case .energie: nil
        case .personen: ha.personen.filter { $0.zustand == "home" }.count
        }
        return Button {
            withAnimation(.snappy(duration: 0.3)) { zustand.reiter = r }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: r.symbol).font(.system(size: 12, weight: .semibold))
                // Bei fünf Reitern nur beim gewählten den Namen zeigen
                if gewaehlt || reiter.count <= 3 {
                    Text(r.titel)
                        .font(.system(size: 12, weight: gewaehlt ? .semibold : .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
                if let anzahl, anzahl > 0 {
                    Text("\(anzahl)")
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(gewaehlt ? Color.white.opacity(0.3) : Color.accentColor.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(gewaehlt ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background {
                if gewaehlt {
                    Capsule()
                        .fill(Color.accentColor.gradient)
                        .shadow(color: .accentColor.opacity(0.35), radius: 4, y: 1)
                        .matchedGeometryEffect(id: "auswahl", in: reiterRaum)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(r.rawValue + 1)")), modifiers: .command)
        .help("\(r.titel) (⌘\(r.rawValue + 1))")
        .accessibilityLabel(r.titel)
    }

    // MARK: Fuß: Verbindungsstatus

    private var fuss: some View {
        HStack(spacing: 6) {
            LivePunkt(farbe: ha.live ? .green : ha.verbunden ? .yellow : .red, pulsiert: ha.live)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(alignment: .top) { Divider().opacity(0.5) }
    }

    private var statusText: String {
        if !ha.eingerichtet { return "Nicht eingerichtet" }
        // Bei mehreren Instanzen deren Namen zeigen, sonst den Rechner
        let host = einstellungen.instanzen.count > 1 ? (kern.aktiv?.anzeigename ?? "") : (URL(string: ha.basis)?.host() ?? ha.basis)
        if ha.live { return "Live verbunden mit \(host)" }
        if ha.verbunden { return "Verbunden mit \(host) · \(ha.stand.formatted(date: .omitted, time: .shortened))" }
        return ha.fehler.isEmpty ? "Verbinde …" : ha.fehler
    }

    private func platzhalter(symbol: String, titel: String, text: String, knopf: String, aktion: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 84, height: 84)
                .glas(Circle())
            Text(titel).font(.title3.weight(.semibold))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button(knopf, action: aktion)
                .glasKnopfBetont()
                .controlSize(.large)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
