import SwiftUI
import HALogik

/// Reiter "Rollläden": Rollläden, Markisen, Tore nach Raum – auf, stopp, zu, Position.
struct RolllaedenSeite: View {
    let ha: HaVerbindung

    /// Für „Alle auf/zu“: keine Tore und Türen
    private var ohneTore: [Rollladen] {
        ha.rolllaeden.filter { !Logik.istTor(ha.zustaende[$0.id]) && Logik.istVerfuegbar(ha.zustaende[$0.id]) }
    }
    private var offenAnzahl: Int {
        ha.rolllaeden.filter { let s = Logik.rollladenStatus(ha.zustaende[$0.id]); return s.verfuegbar && s.position != 0 }.count
    }

    var body: some View {
        let liste = ha.rolllaeden
        let mitRaeumen = liste.contains { !$0.raum.isEmpty }
        ScrollView {
            LazyVStack(spacing: 8) {
                UebersichtKarte(symbol: "blinds.horizontal.open",
                                titel: T("%1 von %2 offen", "\(offenAnzahl)", "\(liste.count)"),
                                untertitel: T("Tore bleiben bei „Alle“ unberührt"),
                                anteil: liste.isEmpty ? 0 : Double(offenAnzahl) / Double(liste.count),
                                farbe: .accentColor) {
                    if ohneTore.count > 1 {
                        GlasGruppe(abstand: 6) {
                            HStack(spacing: 6) {
                                Button { ohneTore.forEach { ha.rollladen($0.id, .auf) } } label: { Label(T("Alle auf"), systemImage: "chevron.up") }
                                    .help(T("Alle auf"))
                                Button { ohneTore.forEach { ha.rollladen($0.id, .zu) } } label: { Label(T("Alle zu"), systemImage: "chevron.down") }
                                    .help(T("Alle zu"))
                            }
                            .labelStyle(.iconOnly)
                            .glasKnopf()
                            .buttonBorderShape(.circle)
                        }
                    }
                }
                ForEach(Array(liste.enumerated()), id: \.element.id) { i, r in
                    if mitRaeumen && (i == 0 || liste[i - 1].raum != r.raum) {
                        Text(r.raum.isEmpty ? T("Ohne Raum") : r.raum)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .padding(.top, 4)
                    }
                    RollladenZeile(ha: ha, eintrag: r)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 2)
        }
    }
}

struct RollladenZeile: View {
    let ha: HaVerbindung
    let eintrag: Rollladen

    var body: some View {
        let e = ha.zustaende[eintrag.id]
        let s = Logik.rollladenStatus(e)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SymbolKreis(symbol: s.position == 0 ? "blinds.horizontal.closed" : "blinds.horizontal.open",
                            farbe: s.bewegt ? .accentColor : nil, verfuegbar: s.verfuegbar)
                VStack(alignment: .leading, spacing: 1) {
                    Text(eintrag.name).font(.body.weight(.semibold)).lineLimit(1)
                    Text(Logik.rollladenText(e)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 4)
                GlasGruppe(abstand: 4) {
                    HStack(spacing: 4) {
                        Button { ha.rollladen(eintrag.id, .auf) } label: { Label(T("Öffnen"), systemImage: "chevron.up") }
                            .disabled(!s.kannAuf).help(T("Öffnen"))
                        if s.kannStopp {
                            Button { ha.rollladen(eintrag.id, .stopp) } label: { Label(T("Anhalten"), systemImage: "stop.fill") }
                                .help(T("Anhalten"))
                        }
                        Button { ha.rollladen(eintrag.id, .zu) } label: { Label(T("Schließen"), systemImage: "chevron.down") }
                            .disabled(!s.kannZu).help(T("Schließen"))
                    }
                    .labelStyle(.iconOnly)
                    .glasKnopf()
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .disabled(!s.verfuegbar)
                }
            }
            if s.kannPosition {
                PositionsRegler(wert: s.position ?? 0) { ha.rollladen(eintrag.id, position: $0) }
                    .disabled(!s.verfuegbar)
                    .accessibilityLabel(T("%1: Position", eintrag.name))
            }
        }
        .karte(farbe: s.bewegt ? Color.accentColor.opacity(0.18) : nil)
        .anheben()
    }
}

/// Position als Kapsel wie der Helligkeitsregler – sendet erst beim Loslassen (Motoren mögen
/// keine Befehlsflut), auf 5 % gerundet. Links zu, rechts offen.
struct PositionsRegler: View {
    let wert: Int
    let setzen: (Int) -> Void

    @State private var lokal: Double = 0
    @State private var zieht = false
    @State private var losgelassen = Date.distantPast
    private let hoehe: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width
            let fuellung = max(hoehe, hoehe + (breite - hoehe) * CGFloat(lokal / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.55), Color.accentColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fuellung)
                HStack {
                    Image(systemName: "blinds.horizontal.closed")
                    Spacer()
                    Text("\(Int(lokal.rounded())) %").monospacedDigit()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        zieht = true
                        lokal = min(100, max(0, Double((g.location.x - hoehe / 2) / max(1, breite - hoehe)) * 100))
                    }
                    .onEnded { _ in
                        zieht = false
                        losgelassen = Date()
                        lokal = (lokal / 5).rounded() * 5
                        setzen(Int(lokal))
                    }
            )
        }
        .frame(height: hoehe)
        .scaleEffect(zieht ? 1.02 : 1)
        .animation(.snappy(duration: 0.18), value: zieht)
        .onAppear { lokal = Double(wert) }
        .onChange(of: wert) { _, neu in
            if !zieht && Date().timeIntervalSince(losgelassen) > 1.5 { withAnimation(.smooth) { lokal = Double(neu) } }
        }
        .accessibilityElement()
        .accessibilityValue(T("%1 Prozent", "\(Int(lokal.rounded()))"))
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: lokal = min(100, lokal + 10)
            case .decrement: lokal = max(0, lokal - 10)
            @unknown default: break
            }
            setzen(Int(lokal))
        }
    }
}
