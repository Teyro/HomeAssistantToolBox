import Foundation
import HALogik

/// Live-Aktualisierung über die WebSocket-API von Home Assistant (state_changed) und
/// beliebige WebSocket-Anfragen (Energie-Dashboard, Langzeitstatistik).
@MainActor
final class LiveVerbindung {
    var zustandGeaendert: (String, Entitaet?) -> Void = { _, _ in }
    var registerGeladen: ([String: RegisterEintrag]) -> Void = { _ in }
    var verbundenGeaendert: (Bool) -> Void = { _ in }
    var tokenAbgelehnt: () -> Void = {}

    private(set) var verbunden = false {
        didSet { if verbunden != oldValue { verbundenGeaendert(verbunden) } }
    }
    private var task: URLSessionWebSocketTask?
    private var generation = 0
    private var naechsteId = 1
    private var registerAnfrage = -1
    private var offene: [Int: CheckedContinuation<JSON?, Never>] = [:]
    private var basis = ""
    private var token = ""
    // Token abgelehnt: nicht immer wieder probieren (Home Assistant sperrt sonst die IP)
    private var abgelehnt = false
    private var wiederholen: Task<Void, Never>?
    private let sitzung = URLSession(configuration: .default)

    func start(basis: String, token: String) {
        stop()
        self.basis = basis
        self.token = token
        abgelehnt = false
        verbinden()
    }

    func stop() {
        generation += 1
        wiederholen?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        verbunden = false
        alleOffenenBeenden()
    }

    /// Nach dem Aufwachen aus dem Ruhezustand: Verbindung ist meist tot – neu aufbauen.
    func neuVerbinden() {
        guard !basis.isEmpty, !abgelehnt else { return }
        start(basis: basis, token: token)
    }

    private func verbinden() {
        guard !basis.isEmpty, !token.isEmpty, !abgelehnt else { return }
        let ws = basis.replacingOccurrences(of: "^http", with: "ws", options: .regularExpression) + "/api/websocket"
        guard let url = URL(string: ws) else { return }
        let t = sitzung.webSocketTask(with: url)
        t.maximumMessageSize = 64 * 1024 * 1024
        task = t
        let gen = generation
        t.resume()
        Task { await empfangen(t, gen) }
        Task { await anklopfen(t, gen) }
    }

    /// Alle 30 s ein Ping: hält die Verbindung offen und merkt tote Verbindungen
    /// (WLAN weg, Ruhezustand), die sonst stumm hängen bleiben.
    private func anklopfen(_ t: URLSessionWebSocketTask, _ gen: Int) async {
        while gen == generation {
            try? await Task.sleep(for: .seconds(30))
            guard gen == generation, verbunden else { continue }
            let ok = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                t.sendPing { fehler in c.resume(returning: fehler == nil) }
            }
            if !ok && gen == generation {
                t.cancel(with: .goingAway, reason: nil)
                return
            }
        }
    }

    private func empfangen(_ t: URLSessionWebSocketTask, _ gen: Int) async {
        while gen == generation {
            do {
                let nachricht = try await t.receive()
                guard gen == generation else { return }
                switch nachricht {
                case .string(let s): verarbeiten(s)
                case .data(let d): verarbeiten(String(decoding: d, as: UTF8.self))
                @unknown default: break
                }
            } catch {
                guard gen == generation else { return }
                geschlossen()
                return
            }
        }
    }

    private func geschlossen() {
        verbunden = false
        task = nil
        alleOffenenBeenden()
        guard !abgelehnt else { return }
        // Nach Verbindungsabbruch (Standby, WLAN weg) nach 10 s neu verbinden
        let gen = generation
        wiederholen?.cancel()
        wiederholen = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, gen == self.generation else { return }
            self.verbinden()
        }
    }

    private func alleOffenenBeenden() {
        let alle = offene
        offene = [:]
        for (_, c) in alle { c.resume(returning: nil) }
    }

    private func senden(_ o: JSON) {
        guard let task else { return }
        task.send(.string(o.zeichenkette)) { _ in }
    }

    private func sendeMitId(_ o: [String: JSON]) -> Int {
        let id = naechsteId
        naechsteId += 1
        var n = o
        n["id"] = .zahl(Double(id))
        senden(.objekt(n))
        return id
    }

    /// Beliebige WebSocket-Anfrage; liefert das Ergebnis oder nil (Fehler/keine Verbindung).
    func anfrage(_ nachricht: [String: JSON]) async -> JSON? {
        guard verbunden else { return nil }
        return await withCheckedContinuation { c in
            let id = naechsteId
            offene[id] = c
            _ = sendeMitId(nachricht)
        }
    }

    private func verarbeiten(_ text: String) {
        guard let m = JSON.lesen(text) else { return }
        switch m["type"]?.text {
        case "auth_required":
            senden(["type": "auth", "access_token": .text(token)])
        case "auth_ok":
            _ = sendeMitId(["type": "subscribe_events", "event_type": "state_changed"])
            registerAnfrage = sendeMitId(["type": "config/entity_registry/list_for_display"])
            verbunden = true
        case "auth_invalid":
            abgelehnt = true
            verbunden = false
            task?.cancel(with: .normalClosure, reason: nil)
            tokenAbgelehnt()
        case "result":
            let id = Int(m["id"]?.zahl ?? -1)
            if let c = offene.removeValue(forKey: id) {
                c.resume(returning: m["success"]?.bool == true ? (m["result"] ?? .null) : nil)
            } else if id == registerAnfrage, m["success"]?.bool == true, let liste = m["result"]?["entities"]?.liste {
                var eintraege: [String: RegisterEintrag] = [:]
                for e in liste {
                    guard let ei = e["ei"]?.text else { continue }
                    let ec = e["ec"] != nil && e["ec"]?.istNull == false
                    let hb = e["hb"]?.bool == true
                    if ec || hb { eintraege[ei] = RegisterEintrag(ec: ec, hb: hb) }
                }
                registerGeladen(eintraege)
            }
        case "event":
            if let daten = m["event"]?["data"], let id = daten["entity_id"]?.text {
                zustandGeaendert(id, Entitaet(json: daten["new_state"]))
            }
        default:
            break
        }
    }
}
