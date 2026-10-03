import SwiftUI
import HALogik

/// Reiter "Lampen": oben die Gruppen, darunter die Räume, zuletzt Lampen ohne Raum.
/// Ein Klick auf eine Gruppe/einen Raum klappt die einzelnen Lampen auf.
struct LampenSeite: View {
    let ha: HaVerbindung
    let einstellungen: Einstellungen
    @Bindable var zustand: PanelZustand

    private var raeumeMitLicht: [Raum] { einstellungen.zeigeRaeume ? ha.raeume.filter { !$0.lichter.isEmpty } : [] }
    private var einzelne: [String] { einstellungen.zeigeRaeume && !ha.raeume.isEmpty ? ha.ohneRaum : ha.lichter }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(zusammenfassung)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    ha.alleLichterAus()
                } label: {
                    Label("Alle aus", systemImage: "power")
                }
                .glasKnopf()
                .controlSize(.small)
                .disabled(ha.lichterAn == 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if einstellungen.zeigeGruppen && !ha.gruppen.isEmpty {
                        Abschnitt(titel: "Gruppen")
                        ForEach(ha.gruppen) { g in
                            GruppenKarte(ha: ha, titel: g.name, symbol: "lightbulb.2.fill", steuerId: g.id, mitglieder: g.mitglieder,
                                         aufgeklappt: zustand.offen.contains("g:" + g.id)) { zustand.umschalten("g:" + g.id) }
                        }
                    }
                    if !raeumeMitLicht.isEmpty {
                        Abschnitt(titel: "Räume")
                        ForEach(raeumeMitLicht) { r in
                            GruppenKarte(ha: ha, titel: r.name, symbol: "house.fill", steuerId: "", mitglieder: r.lichter,
                                         aufgeklappt: zustand.offen.contains("r:" + r.id)) { zustand.umschalten("r:" + r.id) }
                        }
                    }
                    if !einzelne.isEmpty {
                        Abschnitt(titel: einstellungen.zeigeRaeume && !ha.raeume.isEmpty ? "Ohne Raum" : "Alle Lampen",
                                  anzahl: einzelne.count, offen: $zustand.einzelneLampenOffen)
                        if zustand.einzelneLampenOffen {
                            ForEach(einzelne, id: \.self) { id in
                                LampenZeile(ha: ha, entityId: id).karte(farbe: kartenFarbe(id))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var zusammenfassung: String {
        if ha.lichter.isEmpty { return "Keine Lampen gefunden" }
        if ha.lichterAn == 0 { return "Alle \(ha.lichter.count) Lampen sind aus" }
        return "\(ha.lichterAn) von \(ha.lichter.count) Lampen an"
    }

    private func kartenFarbe(_ id: String) -> Color? {
        Logik.lampenFarbe(ha.zustaende[id]).map { $0.farbe.opacity(0.35) }
    }
}

/// Lichtgruppe oder Raum: gemeinsamer Schalter und Regler, aufklappbar.
struct GruppenKarte: View {
    let ha: HaVerbindung
    let titel: String
    let symbol: String
    /// Gruppen-Entität; leer bei Räumen (dann werden die Lampen gemeinsam geschaltet)
    let steuerId: String
    let mitglieder: [String]
    let aufgeklappt: Bool
    let klick: () -> Void

    var body: some View {
        let status = Logik.gruppenStatus(mitglieder, ha.zustaende)
        let farbe = Logik.gruppenFarbe(mitglieder, ha.zustaende)?.farbe
        let an = status.an > 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SymbolKreis(symbol: symbol, farbe: an ? farbe : nil, verfuegbar: status.verfuegbar > 0)
                    .onTapGesture { schalten(!an) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(titel).font(.body.weight(.semibold)).lineLimit(1)
                    Text(untertitel(status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(aufgeklappt ? 180 : 0))
                Toggle("", isOn: Binding(get: { an }, set: { schalten($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .disabled(status.verfuegbar == 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { klick() } }

            if an && status.dimmbar {
                HelligkeitsRegler(wert: status.helligkeit, farbe: farbe ?? .yellow) { p in
                    if !steuerId.isEmpty { ha.dimme(steuerId, p) } else { ha.dimmeMehrere(mitglieder, p) }
                }
            }

            if aufgeklappt {
                VStack(spacing: 0) {
                    ForEach(Array(mitglieder.enumerated()), id: \.element) { i, id in
                        if i > 0 { Divider().padding(.leading, 40) }
                        LampenZeile(ha: ha, entityId: id, klein: true).padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .karte(farbe: an ? (farbe ?? .yellow).opacity(0.35) : nil)
    }

    private func untertitel(_ s: GruppenStatus) -> String {
        if s.verfuegbar == 0 { return "nicht erreichbar" }
        if s.an == 0 { return "\(s.gesamt) Lampen · alle aus" }
        let teil = s.an == s.gesamt ? "alle \(s.gesamt) an" : "\(s.an) von \(s.gesamt) an"
        return s.dimmbar ? "\(teil) · \(s.helligkeit) %" : teil
    }

    private func schalten(_ ein: Bool) {
        if !steuerId.isEmpty { ha.schalte(steuerId, ein) } else { ha.schalteMehrere(mitglieder, ein) }
    }
}

/// Eine Lampe: Symbol in Lampenfarbe, Name, Zustand, Schalter und Helligkeitsregler.
struct LampenZeile: View {
    let ha: HaVerbindung
    let entityId: String
    var klein = false

    var body: some View {
        let e = ha.zustaende[entityId]
        let an = Logik.istAn(e)
        let verfuegbar = Logik.istVerfuegbar(e)
        let farbe = Logik.lampenFarbe(e)?.farbe
        let dimmbar = Logik.dimmbar(e)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                SymbolKreis(symbol: an ? "lightbulb.fill" : "lightbulb", farbe: farbe, verfuegbar: verfuegbar, groesse: klein ? 26 : 32)
                    .onTapGesture { if verfuegbar { ha.schalte(entityId, !an) } }
                VStack(alignment: .leading, spacing: 1) {
                    Text(e?.name ?? entityId).font(klein ? .callout : .body.weight(.medium)).lineLimit(1)
                    Text(!verfuegbar ? "nicht erreichbar" : !an ? "aus" : dimmbar ? "an · \(Logik.helligkeit(e)) %" : "an")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Toggle("", isOn: Binding(get: { an }, set: { ha.schalte(entityId, $0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .disabled(!verfuegbar)
            }
            if an && dimmbar {
                HelligkeitsRegler(wert: Logik.helligkeit(e), farbe: farbe ?? .yellow) { ha.dimme(entityId, $0) }
                    .padding(.leading, klein ? 36 : 0)
            }
        }
    }
}
