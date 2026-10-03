/*
 * Live-Aktualisierung über die WebSocket-API von Home Assistant (state_changed).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtWebSockets

Item {
    id: live

    property string adresse: ""
    property string token: ""
    property bool verbunden: false
    property int naechsteId: 1
    // Token abgelehnt: nicht immer wieder probieren (Home Assistant sperrt sonst die IP)
    property bool abgelehnt: false
    property bool pause: false
    onTokenChanged: abgelehnt = false
    onAdresseChanged: abgelehnt = false

    signal zustandGeaendert(string entityId, var neu)
    signal wiederVerbunden()

    function wsAdresse() {
        if (!adresse) return "";
        return adresse.replace(/^http/, "ws") + "/api/websocket";
    }

    function senden(o) {
        if (!o.type || o.type !== "auth") o.id = naechsteId++;
        socket.sendTextMessage(JSON.stringify(o));
    }

    WebSocket {
        id: socket
        url: live.wsAdresse()
        active: live.adresse !== "" && live.token !== "" && !live.abgelehnt && !live.pause
        onTextMessageReceived: function (text) {
            let m;
            try { m = JSON.parse(text); } catch (e) { return; }
            if (m.type === "auth_required") {
                live.senden({ type: "auth", access_token: live.token });
            } else if (m.type === "auth_ok") {
                live.senden({ type: "subscribe_events", event_type: "state_changed" });
                live.verbunden = true;
                live.wiederVerbunden();
            } else if (m.type === "auth_invalid") {
                live.verbunden = false;
                live.abgelehnt = true;
            } else if (m.type === "event" && m.event && m.event.data) {
                live.zustandGeaendert(m.event.data.entity_id, m.event.data.new_state);
            }
        }
        onStatusChanged: function (zustand) {
            if (zustand === WebSocket.Closed || zustand === WebSocket.Error) {
                live.verbunden = false;
                if (live.adresse !== "" && live.token !== "" && !live.abgelehnt) wiederholen.restart();
            }
        }
    }

    // Nach Verbindungsabbruch (Standby, WLAN weg) neu verbinden
    Timer {
        id: wiederholen
        interval: 10000
        onTriggered: {
            if (live.abgelehnt) return;
            // kurz aus- und wieder einschalten = neu verbinden
            live.pause = true;
            Qt.callLater(() => live.pause = false);
        }
    }
}
