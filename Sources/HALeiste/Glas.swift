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

/// Symbol im Kreis (wie im Kontrollzentrum): an = gefüllt in der Lampenfarbe
struct SymbolKreis: View {
    let symbol: String
    var farbe: Color?
    var verfuegbar = true
    var groesse: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(farbe.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(Color.primary.opacity(0.1)))
            Image(systemName: symbol)
                .font(.system(size: groesse * 0.45, weight: .semibold))
                .foregroundStyle(farbe != nil ? AnyShapeStyle(Color.black.opacity(0.65)) : AnyShapeStyle(.secondary))
        }
        .frame(width: groesse, height: groesse)
        .opacity(verfuegbar ? 1 : 0.4)
        .shadow(color: (farbe ?? .clear).opacity(0.5), radius: farbe != nil ? 6 : 0)
    }
}

/// Abschnittsüberschrift, optional zum Auf- und Zuklappen und mit Anzahl
struct Abschnitt: View {
    let titel: String
    var anzahl: Int?
    var offen: Binding<Bool>?

    var body: some View {
        Button {
            withAnimation(.snappy) { offen?.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                if let offen {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(offen.wrappedValue ? 90 : 0))
                }
                Text(titel).font(.subheadline.weight(.semibold))
                if let anzahl {
                    Text("\(anzahl)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(offen == nil)
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

/// Helligkeitsregler: schickt beim Ziehen höchstens alle 0,3 s und am Ende den Wert
struct HelligkeitsRegler: View {
    let wert: Int
    let farbe: Color
    let setzen: (Double) -> Void

    @State private var lokal: Double = 0
    @State private var zieht = false
    @State private var zuletzt = Date.distantPast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.min").font(.caption).foregroundStyle(.secondary)
            Slider(value: $lokal, in: 1...100, onEditingChanged: { aktiv in
                zieht = aktiv
                if !aktiv { setzen(lokal) }
            })
            .tint(farbe)
            .controlSize(.small)
            .onChange(of: lokal) { _, neu in
                guard zieht, Date().timeIntervalSince(zuletzt) > 0.3 else { return }
                zuletzt = Date()
                setzen(neu)
            }
            Text("\(Int(lokal.rounded())) %")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .onAppear { lokal = Double(max(1, wert)) }
        .onChange(of: wert) { _, neu in if !zieht { lokal = Double(max(1, neu)) } }
    }
}
