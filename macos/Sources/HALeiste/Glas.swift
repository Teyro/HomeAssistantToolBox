import SwiftUI
import HALogik

/// Liquid Glass ab macOS 26, davor das bisherige Material – überall die gleiche Schreibweise.
extension View {
    @ViewBuilder
    func glas<S: Shape>(_ form: S, farbe: Color? = nil, interaktiv: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(Self.glasArt(farbe, interaktiv), in: form)
        } else {
            self.background {
                ZStack {
                    form.fill(.regularMaterial)
                    if let farbe { form.fill(farbe.opacity(0.22)) }
                    form.stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private static func glasArt(_ farbe: Color?, _ interaktiv: Bool) -> Glass {
        var g = Glass.regular
        if let farbe { g = g.tint(farbe) }
        if interaktiv { g = g.interactive() }
        return g
    }

    /// Karte: abgerundetes Glas mit Innenabstand
    func karte(farbe: Color? = nil, eckradius: CGFloat = 16) -> some View {
        self.padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glas(RoundedRectangle(cornerRadius: eckradius, style: .continuous), farbe: farbe)
    }

    /// Runde Glasknöpfe (Werkzeugleiste)
    @ViewBuilder
    func glasKnopf() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glasKnopfBetont() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

/// Mehrere Glasflächen zusammen zeichnen (ab macOS 26 verschmelzen sie weich ineinander)
struct GlasGruppe<Inhalt: View>: View {
    var abstand: CGFloat = 8
    @ViewBuilder var inhalt: Inhalt
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: abstand) { inhalt }
        } else {
            inhalt
        }
    }
}

extension RGB {
    var farbe: Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
}

extension VerbrauchsArt {
    var titel: String {
        switch self {
        case .strom: "Strom"
        case .wasser: "Wasser"
        case .gas: "Gas"
        }
    }
    var symbol: String {
        switch self {
        case .strom: "bolt.fill"
        case .wasser: "drop.fill"
        case .gas: "flame.fill"
        }
    }
    var farbe: Color {
        switch self {
        case .strom: Color(red: 1.0, green: 0.78, blue: 0.2)
        case .wasser: Color(red: 0.2, green: 0.62, blue: 1.0)
        case .gas: Color(red: 1.0, green: 0.5, blue: 0.15)
        }
    }
}

/// Symbol im Kreis (wie im Kontrollzentrum): an = gefüllt in der Lampenfarbe, mit Schein
struct SymbolKreis: View {
    let symbol: String
    var farbe: Color?
    var verfuegbar = true
    var groesse: CGFloat = 32

    var body: some View {
        ZStack {
            if let farbe {
                // weicher Lichtschein hinter dem Kreis
                Circle()
                    .fill(RadialGradient(colors: [farbe.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: groesse * 0.95))
                    .frame(width: groesse * 1.9, height: groesse * 1.9)
                    .allowsHitTesting(false)
            }
            Circle()
                .fill(farbe.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Color.primary.opacity(0.09)))
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(farbe != nil ? 0.35 : 0), .clear], startPoint: .top, endPoint: .center)))
                .overlay(Circle().strokeBorder(.white.opacity(farbe != nil ? 0.35 : 0.06), lineWidth: 0.5))
                .frame(width: groesse, height: groesse)
            Image(systemName: symbol)
                .font(.system(size: groesse * 0.44, weight: .semibold))
                .foregroundStyle(farbe != nil ? AnyShapeStyle(Color.black.opacity(0.62)) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: farbe != nil)
        }
        .frame(width: groesse, height: groesse)
        .opacity(verfuegbar ? 1 : 0.4)
        .animation(.smooth(duration: 0.35), value: farbe)
    }
}

/// Abschnittsüberschrift, optional zum Auf- und Zuklappen und mit Anzahl
struct Abschnitt: View {
    let titel: String
    var symbol: String?
    var anzahl: Int?
    var offen: Binding<Bool>?

    var body: some View {
        if let offen {
            Button {
                withAnimation(.snappy) { offen.wrappedValue.toggle() }
            } label: {
                zeile(offen: offen.wrappedValue)
            }
            .buttonStyle(.plain)
        } else {
            zeile(offen: nil)
        }
    }

    private func zeile(offen: Bool?) -> some View {
        HStack(spacing: 6) {
            if let offen {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .heavy))
                    .rotationEffect(.degrees(offen ? 90 : 0))
            }
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(titel.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
            if let anzahl {
                Text("\(anzahl)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.primary.opacity(0.08), in: Capsule())
            }
            Spacer()
        }
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 1)
    }
}

/// Helligkeitsregler wie im Kontrollzentrum: breite Kapsel, gefüllt in der Lampenfarbe.
/// Schickt beim Ziehen höchstens alle 0,3 s und am Ende den Wert.
struct HelligkeitsRegler: View {
    let wert: Int
    let farbe: Color
    let setzen: (Double) -> Void

    @State private var lokal: Double = 50
    @State private var zieht = false
    @State private var zuletzt = Date.distantPast
    @State private var losgelassen = Date.distantPast
    @State private var ueber = false
    private let hoehe: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width
            let anteil = CGFloat((lokal - 1) / 99)
            let fuellung = max(hoehe, hoehe + (breite - hoehe) * anteil)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [farbe.opacity(0.6), farbe], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fuellung)
                    .shadow(color: farbe.opacity(zieht ? 0.6 : 0.35), radius: zieht ? 8 : 4)
                // Griff am Ende der Füllung
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: hoehe * 0.5)
                    .offset(x: fuellung - 8)
                    .shadow(color: .black.opacity(0.2), radius: 1)
                HStack {
                    Image(systemName: lokal < 40 ? "sun.min.fill" : "sun.max.fill")
                        .foregroundStyle(Color.black.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                    Spacer()
                    Text("\(Int(lokal.rounded())) %")
                        .monospacedDigit()
                        .foregroundStyle(anteil > 0.82 ? AnyShapeStyle(Color.black.opacity(0.6)) : AnyShapeStyle(.secondary))
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(ueber || zieht ? 0.3 : 0.12), lineWidth: 0.5))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        zieht = true
                        lokal = min(100, max(1, 1 + Double((g.location.x - hoehe / 2) / max(1, breite - hoehe)) * 99))
                        if Date().timeIntervalSince(zuletzt) > 0.3 {
                            zuletzt = Date()
                            setzen(lokal)
                        }
                    }
                    .onEnded { _ in
                        zieht = false
                        losgelassen = Date()
                        setzen(lokal)
                    }
            )
        }
        .frame(height: hoehe)
        .scaleEffect(zieht ? 1.02 : 1)
        .animation(.snappy(duration: 0.18), value: zieht)
        .onHover { ueber = $0 }
        .onAppear { lokal = Double(max(1, wert)) }
        .onChange(of: wert) { _, neu in
            // Kurz nach dem Loslassen kommen noch Rückmeldungen zu älteren Zwischenwerten –
            // die würden den Regler zurückspringen lassen.
            if !zieht && Date().timeIntervalSince(losgelassen) > 1.5 {
                withAnimation(.smooth) { lokal = Double(max(1, neu)) }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Helligkeit")
        .accessibilityValue("\(Int(lokal.rounded())) Prozent")
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: lokal = min(100, lokal + 10)
            case .decrement: lokal = max(1, lokal - 10)
            @unknown default: break
            }
            setzen(lokal)
        }
    }
}

/// Übersicht oben im Reiter: Ring mit Anteil, Titel, Untertitel und ein Knopf
struct UebersichtKarte<Knopf: View>: View {
    let symbol: String
    let titel: String
    let untertitel: String
    let anteil: Double
    let farbe: Color
    @ViewBuilder var knopf: Knopf

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.primary.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, anteil)))
                    .stroke(AngularGradient(colors: [farbe.opacity(0.6), farbe], center: .center), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: farbe.opacity(0.5), radius: 3)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(anteil > 0 ? AnyShapeStyle(farbe) : AnyShapeStyle(.secondary))
                    .symbolEffect(.bounce, value: anteil > 0)
            }
            .frame(width: 40, height: 40)
            .animation(.smooth(duration: 0.5), value: anteil)
            VStack(alignment: .leading, spacing: 1) {
                Text(titel).font(.system(size: 15, weight: .semibold)).contentTransition(.numericText())
                Text(untertitel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            knopf
        }
        .karte(farbe: anteil > 0 ? farbe.opacity(0.14) : nil, eckradius: 20)
    }
}

/// Leistung als kleine Plakette (z. B. "62 W" neben einer Steckdose)
struct WattPlakette: View {
    let watt: Double
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold))
            Text(Logik.formatWatt(watt)).font(.system(size: 10.5, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(watt > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
        .background((watt > 0 ? Color.orange : Color.primary).opacity(0.13), in: Capsule())
        .contentTransition(.numericText(value: watt))
        .animation(.snappy, value: watt)
    }
}

/// Pulsierender Punkt für "live verbunden"
struct LivePunkt: View {
    let farbe: Color
    let pulsiert: Bool
    @State private var an = false

    var body: some View {
        ZStack {
            if pulsiert {
                Circle()
                    .fill(farbe.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(an ? 2.4 : 1)
                    .opacity(an ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: an)
            }
            Circle().fill(farbe).frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear { an = true }
    }
}

/// Leichtes Anheben beim Überfahren mit der Maus
struct Anheben: ViewModifier {
    @State private var ueber = false
    func body(content: Content) -> some View {
        content
            .brightness(ueber ? 0.025 : 0)
            .scaleEffect(ueber ? 1.006 : 1)
            .animation(.smooth(duration: 0.2), value: ueber)
            .onHover { ueber = $0 }
    }
}

extension View {
    func anheben() -> some View { modifier(Anheben()) }
}
