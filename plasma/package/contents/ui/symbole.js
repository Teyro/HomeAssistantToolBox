.pragma library
// Symbole im Breeze-Strichstil (22×22). Als Text hinterlegt und beim Anzeigen in der
// gewünschten Farbe erzeugt – so passen sie sich jedem Farbschema an (hell/dunkel).
// Die gleichen Symbole liegen auch als Dateien in ../icons.

var PFADE = {
    "ha-licht-aus": "<path d=\"M2.5 10.2 11 3l8.5 7.2\"/><path d=\"M4.5 8.8v10.7h13V8.8\"/><path d=\"M11 8.6a2.9 2.9 0 0 0-1.7 5.3v1.3h3.4v-1.3A2.9 2.9 0 0 0 11 8.6z\"/><path d=\"M9.6 17.2h2.8\"/>",
    "ha-licht-an": "<path d=\"M2.5 10.2 11 3l8.5 7.2\"/><path d=\"M4.5 8.8v10.7h13V8.8\"/><path d=\"M11 8.6a2.9 2.9 0 0 0-1.7 5.3v1.3h3.4v-1.3A2.9 2.9 0 0 0 11 8.6z\" fill=\"currentColor\"/><path d=\"M9.6 17.2h2.8\"/><path d=\"M7 11.3h-.8M15.8 11.3H15M8.2 8.4l-.6-.6M14.4 7.8l-.6.6\"/>",
    "lampe": "<path d=\"M11 3.5a5 5 0 0 0-3 9v2.2h6v-2.2a5 5 0 0 0-3-9z\"/><path d=\"M8.6 17.2h4.8M9.6 19.5h2.8\"/>",
    "lampe-an": "<path d=\"M11 3.5a5 5 0 0 0-3 9v2.2h6v-2.2a5 5 0 0 0-3-9z\" fill=\"currentColor\"/><path d=\"M8.6 17.2h4.8M9.6 19.5h2.8\"/>",
    "lampen-gruppe": "<path d=\"M7.5 5a3.6 3.6 0 0 0-2.2 6.5v1.6h4.4v-1.6A3.6 3.6 0 0 0 7.5 5z\"/><path d=\"M14.5 5a3.6 3.6 0 0 0-2.2 6.5v1.6h4.4v-1.6A3.6 3.6 0 0 0 14.5 5z\"/><path d=\"M5.8 15.4h3.4M12.8 15.4h3.4M3.5 18.5h15\"/>",
    "raum": "<path d=\"M2.5 10.2 11 3l8.5 7.2\"/><path d=\"M4.5 8.8v10.7h13V8.8\"/><path d=\"M9 19.5v-5.5h4v5.5\"/>",
    "steckdose": "<rect x=\"3\" y=\"3\" width=\"16\" height=\"16\" rx=\"4\"/><circle cx=\"11\" cy=\"11\" r=\"4.6\"/><circle cx=\"9.2\" cy=\"11\" r=\".5\" fill=\"currentColor\"/><circle cx=\"12.8\" cy=\"11\" r=\".5\" fill=\"currentColor\"/>",
    "steckdosenleiste": "<rect x=\"2.5\" y=\"7\" width=\"17\" height=\"8\" rx=\"2.5\"/><circle cx=\"6.6\" cy=\"11\" r=\"1.5\"/><circle cx=\"11\" cy=\"11\" r=\"1.5\"/><circle cx=\"15.4\" cy=\"11\" r=\"1.5\"/><path d=\"M19.5 11h1.2\"/>",
    "energie": "<path d=\"M12.5 2.8 5.5 12.3h5l-1 6.9 7-9.5h-5z\" stroke-linejoin=\"round\"/>",
    "wasser": "<path d=\"M11 3.2c-2.6 3.6-5.2 6.6-5.2 9.9a5.2 5.2 0 0 0 10.4 0c0-3.3-2.6-6.3-5.2-9.9z\"/><path d=\"M8.6 13.6a2.5 2.5 0 0 0 2.2 2.4\"/>",
    "gas": "<path d=\"M11 2.8c.4 3-3.2 4.4-4.6 7.9a5.3 5.3 0 0 0 4.6 8.5 5.3 5.3 0 0 0 4.9-7c-.5 1.3-1.4 2-2.3 2.1.9-3.7-.4-8.6-2.6-11.5z\"/><path d=\"M11 19.2a2.2 2.2 0 0 1-2.1-2.9c.4-1.2 1.6-1.8 2-3.1.9 1 2.3 2.4 2.1 3.8a2.1 2.1 0 0 1-2 2.2z\"/>",
    "thermometer": "<path d=\"M9 4.6a2 2 0 0 1 4 0v8.1a4 4 0 1 1-4 0z\"/><path d=\"M11 9.2v6\"/><circle cx=\"11\" cy=\"16\" r=\"1.5\" fill=\"currentColor\"/><path d=\"M15.5 6h2M15.5 9h2\"/>",
    "heizung": "<rect x=\"3\" y=\"6\" width=\"16\" height=\"11\" rx=\"2\"/><path d=\"M7 6v11M11 6v11M15 6v11\"/><path d=\"M5 19.5h1.5M15.5 19.5H17\"/>",
    "person": "<circle cx=\"11\" cy=\"7.5\" r=\"3.5\"/><path d=\"M4.5 19c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5\"/>",
    "karte": "<path d=\"M3 6.5 8 4.5l6 2 5-2v11l-5 2-6-2-5 2z\"/><path d=\"M8 4.5v11M14 6.5v11\"/>",
    "fenster": "<rect x=\"5\" y=\"3\" width=\"12\" height=\"16\" rx=\"1.5\"/><path d=\"M11 3v16M5 11h12\"/>",
    "fenster-offen": "<rect x=\"5\" y=\"3\" width=\"12\" height=\"16\" rx=\"1.5\"/><path d=\"M5 3 12 5.5v15L5 19z\" fill=\"currentColor\" fill-opacity=\".25\"/><path d=\"M9.6 12.6h.8\"/>"
};

function farbeText(c) {
    // QML-Farbe oder "#rrggbb" -> rgb()/Deckkraft für SVG
    if (typeof c === "string") return { rgb: c, a: 1 };
    return { rgb: "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")", a: c.a };
}

function uri(name, farbe) {
    var inhalt = PFADE[name];
    if (!inhalt) return "";
    var f = farbeText(farbe);
    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22">'
        + '<g fill="none" stroke="' + f.rgb + '" stroke-opacity="' + f.a + '" color="' + f.rgb + '" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
        + inhalt.replace(/currentColor/g, f.rgb)
        + '</g></svg>';
    return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}
