import SwiftUI
import HALogik

/// Einstellungsfenster: mehrere Home-Assistant-Instanzen (eine als Favorit) und Anzeige.
/// Adresse und Token einer Instanz werden erst nach erfolgreichem Test übernommen – so landen
/// beim Tippen keine halben Token bei Home Assistant (die IP würde sonst gesperrt).
struct EinstellungenAnsicht: View {
    let kern: Kern
    @Bindable var einstellungen: Einstellungen

    init(kern: Kern) {
        self.kern = kern
        self.einstellungen = kern.einstellungen
    }

    @State private var auswahl = ""
    @State private var name = ""
    @State private var adresse = ""
    @State private var token = ""
    @State private var probe = HaVerbindung(liveErlaubt: false)
    @State private var testLaeuft = false
    @State private var ergebnis: (ok: Bool, text: String)?
    @State private var anmeldeStart = false

    private var ha: HaVerbindung { kern.ha }
    private var gewaehlt: Instanz? { einstellungen.instanzen.first { $0.id == auswahl } }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HA Leiste").font(.title2.weight(.semibold))
                        Text("Version \(version) · Home Assistant in der Menüleiste")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            LivePunkt(farbe: ha.live ? .green : ha.verbunden ? .yellow : .red, pulsiert: ha.live)
                            Text(ha.live ? "Live verbunden mit \(kern.aktiv?.anzeigename ?? "")" : ha.verbunden ? "Verbunden" : ha.eingerichtet ? "Nicht verbunden" : "Nicht eingerichtet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(einstellungen.instanzen) { i in instanzZeile(i) }
                Button {
                    let id = Logik.neueInstanzId(einstellungen.instanzen)
                    einstellungen.instanzen.append(Instanz(id: id, favorit: einstellungen.instanzen.isEmpty))
                    waehlen(id)
                } label: {
                    Label("Instanz hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Der Stern markiert den Favoriten – er wird beim Start gezeigt. Wechseln geht im Panel über ⋯ → Instanz wechseln.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let i = gewaehlt {
                Section("Instanz „\(i.anzeigename)“") {
                    TextField("Name", text: $name, prompt: Text("leer = Name aus Home Assistant"))
                        .onSubmit { einstellungen.aendern(i.id) { $0.name = name.trimmingCharacters(in: .whitespaces) } }
                        .onChange(of: name) { _, neu in einstellungen.aendern(i.id) { $0.name = neu.trimmingCharacters(in: .whitespaces) } }
                    TextField("Adresse", text: $adresse, prompt: Text("http://homeassistant.local:8123"))
                    SecureField("Zugriffstoken", text: $token, prompt: Text("Langlebiger Zugriffstoken"))
                    Text("In Home Assistant: unten links auf deinen Namen → Sicherheit → „Langlebige Zugriffstoken“ → Token erstellen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            Task { await verbinden(i.id) }
                        } label: {
                            Label("Verbinden", systemImage: "link")
                        }
                        .glasKnopfBetont()
                        .disabled(adresse.isEmpty || token.isEmpty || testLaeuft)
                        if testLaeuft { ProgressView().controlSize(.small) }
                        Spacer()
                        if !einstellungen.token(i.id).isEmpty {
                            Button("Abmelden", role: .destructive) {
                                einstellungen.setzeToken("", fuer: i.id)
                                token = ""
                                ergebnis = nil
                            }
                            .help("Token aus dem Schlüsselbund entfernen")
                        }
                    }
                    if let ergebnis {
                        Label(ergebnis.text, systemImage: ergebnis.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(ergebnis.ok ? .green : .red)
                            .font(.callout)
                    }
                    Picker("Hauptzähler", selection: Binding(get: { i.hauptzaehler }, set: { v in einstellungen.aendern(i.id) { $0.hauptzaehler = v } })) {
                        Text("Keiner (Summe der Messsteckdosen)").tag("")
                        ForEach(hauptzaehlerListe(i), id: \.id) { e in Text(e.name).tag(e.id) }
                    }
                    zaehlerWahl("Stromzähler", klasse: "energy", wert: i.zaehlerStrom) { v in einstellungen.aendern(i.id) { $0.zaehlerStrom = v } }
                        .disabled(!einstellungen.zeigeStromHeute)
                    zaehlerWahl("Wasserzähler", klasse: "water", wert: i.zaehlerWasser) { v in einstellungen.aendern(i.id) { $0.zaehlerWasser = v } }
                        .disabled(!einstellungen.zeigeWasserHeute)
                    zaehlerWahl("Gaszähler", klasse: "gas", wert: i.zaehlerGas) { v in einstellungen.aendern(i.id) { $0.zaehlerGas = v } }
                        .disabled(!einstellungen.zeigeGasHeute)
                }
            }

            Section("Reiter") {
                Toggle("Heizung (Thermostate und Raumtemperaturen)", isOn: $einstellungen.zeigeHeizung)
                Toggle("Personen mit Karte", isOn: $einstellungen.zeigePersonen)
            }

            Section("Lampen") {
                Toggle("Lampengruppen zeigen", isOn: $einstellungen.zeigeGruppen)
                Toggle("Auch klassische Gruppen (group.*) mit Lampen", isOn: $einstellungen.alteGruppen)
                Toggle("Räume (Bereiche aus Home Assistant) zeigen", isOn: $einstellungen.zeigeRaeume)
                Toggle("Nur Schalter vom Typ „Steckdose“ zeigen", isOn: $einstellungen.nurSteckdosen)
            }

            Section {
                Toggle("Strom", isOn: $einstellungen.zeigeStromHeute)
                Toggle("Wasser", isOn: $einstellungen.zeigeWasserHeute)
                Toggle("Gas", isOn: $einstellungen.zeigeGasHeute)
            } header: {
                Text("Verbrauch heute")
            } footer: {
                Text("Die Zähler kommen automatisch aus dem Energie-Dashboard von Home Assistant oder werden je Instanz oben gewählt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sonstiges") {
                Toggle("Zahl der eingeschalteten Lampen in der Menüleiste", isOn: $einstellungen.zeigeAnzahl)
                Toggle("Automatisch nach Updates suchen (GitHub)", isOn: $einstellungen.updatesSuchen)
                Toggle("Beim Anmelden starten", isOn: $anmeldeStart)
                    .onChange(of: anmeldeStart) { _, neu in
                        if neu != einstellungen.anmeldeStart { einstellungen.anmeldeStart = neu }
                    }
                TextField("Ausblenden", text: $einstellungen.ausgeblendet, prompt: Text("light.flur_nachtlicht, switch.*_kindersicherung"))
                Stepper("Abfrage alle \(einstellungen.abfrageSekunden) s (ohne Live-Verbindung)",
                        value: $einstellungen.abfrageSekunden, in: 3...600)
            }

            Section {
                Text("Widgets für den Schreibtisch: Rechtsklick auf den Schreibtisch → „Widgets bearbeiten …“ → „HA Leiste“.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "https://github.com/Teyro/homeassistant-leiste")!) {
                    Label("Projektseite und Updates auf GitHub", systemImage: "arrow.up.forward.square")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .frame(minHeight: 600)
        .onAppear {
            anmeldeStart = einstellungen.anmeldeStart
            if let i = kern.aktiv ?? einstellungen.instanzen.first { waehlen(i.id) }
        }
    }

    private func instanzZeile(_ i: Instanz) -> some View {
        HStack(spacing: 10) {
            Button {
                einstellungen.alsFavorit(i.id)
            } label: {
                Image(systemName: i.favorit ? "star.fill" : "star")
                    .foregroundStyle(i.favorit ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(i.favorit ? "Favorit: wird beim Start gezeigt" : "Als Favorit festlegen")
            VStack(alignment: .leading, spacing: 1) {
                Text(i.anzeigename).font(.body.weight(.medium))
                Text(i.adresse.isEmpty ? "noch keine Adresse" : i.adresse).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if i.id == kern.aktiv?.id {
                Text("aktiv").font(.caption.weight(.semibold)).foregroundStyle(.green)
            }
            Button(role: .destructive) {
                einstellungen.entfernen(i.id)
                if auswahl == i.id, let erste = einstellungen.instanzen.first { waehlen(erste.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Instanz entfernen")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { waehlen(i.id) }
        .listRowBackground(auswahl == i.id ? Color.accentColor.opacity(0.15) : nil)
    }

    private func waehlen(_ id: String) {
        auswahl = id
        let i = einstellungen.instanzen.first { $0.id == id }
        name = i?.name ?? ""
        adresse = i?.adresse ?? ""
        token = einstellungen.token(id)
        ergebnis = nil
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// Aus dem Verbindungstest, sonst aus der laufenden Verbindung (wenn es die gewählte Instanz ist)
    private func quelle(_ i: Instanz) -> HaVerbindung { probe.verbunden || i.id != kern.aktiv?.id ? probe : ha }

    private func hauptzaehlerListe(_ i: Instanz) -> [(id: String, name: String)] {
        let q = quelle(i)
        var liste = q.leistung.map { (id: $0.id, name: "\($0.name) (\(Logik.formatWatt($0.watt)))") }
        if !i.hauptzaehler.isEmpty && !liste.contains(where: { $0.id == i.hauptzaehler }) {
            let e = q.zustaende[i.hauptzaehler]
            liste.insert((i.hauptzaehler, e.map { "\($0.name) (\($0.state) \($0.einheit))" } ?? i.hauptzaehler), at: 0)
        }
        return liste
    }

    private func zaehlerWahl(_ titel: String, klasse: String, wert: String, setzen: @escaping (String) -> Void) -> some View {
        let sensoren = gewaehlt.map { quelle($0).sensoren(klasse: klasse) } ?? []
        return Picker(titel, selection: Binding(get: { wert }, set: setzen)) {
            Text("Automatisch (Energie-Dashboard)").tag("")
            if !wert.isEmpty && !sensoren.contains(where: { $0.id == wert }) { Text(wert).tag(wert) }
            ForEach(sensoren, id: \.id) { e in Text("\(e.name) (\(e.state) \(e.einheit))").tag(e.id) }
        }
    }

    private func verbinden(_ id: String) async {
        testLaeuft = true
        ergebnis = nil
        probe.verbinde(adresse: adresse, token: token)
        await probe.aktualisieren()
        testLaeuft = false
        if probe.verbunden {
            ergebnis = (true, "Verbunden: \(probe.lichter.count) Lampen, \(probe.schalter.count) Steckdosen, \(probe.heizungen.count) Räume mit Heizung, \(probe.personen.count) Personen.")
            let sauber = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
            einstellungen.setzeToken(token.trimmingCharacters(in: .whitespacesAndNewlines), fuer: id)
            einstellungen.aendern(id) { i in
                i.adresse = sauber
                if i.name.isEmpty && !probe.standortName.isEmpty { i.name = probe.standortName }
            }
            name = einstellungen.instanzen.first { $0.id == id }?.name ?? name
            // Gleiche Werte wie vorher (z. B. Token in Home Assistant wieder freigegeben): neu versuchen
            if id == kern.aktiv?.id && (ha.abgelehnt || !ha.verbunden) { ha.erneutVersuchen() }
        } else {
            ergebnis = (false, probe.fehler.isEmpty ? "Keine Verbindung." : probe.fehler)
        }
    }
}
