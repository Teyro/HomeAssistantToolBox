import SwiftUI
import Charts
import HALogik

/// Reiter "Heizung": alle Räume mit Ist-Temperatur (live), Luftfeuchte und Thermostat.
/// Zieltemperatur per Regler, Modus, Profil und "Extra heizen" für eine bestimmte Zeit.
struct HeizungSeite: View {
    let kern: Kern
    private var ha: HaVerbindung { kern.ha }

    var body: some View {
        let klima = ha.heizungen.map { Logik.raumKlima($0, ha.zustaende) }
        let heizen = klima.filter(\.heizt).count
        let werte = klima.compactMap(\.ist)
        let schnitt = werte.isEmpty ? nil : werte.reduce(0, +) / Double(werte.count)
        let mitThermostat = ha.heizungen.filter { !$0.klima.isEmpty }.count
        ScrollView {
            LazyVStack(spacing: 8) {
                UebersichtKarte(symbol: "heater.vertical.fill",
                                titel: heizen == 0 ? T("Gerade heizt kein Raum") : heizen == 1 ? T("1 Raum heizt") : T("%1 Räume heizen", "\(heizen)"),
                                untertitel: schnitt.map { T("Ø %1 in %2 Räumen", "\(Logik.formatTemp($0))", "\(werte.count)") } ?? T("%1 Räume", "\(ha.heizungen.count)"),
                                anteil: mitThermostat == 0 ? 0 : Double(heizen) / Double(mitThermostat),
                                farbe: .orange) { EmptyView() }
                ForEach(ha.heizungen) { raum in
                    HeizRaumKarte(kern: kern, raum: raum, aufgeklappt: kern.panel.offen.contains("h:" + raum.id)) {
                        withAnimation(.snappy) { kern.panel.umschalten("h:" + raum.id) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 2)
        }
    }
}

/// Ein Raum: Temperatur groß, Zustand, Regler für die Zieltemperatur; aufgeklappt Modus,
/// Profil und "Extra heizen".
struct HeizRaumKarte: View {
    let kern: Kern
    let raum: HeizRaum
    let aufgeklappt: Bool
    var klick: () -> Void

    @State private var boostGrad: Double = 22
    @State private var boostMinuten = 60
    @State private var verlauf: KlimaVerlauf?
    private var ha: HaVerbindung { kern.ha }

    var body: some View {
        let k = Logik.raumKlima(raum, ha.zustaende)
        let t = k.thermostat
        let boost = kern.boost(fuer: raum.klima)
        let aufklappbar = t != nil || !raum.temperatur.isEmpty
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SymbolKreis(symbol: t == nil ? "thermometer.medium" : "heater.vertical.fill", farbe: k.heizt ? .orange : nil,
                            verfuegbar: t?.verfuegbar ?? true)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(raum.name).font(.body.weight(.semibold)).lineLimit(1)
                        // Fenster offen/zu
                        if k.fensterBekannt {
                            Image(systemName: k.fensterOffen ? "window.vertical.open" : "window.vertical.closed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(k.fensterOffen ? AnyShapeStyle(Color.cyan) : AnyShapeStyle(.tertiary))
                                .symbolEffect(.bounce, value: k.fensterOffen)
                                .help(k.fensterOffen ? T("Fenster offen") : T("Fenster zu"))
                        }
                    }
                    Text(untertitel(k))
                        .font(.caption)
                        .foregroundStyle(k.fensterOffen ? AnyShapeStyle(Color.cyan) : k.heizt ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(Logik.formatTemp(k.ist))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: k.ist ?? 0))
                    .animation(.snappy, value: k.ist)
                if aufklappbar {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(aufgeklappt ? 180 : 0))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if aufklappbar { klick() } }

            if let t, t.verfuegbar, let ziel = t.ziel, t.modus != "off" {
                HStack(spacing: 8) {
                    rundKnopf("minus") { setzen(ziel - t.schritt, t) }
                    TemperaturRegler(wert: ziel, min: t.min, max: t.max, schritt: t.schritt) { setzen($0, t) }
                    rundKnopf("plus") { setzen(ziel + t.schritt, t) }
                }
            }

            if let boost {
                TimelineView(.periodic(from: .now, by: 30)) { kontext in
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        Text(T("Extra heizen · noch %1, danach %2", "\(Logik.formatDauer(boost.bis.timeIntervalSince(kontext.date)))", "\(boost.modus == "off" ? "aus" : Logik.formatTemp(boost.vorher))"))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button(T("Beenden")) { kern.boostBeenden(boost) }
                            .controlSize(.small)
                            .glasKnopf()
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if aufgeklappt {
                KlimaDiagramm(verlauf: verlauf)
                    .frame(height: 175)
                    .transition(.opacity)
                    .task(id: aufgeklappt) {
                        // beim Aufklappen laden, dann alle 5 Minuten
                        while !Task.isCancelled {
                            if let v = await ha.klimaVerlauf(raum) { verlauf = v }
                            try? await Task.sleep(for: .seconds(300))
                        }
                    }
            }

            if aufgeklappt, let t {
                VStack(alignment: .leading, spacing: 10) {
                    if t.modi.count > 1 {
                        Picker(T("Modus"), selection: Binding(get: { t.modus }, set: { m in raum.klima.forEach { ha.setzeModus($0, m) } })) {
                            ForEach(t.modi, id: \.self) { Text(Logik.modusName($0)).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if !t.presets.isEmpty {
                        Picker(T("Profil"), selection: Binding(get: { t.preset.isEmpty ? "none" : t.preset },
                                                            set: { p in raum.klima.forEach { ha.setzePreset($0, p) } })) {
                            Text(T("Kein Profil")).tag("none")
                            ForEach(t.presets, id: \.self) { Text(Logik.modusName($0)).tag($0) }
                        }
                    }
                    HStack(spacing: 8) {
                        Label(T("Extra heizen"), systemImage: "flame").font(.callout)
                        Spacer()
                        Stepper(Logik.formatTemp(boostGrad), value: $boostGrad, in: t.min...t.max, step: t.schritt)
                            .monospacedDigit()
                        Picker(T("Dauer"), selection: $boostMinuten) {
                            Text(T("30 min")).tag(30)
                            Text(T("1 h")).tag(60)
                            Text(T("2 h")).tag(120)
                            Text(T("3 h")).tag(180)
                            Text(T("4 h")).tag(240)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button(T("Starten")) { kern.boostStarten(raum.klima, grad: boostGrad, minuten: boostMinuten) }
                            .glasKnopfBetont()
                            .controlSize(.small)
                    }
                }
                .padding(10)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear { boostGrad = Logik.rundeZiel(Swift.min(t.max, (t.ziel ?? 20) + 2), t) }
            }
        }
        .karte(farbe: k.heizt ? Color.orange.opacity(0.22) : nil)
        .anheben()
        .animation(.snappy, value: aufgeklappt)
    }

    private func untertitel(_ k: RaumKlima) -> String {
        var teile: [String] = []
        if k.fensterOffen { teile.append(T("Fenster offen")) }
        if let t = k.thermostat {
            if !t.verfuegbar { teile.append(T("nicht erreichbar")) }
            else if k.aus { teile.append(T("Heizung aus")) }
            else if k.heizt { teile.append(T("heizt auf %1", "\(Logik.formatTemp(k.ziel))")) }
            else if let z = k.ziel { teile.append(T("Ziel %1", "\(Logik.formatTemp(z))")) }
            if !t.preset.isEmpty { teile.append(Logik.modusName(t.preset)) }
        } else {
            teile.append(T("Temperatur"))
        }
        if let f = k.feuchte { teile.append(T("%1 % Luftfeuchte", "\(Int(f.rounded()))")) }
        return teile.joined(separator: " · ")
    }

    private func setzen(_ grad: Double, _ t: KlimaStatus) {
        let ziel = Logik.rundeZiel(grad, t)
        raum.klima.forEach { ha.setzeTemperatur($0, ziel) }
    }

    private func rundKnopf(_ symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).frame(width: 18, height: 18)
        }
        .glasKnopf()
        .buttonBorderShape(.circle)
        .controlSize(.small)
    }
}

/// Regler für die Zieltemperatur: Kapsel mit Verlauf von kühl (blau) nach warm (orange),
/// der Wert steht im Griff. Gesendet wird erst beim Loslassen.
struct TemperaturRegler: View {
    let wert: Double
    let min: Double
    let max: Double
    let schritt: Double
    let setzen: (Double) -> Void

    @State private var lokal: Double = 20
    @State private var zieht = false
    @State private var losgelassen = Date.distantPast
    private let hoehe: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width
            let anteil = CGFloat((lokal - min) / Swift.max(0.1, max - min))
            let griffBreite: CGFloat = 64
            let x = (breite - griffBreite) * anteil
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.6, blue: 1), Color(red: 1, green: 0.75, blue: 0.3), .orange, Color(red: 0.95, green: 0.3, blue: 0.2)],
                                         startPoint: .leading, endPoint: .trailing))
                    .opacity(0.35)
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.6, blue: 1), .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + griffBreite)
                    .opacity(0.85)
                Text(Logik.formatTemp(lokal))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: griffBreite, height: hoehe - 6)
                    .background(.white.opacity(0.9), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: zieht ? 4 : 2, y: 1)
                    .offset(x: x + 3)
                    .scaleEffect(zieht ? 1.06 : 1)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    zieht = true
                    let a = Swift.min(1, Swift.max(0, (g.location.x - griffBreite / 2) / Swift.max(1, breite - griffBreite)))
                    lokal = ((min + Double(a) * (max - min)) / schritt).rounded() * schritt
                }
                .onEnded { _ in
                    zieht = false
                    losgelassen = Date()
                    setzen(lokal)
                })
        }
        .frame(height: hoehe)
        .animation(.snappy(duration: 0.18), value: zieht)
        .onAppear { lokal = wert }
        .onChange(of: wert) { _, neu in
            // kurz nach dem Loslassen alte Rückmeldungen nicht übernehmen (der Griff würde springen)
            if !zieht && Date().timeIntervalSince(losgelassen) > 1.5 { withAnimation(.smooth) { lokal = neu } }
        }
        .accessibilityElement()
        .accessibilityLabel("Zieltemperatur")
        .accessibilityValue(Logik.formatTemp(lokal))
        .accessibilityAdjustableAction { r in
            switch r {
            case .increment: lokal = Swift.min(max, lokal + schritt)
            case .decrement: lokal = Swift.max(min, lokal - schritt)
            @unknown default: break
            }
            setzen(lokal)
        }
    }
}

/// Verlauf der letzten 24 Stunden: Ist-Temperatur, Zieltemperatur (gestrichelt) und die
/// Zeiten, in denen geheizt wurde (orange hinterlegt). Beim Überfahren Uhrzeit und Werte.
struct KlimaDiagramm: View {
    let verlauf: KlimaVerlauf?
    @State private var auswahl: Date?

    var body: some View {
        if let v = verlauf, !(v.ist.isEmpty && v.ziel.isEmpty) {
            let werte = (v.ist + v.ziel).map(\.w)
            let lo = ((werte.min() ?? 18) - 0.5).rounded(.down), hi = ((werte.max() ?? 22) + 0.5).rounded(.up)
            let jetzt = Date()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    legende(.accentColor, T("Ist"))
                    legende(.orange, T("Ziel"), gestrichelt: true)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(.orange.opacity(0.25)).frame(width: 12, height: 8)
                        Text(T("heizt"))
                    }
                    Spacer()
                    Text(T("24 Stunden")).foregroundStyle(.tertiary)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Chart {
                    ForEach(v.heizen) { p in
                        RectangleMark(xStart: .value("Von", Swift.max(p.von, jetzt.addingTimeInterval(-86400))), xEnd: .value("Bis", p.bis))
                            .foregroundStyle(.orange.opacity(0.16))
                    }
                    ForEach(v.ziel) { p in
                        LineMark(x: .value("Zeit", p.t), y: .value("Grad", p.w), series: .value("Art", T("Ziel")))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    ForEach(v.ist) { p in
                        LineMark(x: .value("Zeit", p.t), y: .value("Grad", p.w), series: .value("Art", T("Ist")))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    if let auswahl {
                        RuleMark(x: .value("Zeit", auswahl))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                hinweis(v, auswahl)
                            }
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartXScale(domain: jetzt.addingTimeInterval(-86400)...jetzt)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { wert in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        AxisValueLabel {
                            if let d = wert.as(Date.self) {
                                Text(String(format: "%02d:00", Calendar.current.component(.hour, from: d))).fixedSize()
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { wert in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        AxisValueLabel { if let w = wert.as(Double.self) { Text("\(Int(w))°") } }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let ort):
                                    guard let rahmen = proxy.plotFrame else { return }
                                    auswahl = proxy.value(atX: ort.x - geo[rahmen].origin.x)
                                case .ended:
                                    auswahl = nil
                                }
                            }
                    }
                }
            }
            .padding(10)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack {
                Spacer()
                if verlauf == nil { ProgressView().controlSize(.small) } else { Text(T("Kein Verlauf vorhanden")).font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func legende(_ farbe: Color, _ text: String, gestrichelt: Bool = false) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(farbe).frame(width: 12, height: 3).opacity(gestrichelt ? 0.8 : 1)
            Text(text)
        }
    }

    private func hinweis(_ v: KlimaVerlauf, _ t: Date) -> some View {
        let ist = v.ist.last { $0.t <= t }?.w
        let ziel = v.ziel.last { $0.t <= t }?.w
        let heizt = v.heizen.contains { $0.von <= t && $0.bis >= t }
        return VStack(spacing: 0) {
            Text(t.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            Text([Logik.formatTemp(ist), ziel.map { T("Ziel ") + Logik.formatTemp($0) }, heizt ? T("heizt") : nil].compactMap { $0 }.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .glas(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
