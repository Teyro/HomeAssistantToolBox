import SwiftUI
import HALogik

/// Reiter "Steckdosen": oben die Steckdosengruppen (Schaltergruppen und Geräte mit mehreren
/// Dosen), darunter – zunächst eingeklappt – die einzelnen Steckdosen nach Raum.
struct SteckdosenSeite: View {
    let ha: HaVerbindung
    @Bindable var zustand: PanelZustand

    /// Einzelne nach Raum gruppiert, Räume alphabetisch, "Ohne Raum" zuletzt
    private var einzelne: [Schalter] {
        ha.schalter.filter { ha.einzelneSchalter.contains($0.id) }.sorted { a, b in
            if a.raum == b.raum { return Logik.vorher(a.name, b.name) }
            if a.raum.isEmpty { return false }
            if b.raum.isEmpty { return true }
            return Logik.vorher(a.raum, b.raum)
        }
    }

    private var summe: Double {
        var w = 0.0
        var gesehen = Set<String>()
        for s in ha.schalter where !s.leistung.isEmpty && !gesehen.contains(s.leistung) {
            gesehen.insert(s.leistung)
            w += Logik.wattVon(ha.zustaende[s.leistung]) ?? 0
        }
        return w
    }

    var body: some View {
        let liste = einzelne
        let mitRaeumen = liste.contains { !$0.raum.isEmpty }
        // Ohne Gruppen gibt es nichts zum Einklappen – dann gleich alles zeigen
        let einzelneSichtbar = zustand.einzelneSteckdosenOffen || ha.schalterGruppen.isEmpty
        let mitMessung = ha.schalter.contains { !$0.leistung.isEmpty }
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    UebersichtKarte(symbol: "poweroutlet.type.f.fill",
                                    titel: ha.schalter.isEmpty ? T("Keine Steckdosen") : ha.schalterAn == 0 ? T("Alle aus") : T("%1 von %2 an", "\(ha.schalterAn)", "\(ha.schalter.count)"),
                                    untertitel: mitMessung ? T("Verbrauch zusammen") : T("%1 Steckdosen", "\(ha.schalter.count)"),
                                    anteil: ha.schalter.isEmpty ? 0 : Double(ha.schalterAn) / Double(ha.schalter.count),
                                    farbe: .accentColor) {
                        if mitMessung {
                            Text(Logik.formatWatt(summe))
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: summe))
                                .animation(.snappy, value: summe)
                        }
                    }
                    if !ha.schalterGruppen.isEmpty {
                        Abschnitt(titel: T("Gruppen & Steckdosenleisten"), symbol: "poweroutlet.strip.fill")
                        ForEach(ha.schalterGruppen) { g in
                            SteckdosenGruppe(ha: ha, gruppe: g, aufgeklappt: zustand.offen.contains(g.id)) { zustand.umschalten(g.id) }
                        }
                        if !liste.isEmpty {
                            Abschnitt(titel: T("Einzelne Steckdosen"), anzahl: liste.count, offen: $zustand.einzelneSteckdosenOffen)
                        }
                    }
                    if einzelneSichtbar {
                        ForEach(Array(liste.enumerated()), id: \.element.id) { i, s in
                            if mitRaeumen && (i == 0 || liste[i - 1].raum != s.raum) {
                                Text(s.raum.isEmpty ? T("Ohne Raum") : s.raum)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 6)
                                    .padding(.top, 4)
                            }
                            SteckdosenZeile(ha: ha, eintrag: s)
                                .karte(farbe: Logik.istAn(ha.zustaende[s.id]) ? Color.accentColor.opacity(0.18) : nil)
                                .anheben()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 2)
            }
        }
    }
}

/// Steckdosengruppe (Schaltergruppe oder Steckdosenleiste): gemeinsamer Schalter und
/// Gesamtverbrauch, aufklappbar.
struct SteckdosenGruppe: View {
    let ha: HaVerbindung
    let gruppe: SchalterGruppe
    let aufgeklappt: Bool
    let klick: () -> Void

    var body: some View {
        let s = Logik.schalterGruppenStatus(gruppe, ha.zustaende)
        let an = s.an > 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SymbolKreis(symbol: "poweroutlet.strip.fill", farbe: an ? .accentColor : nil, verfuegbar: s.verfuegbar > 0)
                    .onTapGesture { if s.verfuegbar > 0 { schalten(!an) } }
                VStack(alignment: .leading, spacing: 1) {
                    Text(gruppe.name).font(.body.weight(.semibold)).lineLimit(1)
                    Text(untertitel(s)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
                    .disabled(s.verfuegbar == 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { klick() } }

            if aufgeklappt {
                VStack(spacing: 0) {
                    ForEach(Array(gruppe.mitglieder.enumerated()), id: \.element) { i, id in
                        if i > 0 { Divider().padding(.leading, 40) }
                        SteckdosenZeile(ha: ha, eintrag: mitglied(id), klein: true)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .karte(farbe: an ? Color.accentColor.opacity(0.22) : nil)
        .anheben()
        .animation(.snappy, value: aufgeklappt)
    }

    /// Mitglied der Gruppe. Teilen sich mehrere Dosen einen Messsensor (typisch bei Leisten),
    /// gehört der Wert zur ganzen Leiste – dann nicht bei jeder einzelnen Dose anzeigen.
    private func mitglied(_ id: String) -> Schalter {
        guard let s = ha.schalter.first(where: { $0.id == id }) else { return Schalter(id: id, name: id, raum: "", leistung: "") }
        let geteilt = !s.leistung.isEmpty && gruppe.mitglieder.filter { m in ha.schalter.first { $0.id == m }?.leistung == s.leistung }.count > 1
        return geteilt ? Schalter(id: s.id, name: s.name, raum: s.raum, leistung: "") : s
    }

    private func untertitel(_ s: SchalterGruppenStatus) -> String {
        var teile: [String] = []
        if s.verfuegbar == 0 { teile.append(T("nicht erreichbar")) }
        else if s.an == 0 { teile.append(s.gesamt == 1 ? T("1 Dose · aus") : T("%1 Dosen · alle aus", "\(s.gesamt)")) }
        else if s.an == s.gesamt { teile.append(T("alle %1 an", "\(s.gesamt)")) }
        else { teile.append(T("%1 von %2 an", "\(s.an)", "\(s.gesamt)")) }
        if let w = s.watt { teile.append(Logik.formatWatt(w)) }
        if !gruppe.raum.isEmpty { teile.append(gruppe.raum) }
        return teile.joined(separator: " · ")
    }

    private func schalten(_ ein: Bool) {
        if !gruppe.steuerId.isEmpty { ha.schalte(gruppe.steuerId, ein) } else { ha.schalteSchalter(gruppe.mitglieder, ein) }
    }
}

/// Eine Steckdose bzw. ein Schalter: Symbol, Name, Zustand mit Verbrauch, Schalter.
struct SteckdosenZeile: View {
    let ha: HaVerbindung
    let eintrag: Schalter
    var klein = false

    var body: some View {
        let e = ha.zustaende[eintrag.id]
        let an = Logik.istAn(e)
        let verfuegbar = Logik.istVerfuegbar(e)
        let watt = eintrag.leistung.isEmpty ? nil : Logik.wattVon(ha.zustaende[eintrag.leistung])
        HStack(spacing: 10) {
            SymbolKreis(symbol: "poweroutlet.type.f.fill", farbe: an ? .accentColor : nil, verfuegbar: verfuegbar, groesse: klein ? 26 : 32)
                .onTapGesture { if verfuegbar { ha.schalte(eintrag.id, !an) } }
            VStack(alignment: .leading, spacing: 1) {
                Text(eintrag.name).font(klein ? .callout : .body.weight(.medium)).lineLimit(1)
                Text(!verfuegbar ? T("nicht erreichbar") : an ? T("an") : T("aus"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let watt { WattPlakette(watt: watt) }
            Toggle("", isOn: Binding(get: { an }, set: { ha.schalte(eintrag.id, $0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!verfuegbar)
        }
    }
}
