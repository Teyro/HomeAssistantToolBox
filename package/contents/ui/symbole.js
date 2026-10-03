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
    "energie": "<path d=\"M12.5 2.8 5.5 12.3h5l-1 6.9 7-9.5h-5z\" stroke-linejoin=\"round\"/>"
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
