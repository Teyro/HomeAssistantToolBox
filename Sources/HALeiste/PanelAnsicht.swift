import SwiftUI
import HALogik

enum Reiter: Int, CaseIterable, Identifiable {
    case lampen, steckdosen, energie
    var id: Int { rawValue }
    var titel: String {
        switch self {
        case .lampen: "Lampen"
        case .steckdosen: "Steckdosen"
        case .energie: "Energie"
        }
    }
    var symbol: String {
        switch self {
        case .lampen: "lightbulb.fill"
        case .steckdosen: "poweroutlet.type.f.fill"
        case .energie: "bolt.fill"
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
    let ha: HaVerbindung
    let einstellungen: Einstellungen
    @Bindable var zustand: PanelZustand
    var einrichten: () -> Void

    @Namespace private var reiterRaum

    var body: some View {
        VStack(spacing: 0) {
            kopf
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
                        platzhalter(symbol: "wifi.exclamationmark", titel: "Keine Verbindung",
                                    text: ha.fehler.isEmpty ? "Home Assistant antwortet nicht." : ha.fehler,
                                    knopf: ha.abgelehnt ? "Einstellungen …" : "Erneut versuchen",
                                    aktion: ha.abgelehnt ? einrichten : { ha.erneutVersuchen() })
                    }
                } else {
                    switch zustand.reiter {
                    case .lampen: LampenSeite(ha: ha, einstellungen: einstellungen, zustand: zustand)
                    case .steckdosen: SteckdosenSeite(ha: ha, zustand: zustand)
                    case .energie: EnergieSeite(ha: ha, einstellungen: einstellungen)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            fuss
        }
        .frame(width: 400, height: 640)
        .animation(.snappy, value: ha.meldung)
        .onAppear { ha.sichtbar = true }
        .onDisappear { ha.sichtbar = false }
    }

    // MARK: Kopf: Reiter als Glasleiste + Knöpfe

    private var kopf: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(Reiter.allCases) { r in reiterKnopf(r) }
            }
            .padding(3)
            .glas(Capsule())

            Spacer(minLength: 4)

            GlasGruppe(abstand: 6) {
                HStack(spacing: 6) {
                    Button { ha.erneutVersuchen() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Aktualisieren")
                    Menu {
                        Button("Home Assistant öffnen") { if let u = URL(string: ha.basis) { NSWorkspace.shared.open(u) } }
                            .disabled(!ha.eingerichtet)
                        Button("Alle Lampen aus") { ha.alleLichterAus() }
                            .disabled(ha.lichterAn == 0)
                        Divider()
                        Button("Einstellungen …", action: einrichten)
                        Divider()
                        Button("HA Leiste beenden") { NSApp.terminate(nil) }
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
        case .energie: nil
        }
        return Button {
            withAnimation(.snappy(duration: 0.3)) { zustand.reiter = r }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: r.symbol).font(.system(size: 12, weight: .semibold))
                Text(r.titel).font(.system(size: 12, weight: gewaehlt ? .semibold : .medium))
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
            .padding(.horizontal, 10)
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
    }

    // MARK: Fuß: Verbindungsstatus

    private var fuss: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ha.live ? Color.green : ha.verbunden ? Color.yellow : Color.red)
                .frame(width: 7, height: 7)
                .shadow(color: ha.live ? .green.opacity(0.7) : .clear, radius: 3)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var statusText: String {
        if !ha.eingerichtet { return "Nicht eingerichtet" }
        let host = URL(string: ha.basis)?.host() ?? ha.basis
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
