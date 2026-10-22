import SwiftUI
import MapKit
import HALogik

/// Reiter "Wo ist?" (optional, ersetzt "Personen"): Personen, Geräte und Objekte mit Standort – auch aus weiteren
/// Home-Assistant-Instanzen – auf Apple-Karten, mit Akku, Entfernung, Route und dem Weg der letzten 30 Minuten bis
/// 6 Stunden. Weitere Instanzen werden nur abgefragt, solange der Reiter offen ist (jede Minute).
struct WoIstSeite: View {
    let kern: Kern
    @State private var position: MapCameraPosition = .automatic
    @State private var fremde: [String: [Ort]] = [:]
    @State private var fremdeFehler: [String: String] = [:]
    @State private var wege: [String: [SpurPunkt]] = [:]
    @State private var wegeStand = Date.distantPast

    private var ha: HaVerbindung { kern.ha }
    private var zustand: PanelZustand { kern.panel }
    private var weitere: [Instanz] { kern.einstellungen.instanzen.filter { $0.id != kern.aktiv?.id && !$0.adresse.isEmpty } }
    private var alle: [Ort] { ha.orter + weitere.flatMap { fremde[$0.id] ?? [] } }
    private var gezeigt: [Ort] { alle.filter { $0.art == zustand.woArt } }
    private var heim: Zone? { ha.zonen.first(where: \.heim) }
    private var minuten: Int { Logik.verlaufStufen[zustand.woStufe] }
    private var versteckt: [String] { kern.einstellungen.ausgeblendet.split(whereSeparator: { " \t\n,;".contains($0) }).map(String.init) }

    private struct Weg: Identifiable {
        let id: String
        let farbe: Color
        let punkte: [SpurPunkt]
        var koordinaten: [CLLocationCoordinate2D] { punkte.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } }
    }
    private func wegVon(_ o: Ort) -> [SpurPunkt] { Logik.spurSeit(wege[o.id] ?? [], minuten: minuten, aktuell: o) }
    private var sichtbareWege: [Weg] {
        let wen = zustand.woAuswahl.map { id in alle.filter { $0.id == id } } ?? gezeigt
        return wen.compactMap { o in
            let p = wegVon(o)
            return p.isEmpty ? nil : Weg(id: o.id, farbe: wen.count == 1 ? .accentColor : Color(hex: o.farbe), punkte: p)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                karte
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

                Picker(T("Gruppe"), selection: Bindable(zustand).woArt) {
                    ForEach(OrtArt.allCases) { a in
                        let n = alle.filter { $0.art == a }.count
                        Text(n > 0 ? "\(artTitel(a)) \(n)" : artTitel(a)).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 8) {
                    if !fremdeFehler.isEmpty {
                        Label(fremdeFehler.values.sorted().joined(separator: " · "), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                    Spacer()
                    Picker(selection: Bindable(zustand).woStufe) {
                        ForEach(Logik.verlaufStufen.indices, id: \.self) { i in
                            Text(i == 0 ? T("Kein Weg") : T("Weg: %1", Logik.verlaufStufeText(Logik.verlaufStufen[i]))).tag(i)
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .fixedSize()
                    .help(T("Wo war jemand in den letzten 30 Minuten, 3 oder 6 Stunden?"))
                }
                .padding(.horizontal, 4)

                if gezeigt.isEmpty {
                    ContentUnavailableView {
                        Label(T("Nichts mit Standort in dieser Gruppe"), systemImage: artSymbol(zustand.woArt))
                    } description: {
                        if zustand.woArt != .personen {
                            Text(T("Ortungsgeräte (device_tracker) mit GPS, z. B. aus der Companion-App oder von Trackern, erscheinen hier."))
                        }
                    }
                    .frame(minHeight: 160)
                } else {
                    ForEach(gezeigt) { o in zeile(o) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 2)
        }
        .task(id: weitere.map(\.id)) {
            while !Task.isCancelled {
                await fremdeLaden()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .task(id: zustand.woStufe) { await wegeLaden(); einpassen() }
        .onChange(of: zustand.woArt) { zustand.woAuswahl = nil; einpassen() }
        .onChange(of: zustand.woAuswahl) { einpassen() }
    }

    // MARK: Karte

    private var karte: some View {
        Map(position: $position, selection: Bindable(zustand).woAuswahl) {
            ForEach(ha.zonen) { z in
                MapCircle(center: CLLocationCoordinate2D(latitude: z.lat, longitude: z.lon), radius: z.radius)
                    .foregroundStyle((z.heim ? Color.green : Color.accentColor).opacity(0.12))
                    .stroke(z.heim ? Color.green : Color.accentColor, lineWidth: 1)
            }
            ForEach(sichtbareWege) { w in
                MapPolyline(coordinates: w.koordinaten)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: w.koordinaten)
                    .stroke(w.farbe, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // Startpunkt mit Uhrzeit
            ForEach(sichtbareWege) { w in
                Annotation("", coordinate: w.koordinaten[0], anchor: .bottom) {
                    VStack(spacing: 3) {
                        Text(w.punkte[0].t.formatted(date: .omitted, time: .shortened))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.regularMaterial, in: Capsule())
                        Circle().fill(w.farbe).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    .offset(y: 5)
                }
            }
            ForEach(gezeigt) { o in
                Annotation(o.name, coordinate: CLLocationCoordinate2D(latitude: o.lat, longitude: o.lon), anchor: .bottom) {
                    OrtNadel(ort: o, gewaehlt: zustand.woAuswahl == o.id)
                }
                .tag(o.id)
            }
        }
        .mapStyle(zustand.woSatellit ? .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll) : .standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapZoomStepper()
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Button {
                    zustand.woAuswahl = nil
                    withAnimation { position = .automatic }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help(T("Alle zeigen"))
                Button {
                    zustand.woSatellit.toggle()
                } label: {
                    Image(systemName: zustand.woSatellit ? "map" : "globe.europe.africa.fill")
                }
                .help(zustand.woSatellit ? T("Straßenkarte") : T("Satellitenbild"))
            }
            .glasKnopf()
            .buttonBorderShape(.circle)
            .padding(8)
        }
    }

    /// Ausschnitt: Weg, sonst den gewählten Eintrag, sonst alle der Gruppe
    private func einpassen() {
        let wege = sichtbareWege
        var punkte = wege.flatMap(\.koordinaten)
        if punkte.isEmpty, let id = zustand.woAuswahl, let o = alle.first(where: { $0.id == id }) {
            withAnimation(.smooth) {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: o.lat, longitude: o.lon), latitudinalMeters: 1500, longitudinalMeters: 1500))
            }
            return
        }
        if punkte.isEmpty { punkte = gezeigt.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } }
        guard !punkte.isEmpty else { return }
        var r = MKMapRect.null
        for p in punkte { r = r.union(MKMapRect(origin: MKMapPoint(p), size: MKMapSize(width: 1, height: 1))) }
        let rand = Swift.max(r.width, r.height) * 0.25 + 800
        withAnimation(.smooth) { position = .rect(r.insetBy(dx: -rand, dy: -rand)) }
    }

    // MARK: Liste

    private func zeile(_ o: Ort) -> some View {
        let gewaehlt = zustand.woAuswahl == o.id
        let km = o.zustand == "home" ? nil : Logik.entfernung(o.lat, o.lon, heim?.lat, heim?.lon)
        let weg = gewaehlt ? wegVon(o) : []
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                OrtBild(ort: o, groesse: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(o.name).font(.body.weight(.semibold)).lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 60)) { k in
                        Text([o.ort, Logik.formatSeit(o.seit, jetzt: k.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(o.zustand == "home" ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                    }
                    if let start = weg.first {
                        Text(T("%1 unterwegs seit %2", Logik.formatEntfernung(Logik.streckeKm(weg)), start.t.formatted(date: .omitted, time: .shortened)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let km {
                        Text(Logik.formatEntfernung(km)).font(.callout.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    if let a = o.akku {
                        Label("\(a) %", systemImage: akkuSymbol(a))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(a <= 20 ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                    }
                }
            }
            if gewaehlt {
                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "maps://?daddr=\(o.lat),\(o.lon)") { NSWorkspace.shared.open(url) }
                    } label: {
                        Label(T("Route"), systemImage: "car.fill").frame(maxWidth: .infinity)
                    }
                    .help(T("Route in Apple Karten"))
                    Button {
                        zustand.woStufe = (zustand.woStufe + 1) % Logik.verlaufStufen.count
                    } label: {
                        Label(minuten > 0 ? T("Weg: %1", Logik.verlaufStufeText(minuten)) : T("Weg zeigen"), systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                }
                .glasKnopf()
                .padding(.leading, 44)
            }
        }
        .karte(farbe: gewaehlt ? Color.accentColor.opacity(0.2) : nil)
        .anheben()
        .contentShape(Rectangle())
        .onTapGesture { zustand.woAuswahl = gewaehlt ? nil : o.id }
    }

    private func artTitel(_ a: OrtArt) -> String {
        switch a { case .personen: T("Personen"); case .geraete: T("Geräte"); case .objekte: T("Objekte") }
    }
    private func artSymbol(_ a: OrtArt) -> String {
        switch a { case .personen: "person.2.fill"; case .geraete: "iphone"; case .objekte: "airtag.fill" }
    }
    private func akkuSymbol(_ p: Int) -> String {
        p >= 88 ? "battery.100percent" : p >= 63 ? "battery.75percent" : p >= 38 ? "battery.50percent" : p >= 13 ? "battery.25percent" : "battery.0percent"
    }

    // MARK: Laden

    private func fremdeLaden() async {
        for i in weitere {
            let name = i.anzeigename
            guard let antwort = await HaVerbindung.holen(i.adresse, kern.einstellungen.token(i.id), "/api/states") else {
                fremdeFehler[i.id] = T("„%1“ nicht erreichbar", name)
                continue
            }
            var z: [String: Entitaet] = [:]
            for j in antwort.liste ?? [] { if let e = Entitaet(json: j), Logik.relevant(e.id, e, "") { z[e.id] = e } }
            let o = Logik.orter(z, versteckt: versteckt, instanz: i.id, instanzName: name, weitere: true)
            if fremde[i.id] != o { fremde[i.id] = o }
            fremdeFehler[i.id] = nil
        }
    }

    private func wegeLaden() async {
        guard minuten > 0, Date().timeIntervalSince(wegeStand) > 180 else { return }
        wegeStand = Date()
        let ab = Date().addingTimeInterval(-6 * 3600)
        let eigene = ha.orter
        if let a = await ha.ortVerlauf(eigene.map(\.entitaet), ab: ab) {
            for o in eigene { wege[o.id] = Logik.ortSpur(a, entitaet: o.entitaet, ab: ab) }
        }
        for i in weitere {
            let liste = fremde[i.id] ?? []
            guard !liste.isEmpty else { continue }
            let pfad = "/api/history/period/" + HaVerbindung.kodiert(Logik.isoText(ab)) + "?filter_entity_id="
                + HaVerbindung.kodiert(liste.map(\.entitaet).joined(separator: ",")) + "&significant_changes_only=0"
            if let a = await HaVerbindung.holen(i.adresse, kern.einstellungen.token(i.id), pfad) {
                for o in liste { wege[o.id] = Logik.ortSpur(a, entitaet: o.entitaet, ab: ab) }
            }
        }
    }
}

/// Runder Kreis in der Farbe des Eintrags: Initialen bei Personen, sonst ein Symbol
struct OrtBild: View {
    let ort: Ort
    var groesse: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: ort.farbe).gradient)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .overlay {
                    if ort.art == .personen {
                        Text(Logik.initialen(ort.name)).font(.system(size: groesse * 0.38, weight: .bold)).foregroundStyle(.white)
                    } else {
                        Image(systemName: ort.art == .geraete ? "iphone" : "airtag.fill")
                            .font(.system(size: groesse * 0.42, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: groesse, height: groesse)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            if ort.zustand == "home" {
                Circle()
                    .fill(.green)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: groesse * 0.34, height: groesse * 0.34)
            }
        }
    }
}

/// Stecknadel wie in Apples „Wo ist?“: Kreis mit weißem Rand und kleiner Spitze
struct OrtNadel: View {
    let ort: Ort
    let gewaehlt: Bool

    var body: some View {
        VStack(spacing: -3) {
            OrtBild(ort: ort, groesse: gewaehlt ? 42 : 34)
                .overlay(Circle().stroke(gewaehlt ? Color.accentColor : .clear, lineWidth: 3).padding(-1))
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .rotationEffect(.degrees(180))
                .foregroundStyle(gewaehlt ? Color.accentColor : .white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .animation(.snappy, value: gewaehlt)
    }
}
