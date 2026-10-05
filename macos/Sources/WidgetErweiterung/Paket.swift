import WidgetKit
import SwiftUI
import AppIntents
import HALogik

/// Alle Widgets von Home Assistant ToolBox für den Schreibtisch und die Mitteilungszentrale.
@main
struct HAToolBoxWidgets: WidgetBundle {
    init() { Sprache.laden() }
    var body: some Widget {
        UebersichtWidget()
        LampeWidget()
        SteckdoseWidget()
        HeizungWidget()
        RaumWidget()
        EnergieWidget()
        PersonenWidget()
        WertWidget()
    }
}

// MARK: Zeitleiste: Daten aus der Datei der App, alle 5 Minuten neu (die App stößt bei Änderungen an)

struct Eintrag: TimelineEntry {
    let date: Date
    let daten: Schnappschuss
    let auswahl: String?
}

private func aktuell(_ auswahl: String? = nil) -> Eintrag {
    Eintrag(date: Date(), daten: Schnappschuss.lesen() ?? Schnappschuss(), auswahl: auswahl)
}

struct FesterAnbieter: TimelineProvider {
    func placeholder(in context: Context) -> Eintrag { aktuell() }
    func getSnapshot(in context: Context, completion: @escaping (Eintrag) -> Void) { completion(aktuell()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Eintrag>) -> Void) {
        completion(Timeline(entries: [aktuell()], policy: .after(Date().addingTimeInterval(300))))
    }
}

struct WahlAnbieter<I: WidgetConfigurationIntent & Auswahl>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Eintrag { aktuell() }
    func snapshot(for configuration: I, in context: Context) async -> Eintrag { aktuell(configuration.auswahlId) }
    func timeline(for configuration: I, in context: Context) async -> Timeline<Eintrag> {
        Timeline(entries: [aktuell(configuration.auswahlId)], policy: .after(Date().addingTimeInterval(300)))
    }
}

private func groesse(_ f: WidgetFamily) -> WidgetGroesse {
    switch f {
    case .systemSmall: .klein
    case .systemLarge, .systemExtraLarge: .gross
    default: .mittel
    }
}

/// Hintergrund: leichter Verlauf, passend zum Inhalt
private struct Hintergrund: View {
    var farbe: Color = .accentColor
    var body: some View {
        LinearGradient(colors: [farbe.opacity(0.18), farbe.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(.background)
    }
}

// MARK: Widgets

struct UebersichtWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "uebersicht", provider: FesterAnbieter()) { e in
            UebersichtAnsicht(e: e)
        }
        .configurationDisplayName(T("Übersicht"))
        .description(T("Lampen, Steckdosen, Heizung, Verbrauch und wer zu Hause ist."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
struct UebersichtAnsicht: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        UebersichtKachel(daten: e.daten, groesse: groesse(familie)).containerBackground(for: .widget) { Hintergrund() }
    }
}

struct LampeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "lampe", intent: LampeEinstellung.self, provider: WahlAnbieter<LampeEinstellung>()) { e in
            let l = e.daten.lampen.first { $0.id == e.auswahl }
            LampeKachel(lampe: l).containerBackground(for: .widget) {
                Hintergrund(farbe: l?.an == true ? Color(widgetHex: l?.farbe ?? "#ffc65c") : .gray)
            }
        }
        .configurationDisplayName(T("Lampe"))
        .description(T("Eine Lampe oder Lichtgruppe zum Schalten."))
        .supportedFamilies([.systemSmall])
    }
}

struct SteckdoseWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "steckdose", intent: SteckdoseEinstellung.self, provider: WahlAnbieter<SteckdoseEinstellung>()) { e in
            let d = e.daten.steckdosen.first { $0.id == e.auswahl }
            SteckdoseKachel(dose: d).containerBackground(for: .widget) { Hintergrund(farbe: d?.an == true ? .accentColor : .gray) }
        }
        .configurationDisplayName(T("Steckdose"))
        .description(T("Eine Steckdose mit Verbrauch zum Schalten."))
        .supportedFamilies([.systemSmall])
    }
}

struct HeizungWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "heizung", intent: HeizungEinstellung.self, provider: WahlAnbieter<HeizungEinstellung>()) { e in
            let h = e.daten.heizungen.first { $0.id == e.auswahl }
            HeizungKachel(heizung: h).containerBackground(for: .widget) { Hintergrund(farbe: h?.heizt == true ? .orange : .blue) }
        }
        .configurationDisplayName(T("Heizung"))
        .description(T("Raumtemperatur und Zieltemperatur zum Verstellen."))
        .supportedFamilies([.systemSmall])
    }
}

struct RaumWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "raum", intent: RaumEinstellung.self, provider: WahlAnbieter<RaumEinstellung>()) { e in
            RaumAnsicht(e: e)
        }
        .configurationDisplayName(T("Raum"))
        .description(T("Temperatur, Lampen und Steckdosen eines Raums."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
struct RaumAnsicht: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        RaumKachel(daten: e.daten, raum: e.daten.raeume.first { $0.id == e.auswahl }, groesse: groesse(familie))
            .containerBackground(for: .widget) { Hintergrund() }
    }
}

struct EnergieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "energie", provider: FesterAnbieter()) { e in EnergieAnsicht(e: e) }
            .configurationDisplayName(T("Energie"))
            .description(T("Verbrauch gerade, Verlauf und Verbrauch heute (Strom, Wasser, Gas)."))
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
struct EnergieAnsicht: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        EnergieKachel(daten: e.daten, groesse: groesse(familie)).containerBackground(for: .widget) { Hintergrund(farbe: .yellow) }
    }
}

struct PersonenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "personen", provider: FesterAnbieter()) { e in PersonenAnsicht(e: e) }
            .configurationDisplayName(T("Personen"))
            .description(T("Wer ist zu Hause, wer ist wie weit weg."))
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
struct PersonenAnsicht: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        PersonenKachel(daten: e.daten, groesse: groesse(familie)).containerBackground(for: .widget) { Hintergrund(farbe: .green) }
    }
}

struct WertWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "entitaet", intent: WertEinstellung.self, provider: WahlAnbieter<WertEinstellung>()) { e in
            WertKachel(wert: e.daten.werte.first { $0.id == e.auswahl }).containerBackground(for: .widget) { Hintergrund() }
        }
        .configurationDisplayName(T("Entität"))
        .description(T("Eine beliebige Entität (Sensor, Schalter …) mit großem Wert."))
        .supportedFamilies([.systemSmall])
    }
}
