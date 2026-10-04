import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Instanzen & Anzeige")
        icon: "network-connect"
        source: "configAllgemein.qml"
    }
    ConfigCategory {
        name: i18n("Schreibtisch")
        icon: "preferences-desktop-plasma"
        source: "configSchreibtisch.qml"
    }
}
