import SwiftUI
import MapKit
import HALogik

/// Reiter "Personen": wer ist wo – Karte wie bei "Wo ist?", darunter die Liste mit Ort,
/// seit wann und Entfernung von zu Hause. Dazu, ob gerade geheizt wird.
struct PersonenSeite: View {
    let ha: HaVerbindung
    @State private var position: MapCameraPosition = .automatic
    @State private var auswahl: String?

    private var heim: Zone? { ha.zonen.first(where: \.heim) }

    var body: some View {
        let zuhause = ha.personen.filter { $0.zustand == "home" }.count
        let heizen = ha.heizungen.filter { Logik.raumKlima($0, ha.zustaende).heizt }.count
        let mitThermostat = ha.heizungen.filter { !$0.klima.isEmpty }.count
        ScrollView {
            VStack(spacing: 8) {
                karte
                    .frame(height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

                HStack(spacing: 8) {
                    Label(zuhause == 0 ? T("Niemand zu Hause") : zuhause == ha.personen.count ? T("Alle zu Hause") : T("%1 von %2 zu Hause", "\(zuhause)", "\(ha.personen.count)"),
                          systemImage: "house.fill")
                    Spacer()
                    if mitThermostat > 0 {
                        Label(heizen == 0 ? T("Heizung ruht") : T("Heizung an (%1 von %2)", "\(heizen)", "\(mitThermostat)"), systemImage: "heater.vertical.fill")
                            .foregroundStyle(heizen > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)

                ForEach(ha.personen) { p in personZeile(p) }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 2)
        }
    }

    private var karte: some View {
        Map(position: $position, selection: $auswahl) {
            ForEach(ha.zonen) { z in
                let c = CLLocationCoordinate2D(latitude: z.lat, longitude: z.lon)
                MapCircle(center: c, radius: z.radius)
                    .foregroundStyle((z.heim ? Color.green : Color.accentColor).opacity(0.15))
                    .stroke(z.heim ? Color.green : Color.accentColor, lineWidth: 1)
                Annotation(z.name, coordinate: c, anchor: .center) {
                    Image(systemName: z.heim ? "house.fill" : "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(z.heim ? Color.green : Color.accentColor, in: Circle())
                }
            }
            ForEach(ha.personen.filter { $0.lat != nil && $0.lon != nil }) { p in
                Annotation(p.name, coordinate: CLLocationCoordinate2D(latitude: p.lat!, longitude: p.lon!), anchor: .bottom) {
                    PersonBild(person: p, groesse: auswahl == p.id ? 40 : 32)
                }
                .tag(p.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapZoomStepper()
            MapCompass()
        }
        .overlay(alignment: .topLeading) {
            Button {
                withAnimation { position = .automatic; auswahl = nil }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help(T("Alle zeigen"))
            .glasKnopf()
            .buttonBorderShape(.circle)
            .padding(8)
        }
    }

    private func personZeile(_ p: Person) -> some View {
        let km = Logik.entfernung(p.lat, p.lon, heim?.lat, heim?.lon)
        return HStack(spacing: 10) {
            PersonBild(person: p, groesse: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.body.weight(.semibold))
                TimelineView(.periodic(from: .now, by: 60)) { k in
                    Text([Logik.ortText(p.zustand), Logik.formatSeit(p.seit, jetzt: k.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(p.zustand == "home" ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
                }
            }
            Spacer()
            if p.zustand != "home", let km {
                Text(Logik.formatEntfernung(km))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .karte(farbe: auswahl == p.id ? Color.accentColor.opacity(0.2) : nil)
        .anheben()
        .contentShape(Rectangle())
        .onTapGesture {
            auswahl = p.id
            if let lat = p.lat, let lon = p.lon {
                withAnimation(.smooth) {
                    position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                                          latitudinalMeters: 1500, longitudinalMeters: 1500))
                }
            }
        }
    }
}

/// Runder Kreis mit Initialen in der Farbe der Person, grüner Punkt = zu Hause
struct PersonBild: View {
    let person: Person
    var groesse: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: person.farbe).gradient)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .overlay(Text(Logik.initialen(person.name)).font(.system(size: groesse * 0.38, weight: .bold)).foregroundStyle(.white))
                .frame(width: groesse, height: groesse)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            if person.zustand == "home" {
                Circle()
                    .fill(.green)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: groesse * 0.34, height: groesse * 0.34)
            }
        }
        .animation(.snappy, value: groesse)
    }
}

extension Color {
    /// "#rrggbb" → Farbe
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt32(s, radix: 16) ?? 0x3daee9
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}
