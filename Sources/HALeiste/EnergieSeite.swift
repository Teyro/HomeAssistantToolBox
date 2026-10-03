import SwiftUI
import Charts
import HALogik

/// Reiter "Energie": aktueller Verbrauch mit Kennzahlen der letzten 24 Stunden und Verlauf,
/// Verbrauch heute (Strom, Wasser, Gas), größte Verbraucher, Zählerstände als Kacheln.
struct EnergieSeite: View {
    let ha: HaVerbindung
    let einstellungen: Einstellungen

    private var aktuell: Double { ha.hauptWatt ?? ha.summeWatt }
    private var verbraucher: [Messung] { Array(ha.leistung.filter { $0.watt > 0 }.prefix(10)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                jetzt
                if !einstellungen.hauptzaehler.isEmpty {
                    VerlaufDiagramm(punkte: ha.verlauf, aktuell: ha.hauptWatt)
                        .frame(height: 130)
                        .karte()
                } else {
                    Text("Tipp: In den Einstellungen einen Hauptzähler wählen, dann erscheint hier der Verlauf der letzten 24 Stunden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                verbrauchHeute
                if !verbraucher.isEmpty {
                    Abschnitt(titel: "Größte Verbraucher gerade")
                    VStack(spacing: 10) {
                        ForEach(verbraucher) { v in verbraucherZeile(v) }
                    }
                    .karte()
                }
                if !ha.energie.isEmpty {
                    Abschnitt(titel: "Zählerstände")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(ha.energie) { z in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(z.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Text(Logik.formatKwh(z.kwh)).font(.callout.weight(.semibold)).monospacedDigit().lineLimit(1)
                            }
                            .karte(eckradius: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        // Verlauf und Tageswerte beim Öffnen und dann alle 5 Minuten
        .task(id: einstellungen.hauptzaehler) {
            while !Task.isCancelled {
                await ha.verlaufLaden()
                try? await Task.sleep(for: .seconds(300))
            }
        }
        .task(id: verbrauchSchluessel) {
            while !Task.isCancelled {
                if !einstellungen.verbrauchGewuenscht.isEmpty {
                    await ha.verbrauchHeuteLaden(eigene: einstellungen.eigeneZaehler, gewuenscht: einstellungen.verbrauchGewuenscht)
                }
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    /// Ändert sich bei anderen Einstellungen oder wenn die Live-Verbindung steht → neu laden
    private var verbrauchSchluessel: String {
        let arten = einstellungen.verbrauchGewuenscht.map(\.rawValue).sorted().joined(separator: ",")
        return [arten, einstellungen.zaehlerStrom, einstellungen.zaehlerWasser, einstellungen.zaehlerGas, ha.live ? "live" : ""].joined(separator: "|")
    }

    // MARK: Jetzt

    private var jetzt: some View {
        let k = Logik.verlaufKennzahlen(ha.verlauf, ende: Date())
        return HStack(alignment: .center, spacing: 12) {
            SymbolKreis(symbol: "bolt.fill", farbe: .accentColor, groesse: 46)
            VStack(alignment: .leading, spacing: 0) {
                Text(ha.hauptWatt != nil ? "Verbrauch gerade" : "Verbrauch der Messsteckdosen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Logik.formatWatt(aktuell))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: aktuell))
                    .animation(.snappy, value: aktuell)
            }
            Spacer(minLength: 4)
            if let k {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 1) {
                    kennzahl("24 h", "≈ " + Logik.formatKwh(k.kwh))
                    kennzahl("Ø", Logik.formatWatt(k.schnitt))
                    kennzahl("Spitze", Logik.formatWatt(k.spitze.w) + " · " + k.spitze.t.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption)
            }
        }
        .karte(farbe: Color.accentColor.opacity(0.18), eckradius: 20)
    }

    private func kennzahl(_ titel: String, _ wert: String) -> some View {
        GridRow {
            Text(titel).foregroundStyle(.secondary)
            Text(wert).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }

    // MARK: Verbrauch heute

    @ViewBuilder
    private var verbrauchHeute: some View {
        let arten = VerbrauchsArt.allCases.filter { einstellungen.verbrauchGewuenscht.contains($0) }
        let mitWert = arten.filter { ha.verbrauchHeute[$0] != nil }
        if !arten.isEmpty {
            Abschnitt(titel: "Verbrauch heute")
            if mitWert.isEmpty {
                Text("Keine Zähler gefunden. In Home Assistant das Energie-Dashboard einrichten oder in den Einstellungen Zähler wählen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            } else {
                GlasGruppe(abstand: 8) {
                    HStack(spacing: 8) {
                        ForEach(mitWert) { art in tagesKachel(art, ha.verbrauchHeute[art]!) }
                    }
                }
            }
        }
    }

    private func tagesKachel(_ art: VerbrauchsArt, _ w: Tageswert) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: art.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(art.farbe.gradient, in: Circle())
                Text(art.titel).font(.caption).foregroundStyle(.secondary)
            }
            Text(w.gueltig ? Logik.formatMenge(w.heute, w.einheit, art) : "–")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
            if w.gueltig {
                Text("gestern " + Logik.formatMenge(w.gestern, w.einheit, art))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .karte(farbe: art.farbe.opacity(0.2), eckradius: 16)
    }

    // MARK: Größte Verbraucher

    private func verbraucherZeile(_ v: Messung) -> some View {
        let maxWatt = max(verbraucher.first?.watt ?? 1, 1)
        return VStack(spacing: 4) {
            HStack {
                Text(v.name).lineLimit(1)
                Spacer()
                // Anteil am Hauptzähler (über 100 % z. B. bei eigener PV-Erzeugung nicht sinnvoll)
                if aktuell > 0, ha.hauptWatt != nil, v.watt <= aktuell {
                    Text("\(Int((v.watt / aktuell * 100).rounded())) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(Logik.formatWatt(v.watt))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .font(.callout)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [.accentColor.opacity(0.7), .accentColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * v.watt / maxWatt))
                }
            }
            .frame(height: 6)
            .animation(.snappy, value: v.watt)
        }
    }
}

/// Verlauf der letzten 24 Stunden mit Fläche, Linie und Wert beim Überfahren.
struct VerlaufDiagramm: View {
    let punkte: [Punkt]
    let aktuell: Double?
    @State private var auswahl: Punkt?

    /// Punkte plus aktueller Wert am rechten Rand
    private var daten: [Punkt] {
        guard let letzter = punkte.last else { return [] }
        return punkte + [Punkt(t: Date(), w: aktuell ?? letzter.w)]
    }

    var body: some View {
        if punkte.count < 2 {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(daten) { p in
                    AreaMark(x: .value("Zeit", p.t), y: .value("Leistung", p.w))
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.45), .accentColor.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Zeit", p.t), y: .value("Leistung", p.w))
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
                if let letzter = daten.last {
                    PointMark(x: .value("Zeit", letzter.t), y: .value("Leistung", letzter.w))
                        .symbolSize(40)
                        .foregroundStyle(Color.accentColor)
                }
                if let auswahl {
                    RuleMark(x: .value("Zeit", auswahl.t))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(spacing: 0) {
                                Text(Logik.formatWatt(auswahl.w)).font(.caption.weight(.semibold)).monospacedDigit()
                                Text(auswahl.t.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glas(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel {
                        if let w = wert.as(Double.self) { Text(Logik.formatWatt(w)) }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let ort):
                                guard let rahmen = proxy.plotFrame else { return }
                                let x = ort.x - geo[rahmen].origin.x
                                guard let t: Date = proxy.value(atX: x) else { return }
                                // der Wert, der zu diesem Zeitpunkt galt
                                auswahl = daten.last { $0.t <= t } ?? daten.first
                            case .ended:
                                auswahl = nil
                            }
                        }
                }
            }
        }
    }
}
