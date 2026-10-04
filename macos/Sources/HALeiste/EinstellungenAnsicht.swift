import SwiftUI
import HALogik

/// Einstellungsfenster. Adresse und Token werden erst nach erfolgreichem Test übernommen –
/// so landen beim Tippen keine halben Token bei Home Assistant (die IP würde sonst gesperrt).
struct EinstellungenAnsicht: View {
    let ha: HaVerbindung
    @Bindable var einstellungen: Einstellungen

    @State private var adresse = ""
    @State private var token = ""
    @State private var probe = HaVerbindung(liveErlaubt: false)
    @State private var testLaeuft = false
    @State private var ergebnis: (ok: Bool, text: String)?
    @State private var anmeldeStart = false

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
                            Text(ha.live ? "Live verbunden" : ha.verbunden ? "Verbunden" : ha.eingerichtet ? "Nicht verbunden" : "Nicht eingerichtet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Verbindung") {
                TextField("Adresse", text: $adresse, prompt: Text("http://homeassistant.local:8123"))
                SecureField("Zugriffstoken", text: $token, prompt: Text("Langlebiger Zugriffstoken"))
                Text("In Home Assistant: unten links auf deinen Namen → Sicherheit → „Langlebige Zugriffstoken“ → Token erstellen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        Task { await verbinden() }
                    } label: {
                        Label("Verbinden", systemImage: "link")
                    }
                    .glasKnopfBetont()
                    .disabled(adresse.isEmpty || token.isEmpty || testLaeuft)
                    if testLaeuft { ProgressView().controlSize(.small) }
                    Spacer()
                    if !einstellungen.token.isEmpty {
                        Button("Abmelden", role: .destructive) {
                            einstellungen.token = ""
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
            }

            Section("Lampen") {
                Toggle("Lampengruppen zeigen", isOn: $einstellungen.zeigeGruppen)
                Toggle("Auch klassische Gruppen (group.*) mit Lampen", isOn: $einstellungen.alteGruppen)
                Toggle("Räume (Bereiche aus Home Assistant) zeigen", isOn: $einstellungen.zeigeRaeume)
            }

            Section {
                Toggle("Nur Schalter vom Typ „Steckdose“ zeigen", isOn: $einstellungen.nurSteckdosen)
                Picker("Hauptzähler", selection: $einstellungen.hauptzaehler) {
                    Text("Keiner (Summe der Messsteckdosen)").tag("")
                    ForEach(hauptzaehlerListe, id: \.id) { e in
                        Text(e.name).tag(e.id)
                    }
                }
            } header: {
                Text("Steckdosen & Energie")
            } footer: {
                Text("Leistungssensor deines Stromzählers (z. B. Shelly 3EM, Tibber Pulse).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Strom", isOn: $einstellungen.zeigeStromHeute)
                Toggle("Wasser", isOn: $einstellungen.zeigeWasserHeute)
                Toggle("Gas", isOn: $einstellungen.zeigeGasHeute)
                zaehlerWahl("Stromzähler", klasse: "energy", auswahl: $einstellungen.zaehlerStrom)
                    .disabled(!einstellungen.zeigeStromHeute)
                zaehlerWahl("Wasserzähler", klasse: "water", auswahl: $einstellungen.zaehlerWasser)
                    .disabled(!einstellungen.zeigeWasserHeute)
                zaehlerWahl("Gaszähler", klasse: "gas", auswahl: $einstellungen.zaehlerGas)
                    .disabled(!einstellungen.zeigeGasHeute)
            } header: {
                Text("Verbrauch heute")
            } footer: {
                Text("„Automatisch“ nimmt die Zähler aus dem Energie-Dashboard von Home Assistant und rechnet genau wie dort.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sonstiges") {
                Toggle("Zahl der eingeschalteten Lampen in der Menüleiste", isOn: $einstellungen.zeigeAnzahl)
                Toggle("Beim Anmelden starten", isOn: $anmeldeStart)
                    .onChange(of: anmeldeStart) { _, neu in
                        if neu != einstellungen.anmeldeStart { einstellungen.anmeldeStart = neu }
                    }
                TextField("Ausblenden", text: $einstellungen.ausgeblendet, prompt: Text("light.flur_nachtlicht, switch.*_kindersicherung"))
                Stepper("Abfrage alle \(einstellungen.abfrageSekunden) s (ohne Live-Verbindung)",
                        value: $einstellungen.abfrageSekunden, in: 3...600)
            }

            Section {
                Link(destination: URL(string: "https://github.com/Teyro/homeassistant-leiste")!) {
                    Label("Projektseite und Updates auf GitHub", systemImage: "arrow.up.forward.square")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
        .onAppear {
            adresse = einstellungen.adresse
            token = einstellungen.token
            anmeldeStart = einstellungen.anmeldeStart
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// Aus der laufenden Verbindung, sonst aus dem Verbindungstest
    private var quelle: HaVerbindung { probe.verbunden ? probe : ha }

    private var hauptzaehlerListe: [(id: String, name: String)] {
        var liste = quelle.leistung.map { (id: $0.id, name: "\($0.name) (\(Logik.formatWatt($0.watt)))") }
        if let h = ha.zustaende[einstellungen.hauptzaehler], !liste.contains(where: { $0.id == h.id }) {
            liste.insert((h.id, "\(h.name) (\(h.state) \(h.einheit))"), at: 0)
        } else if !einstellungen.hauptzaehler.isEmpty && !liste.contains(where: { $0.id == einstellungen.hauptzaehler }) {
            liste.insert((einstellungen.hauptzaehler, einstellungen.hauptzaehler), at: 0)
        }
        return liste
    }

    private func zaehlerWahl(_ titel: String, klasse: String, auswahl: Binding<String>) -> some View {
        let sensoren = quelle.sensoren(klasse: klasse)
        return Picker(titel, selection: auswahl) {
            Text("Automatisch (Energie-Dashboard)").tag("")
            if !auswahl.wrappedValue.isEmpty && !sensoren.contains(where: { $0.id == auswahl.wrappedValue }) {
                Text(auswahl.wrappedValue).tag(auswahl.wrappedValue)
            }
            ForEach(sensoren, id: \.id) { e in
                Text("\(e.name) (\(e.state) \(e.einheit))").tag(e.id)
            }
        }
    }

    private func verbinden() async {
        testLaeuft = true
        ergebnis = nil
        probe.verbinde(adresse: adresse, token: token)
        await probe.aktualisieren()
        testLaeuft = false
        if probe.verbunden {
            ergebnis = (true, "Verbunden: \(probe.lichter.count) Lampen, \(probe.gruppen.count) Gruppen, \(probe.schalter.count) Steckdosen, \(probe.leistung.count) Leistungssensoren.")
            einstellungen.adresse = adresse
            einstellungen.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
            // Gleiche Werte wie vorher (z. B. Token in Home Assistant wieder freigegeben): neu versuchen
            if ha.abgelehnt || !ha.verbunden { ha.erneutVersuchen() }
        } else {
            ergebnis = (false, probe.fehler.isEmpty ? "Keine Verbindung." : probe.fehler)
        }
    }
}
