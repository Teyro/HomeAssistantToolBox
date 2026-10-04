import SwiftUI
import Charts
import AppIntents
import HALogik

// Ansichten der Schreibtisch-Widgets. Auch in der App eingebunden (für die Vorschau-Bilder).

enum WidgetGroesse { case klein, mittel, gross }

extension Color {
    init(widgetHex hex: String) {
        let v = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x3daee9
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}

/// Runder Kreis mit Symbol (wie im Kontrollzentrum)
struct WidgetSymbol: View {
    let symbol: String
    var farbe: Color?
    var groesse: CGFloat = 30
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: groesse * 0.45, weight: .semibold))
            .foregroundStyle(farbe != nil ? AnyShapeStyle(Color.black.opacity(0.65)) : AnyShapeStyle(.secondary))
            .frame(width: groesse, height: groesse)
            .background(farbe.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(Color.primary.opacity(0.1)), in: Circle())
    }
}

/// Hinweis, wenn noch nichts gewählt ist oder die App keine Daten geschrieben hat
struct WidgetHinweis: View {
    let text: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lightbulb.2").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetKopf: View {
    let symbol: String
    let titel: String
    var rechts: String = ""
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(titel).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 2)
            if !rechts.isEmpty { Text(rechts).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }
    }
}

// MARK: Lampe

struct LampeKachel: View {
    let lampe: Schnappschuss.Lampe?
    var body: some View {
        if let l = lampe {
            let farbe = l.an ? Color(widgetHex: l.farbe ?? "#ffc65c") : nil
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    WidgetSymbol(symbol: l.an ? "lightbulb.fill" : "lightbulb", farbe: farbe, groesse: 36)
                    Spacer()
                    Toggle(isOn: l.an, intent: SchalteAbsicht(l.id, an: !l.an)) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!l.verfuegbar)
                }
                Spacer(minLength: 0)
                Text(l.name).font(.headline).lineLimit(2)
                Text(!l.verfuegbar ? "nicht erreichbar" : !l.an ? "aus" : l.helligkeit.map { "an · \($0) %" } ?? "an")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let h = l.helligkeit, l.an {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.1))
                            Capsule().fill((farbe ?? .yellow).gradient).frame(width: Swift.max(6, geo.size.width * CGFloat(h) / 100))
                        }
                    }
                    .frame(height: 5)
                }
            }
        } else {
            WidgetHinweis(text: "Lampe wählen: Rechtsklick → „Widget bearbeiten“")
        }
    }
}

// MARK: Steckdose

struct SteckdoseKachel: View {
    let dose: Schnappschuss.Steckdose?
    var body: some View {
        if let d = dose {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    WidgetSymbol(symbol: "poweroutlet.type.f.fill", farbe: d.an ? .accentColor : nil, groesse: 36)
                    Spacer()
                    Toggle(isOn: d.an, intent: SchalteAbsicht(d.id, an: !d.an)) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!d.verfuegbar)
                }
                Spacer(minLength: 0)
                Text(d.name).font(.headline).lineLimit(2)
                HStack(spacing: 4) {
                    Text(!d.verfuegbar ? "nicht erreichbar" : d.an ? "an" : "aus").foregroundStyle(.secondary)
                    if let w = d.watt {
                        Text("· \(Logik.formatWatt(w))").foregroundStyle(w > 0 ? .orange : .secondary).monospacedDigit()
                    }
                }
                .font(.caption)
            }
        } else {
            WidgetHinweis(text: "Steckdose wählen: Rechtsklick → „Widget bearbeiten“")
        }
    }
}

// MARK: Heizung

struct HeizungKachel: View {
    let heizung: Schnappschuss.Heizung?
    var groesse: WidgetGroesse = .klein
    var body: some View {
        if let h = heizung {
            VStack(alignment: .leading, spacing: 4) {
                WidgetKopf(symbol: h.heizt ? "flame.fill" : "heater.vertical", titel: h.name,
                           rechts: h.fensterOffen ? "Fenster offen" : (h.feuchte.map { "\(Int($0.rounded())) %" } ?? ""))
                Spacer(minLength: 0)
                Text(Logik.formatTemp(h.ist))
                    .font(.system(size: groesse == .klein ? 30 : 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(h.klima.isEmpty ? "Temperatur" : h.aus ? "Heizung aus" : h.heizt ? "heizt auf \(Logik.formatTemp(h.ziel))" : "Ziel \(Logik.formatTemp(h.ziel))")
                    .font(.caption)
                    .foregroundStyle(h.heizt ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                if let ziel = h.ziel, !h.klima.isEmpty {
                    HStack(spacing: 6) {
                        Button(intent: TemperaturAbsicht(h.klima, grad: Swift.max(h.min, ziel - h.schritt))) {
                            Image(systemName: "minus").frame(maxWidth: .infinity)
                        }
                        Text(Logik.formatTemp(ziel)).font(.caption.weight(.semibold)).monospacedDigit().fixedSize()
                        Button(intent: TemperaturAbsicht(h.klima, grad: Swift.min(h.max, ziel + h.schritt))) {
                            Image(systemName: "plus").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } else {
            WidgetHinweis(text: "Heizung wählen: Rechtsklick → „Widget bearbeiten“")
        }
    }
}

// MARK: Raum

struct RaumKachel: View {
    let daten: Schnappschuss
    let raum: Schnappschuss.Raum?
    var groesse: WidgetGroesse = .mittel
    var body: some View {
        if let r = raum {
            let heizung = r.heizung.flatMap { id in daten.heizungen.first { $0.id == id } }
            let lampen = r.lampen.compactMap { id in daten.lampen.first { $0.id == id } }
            let dosen = r.steckdosen.compactMap { id in daten.steckdosen.first { $0.id == id } }
            let max = groesse == .gross ? 8 : 3
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "house.fill").foregroundStyle(.secondary)
                    Text(r.name).font(.headline).lineLimit(1)
                    Spacer()
                    if let h = heizung {
                        HStack(spacing: 3) {
                            if h.heizt { Image(systemName: "flame.fill").foregroundStyle(.orange) }
                            Text(Logik.formatTemp(h.ist)).monospacedDigit()
                        }
                        .font(.callout.weight(.semibold))
                    }
                }
                ForEach(Array((lampen.map { ($0.id, $0.name, $0.an, $0.verfuegbar, true) } + dosen.map { ($0.id, $0.name, $0.an, $0.verfuegbar, false) }).prefix(max)), id: \.0) { e in
                    HStack(spacing: 8) {
                        Image(systemName: e.4 ? (e.2 ? "lightbulb.fill" : "lightbulb") : "poweroutlet.type.f.fill")
                            .foregroundStyle(e.2 ? (e.4 ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(Color.accentColor)) : AnyShapeStyle(.secondary))
                            .frame(width: 18)
                        Text(e.1).font(.callout).lineLimit(1)
                        Spacer(minLength: 2)
                        Toggle(isOn: e.2, intent: SchalteAbsicht(e.0, an: !e.2)) { EmptyView() }
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .disabled(!e.3)
                    }
                }
                Spacer(minLength: 0)
                if let h = heizung, groesse == .gross {
                    HeizungKachel(heizung: h, groesse: .mittel).frame(maxHeight: 120)
                }
            }
        } else {
            WidgetHinweis(text: "Raum wählen: Rechtsklick → „Widget bearbeiten“")
        }
    }
}

// MARK: Energie

struct EnergieKachel: View {
    let daten: Schnappschuss
    var groesse: WidgetGroesse = .mittel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetKopf(symbol: "bolt.fill", titel: "Verbrauch gerade")
                    Text(Logik.formatWatt(daten.watt))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                if daten.verlauf.count > 2 {
                    Chart(Array(daten.verlauf.enumerated()), id: \.offset) { p in
                        AreaMark(x: .value("t", p.offset), y: .value("W", p.element))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.45), .accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("t", p.offset), y: .value("W", p.element))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: groesse == .klein ? 0 : 150, height: 54)
                }
            }
            if !daten.tage.isEmpty {
                HStack(spacing: 6) {
                    ForEach(daten.tage) { t in
                        let art = VerbrauchsArt(rawValue: t.art) ?? .strom
                        VStack(alignment: .leading, spacing: 1) {
                            Label(widgetTitel(art), systemImage: widgetSymbol(art))
                                .font(.caption2)
                                .foregroundStyle(widgetFarbe(art))
                            Text(Logik.formatMenge(t.heute, t.einheit, art))
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(widgetFarbe(art).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            if groesse == .gross {
                ForEach(daten.verbraucher) { v in
                    HStack {
                        Text(v.name).font(.callout).lineLimit(1)
                        Spacer()
                        Text(Logik.formatWatt(v.watt)).font(.callout.weight(.semibold)).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

func widgetTitel(_ a: VerbrauchsArt) -> String { a == .strom ? "Strom" : a == .wasser ? "Wasser" : "Gas" }
func widgetSymbol(_ a: VerbrauchsArt) -> String { a == .strom ? "bolt.fill" : a == .wasser ? "drop.fill" : "flame.fill" }
func widgetFarbe(_ a: VerbrauchsArt) -> Color {
    a == .strom ? Color(red: 0.95, green: 0.7, blue: 0.1) : a == .wasser ? Color(red: 0.2, green: 0.6, blue: 1) : .orange
}

// MARK: Übersicht

struct UebersichtKachel: View {
    let daten: Schnappschuss
    var groesse: WidgetGroesse = .mittel
    var body: some View {
        let heizen = daten.heizungen.filter(\.heizt).count
        let temps = daten.heizungen.compactMap(\.ist)
        let zuhause = daten.personen.filter(\.zuhause)
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                WidgetKopf(symbol: "house.fill", titel: daten.instanz.isEmpty ? "Home Assistant" : daten.instanz)
                Button(intent: AlleAusAbsicht()) {
                    Label("Alle aus", systemImage: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            zeile("lightbulb.fill", farbe: daten.lichterAn > 0 ? .yellow : .secondary, "\(daten.lichterAn) von \(daten.lichterGesamt) Lampen an")
            if !daten.steckdosen.isEmpty {
                zeile("poweroutlet.type.f.fill", farbe: .accentColor, "\(daten.steckdosen.filter(\.an).count) von \(daten.steckdosen.count) Steckdosen an")
            }
            if !daten.heizungen.isEmpty {
                zeile("heater.vertical.fill", farbe: heizen > 0 ? .orange : .secondary,
                      (heizen > 0 ? "Heizung an (\(heizen))" : "Heizung ruht") + (temps.isEmpty ? "" : " · Ø " + Logik.formatTemp(temps.reduce(0, +) / Double(temps.count))))
            }
            if daten.watt != nil { zeile("bolt.fill", farbe: .secondary, "Verbrauch \(Logik.formatWatt(daten.watt))") }
            if !daten.personen.isEmpty {
                zeile("person.2.fill", farbe: .green, zuhause.isEmpty ? "Niemand zu Hause" : "Zu Hause: " + zuhause.map(\.name).joined(separator: ", "))
            }
            if groesse == .gross {
                Divider()
                ForEach(daten.heizungen.prefix(5)) { h in
                    HStack {
                        Text(h.name).font(.callout)
                        Spacer()
                        if h.heizt { Image(systemName: "flame.fill").foregroundStyle(.orange) }
                        Text(Logik.formatTemp(h.ist)).font(.callout.weight(.semibold)).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func zeile(_ symbol: String, farbe: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(farbe).frame(width: 18)
            Text(text).font(.callout).lineLimit(1)
        }
    }
}

// MARK: Personen

struct PersonenKachel: View {
    let daten: Schnappschuss
    var groesse: WidgetGroesse = .mittel
    var body: some View {
        let zuhause = daten.personen.filter(\.zuhause).count
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(symbol: "person.2.fill", titel: "Personen", rechts: "\(zuhause) von \(daten.personen.count) zu Hause")
            ForEach(daten.personen.prefix(groesse == .gross ? 8 : 3)) { p in
                HStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle().fill(Color(widgetHex: p.farbe).gradient)
                            .overlay(Text(Logik.initialen(p.name)).font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                            .frame(width: 26, height: 26)
                        if p.zuhause { Circle().fill(.green).frame(width: 9, height: 9).overlay(Circle().stroke(.white, lineWidth: 1)) }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.name).font(.callout.weight(.medium))
                        Text(p.ort).font(.caption).foregroundStyle(p.zuhause ? .green : .secondary)
                    }
                    Spacer()
                    if !p.zuhause, let km = p.km { Text(Logik.formatEntfernung(km)).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Beliebige Entität

struct WertKachel: View {
    let wert: Schnappschuss.Wert?
    var body: some View {
        if let w = wert {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(w.name).font(.caption.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 2)
                    if w.schaltbar {
                        Toggle(isOn: w.an, intent: SchalteAbsicht(w.id, an: !w.an)) { EmptyView() }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                }
                Spacer(minLength: 0)
                Text(w.text)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(w.id).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        } else {
            WidgetHinweis(text: "Entität wählen: Rechtsklick → „Widget bearbeiten“")
        }
    }
}

/// Fußzeile mit Stand und Instanz (in größeren Widgets)
struct WidgetStand: View {
    let daten: Schnappschuss
    var body: some View {
        Text(daten.stand == .distantPast ? "HA Leiste öffnen" : "Stand \(daten.stand.formatted(date: .omitted, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
