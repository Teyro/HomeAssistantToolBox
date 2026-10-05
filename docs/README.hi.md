# Home Assistant ToolBox

**आपका स्मार्ट होम बस एक क्लिक दूर – KDE Plasma पैनल में, macOS मेन्यू बार में और आपके iPhone पर।**

[English](../README.md) · [Deutsch](../README.de.md) · [中文](README.zh.md) · **हिन्दी** · [Español](README.es.md) · [العربية](README.ar.md) · [Français](README.fr.md) · [বাংলা](README.bn.md)

[Home Assistant](https://www.home-assistant.io/) से लाइटें, सॉकेट, हीटिंग, ऊर्जा और लोग – नेटिव
**KDE Plasma 6 विजेट**, **macOS मेन्यू बार ऐप** (macOS 26 पर Liquid Glass) और [Scriptable](https://scriptable.app) के ज़रिए
**iPhone/iPad विजेट** के रूप में। तीनों एक ही लॉजिक और एक जैसी सुविधाएँ साझा करते हैं।

![KDE](../plasma/bilder/en/tiles-dark.png)

## सुविधाएँ

- **लाइटें**: समूह और कमरे (Home Assistant क्षेत्र), हर लाइट के लिए स्विच और ब्राइटनेस, «सब बंद»
- **सॉकेट**: पावर स्ट्रिप और स्विच समूह एक पंक्ति में, साझा स्विच और कुल खपत के साथ
- **ऊर्जा**: वर्तमान खपत, 24 घंटे का इतिहास, बिजली, पानी और गैस की **आज की खपत**, सबसे बड़े उपभोक्ता
- **हीटिंग**: हर कमरे का तापमान और नमी, लक्ष्य तापमान, मोड, प्रीसेट, **अतिरिक्त हीटिंग**,
  खिड़की खुली/बंद और **24 घंटे का चार्ट**
- **लोग**: ज़ोन वाला नक्शा, कौन कहाँ है और घर से कितनी दूर
- **कई Home Assistant इंस्टेंस**, **डेस्कटॉप विजेट**, **लाइव अपडेट** (WebSocket)
- सिस्टम भाषा के अनुसार **8 भाषाएँ**

## डाउनलोड और इंस्टॉलेशन

सभी फ़ाइलें [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest) पर हैं:

- **KDE Plasma 6**: `homeassistant-toolbox.plasmoid` → `kpackagetool6 -t Plasma/Applet -i homeassistant-toolbox.plasmoid`,
  फिर पैनल पर राइट-क्लिक → विजेट जोड़ें → «Home Assistant ToolBox» ([गाइड](../plasma/README.md))
- **macOS 14+**: `HomeAssistantToolBox-macOS-x.y.z.zip` खोलें, Applications में खींचें और एक बार चलाएँ
  `xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"` ([गाइड](../macos/README.md))
- **iPhone/iPad**: `HomeAssistantToolBox.js` को Scriptable फ़ोल्डर में सहेजें ([गाइड](../ios/README.md))

आपको अपने Home Assistant का पता और एक **लंबे समय तक चलने वाला एक्सेस टोकन** चाहिए
(Home Assistant → आपकी प्रोफ़ाइल → *सुरक्षा* → *लंबे समय तक चलने वाले एक्सेस टोकन* → *टोकन बनाएँ*)।

## गोपनीयता

ऐप्स केवल **आपके अपने Home Assistant** से बात करते हैं – कोई क्लाउड नहीं, कोई ट्रैकिंग नहीं। इसके अलावा: GitHub
(अपडेट जाँच) और OpenStreetMap नक्शे। macOS और iOS पर टोकन कीचेन में रखा जाता है।

## अनुवाद

अनुवाद मशीन की मदद से बनाए गए हैं। `i18n/hi.json` में सुधार का स्वागत है!

## लाइसेंस और ट्रेडमार्क

GPL-3.0-or-later. Home Assistant ToolBox एक स्वतंत्र प्रोजेक्ट है और Home Assistant, Nabu Casa या Open Home Foundation से
**संबद्ध नहीं** है। «Home Assistant» अपने स्वामी का ट्रेडमार्क है।
