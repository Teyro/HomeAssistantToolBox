# Home Assistant ToolBox

**আপনার স্মার্ট হোম এক ক্লিকেই – KDE Plasma প্যানেলে, macOS মেনু বারে এবং আপনার iPhone-এ।**

[English](../README.md) · [Deutsch](../README.de.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md) · [Español](README.es.md) · [العربية](README.ar.md) · [Français](README.fr.md) · **বাংলা**

[Home Assistant](https://www.home-assistant.io/) থেকে আলো, সকেট, হিটিং, শক্তি ও মানুষ – নেটিভ
**KDE Plasma 6 উইজেট**, **macOS মেনু বার অ্যাপ** (macOS 26-এ Liquid Glass) এবং [Scriptable](https://scriptable.app)-এর মাধ্যমে
**iPhone/iPad উইজেট** হিসেবে। তিনটিই একই লজিক ও একই বৈশিষ্ট্য ভাগ করে।

![KDE](../plasma/bilder/en/tiles-dark.png)

## বৈশিষ্ট্য

- **আলো**: গ্রুপ ও ঘর (Home Assistant এলাকা), প্রতিটি আলোর জন্য সুইচ ও উজ্জ্বলতা, «সব বন্ধ»
- **সকেট**: পাওয়ার স্ট্রিপ ও সুইচ গ্রুপ এক সারিতে, সাধারণ সুইচ ও মোট ব্যবহারসহ
- **শক্তি**: বর্তমান ব্যবহার, ২৪ ঘণ্টার ইতিহাস, বিদ্যুৎ, পানি ও গ্যাসের **আজকের ব্যবহার**, সবচেয়ে বড় ব্যবহারকারী
- **হিটিং**: প্রতিটি ঘরের তাপমাত্রা ও আর্দ্রতা, লক্ষ্য তাপমাত্রা, মোড, প্রিসেট, **অতিরিক্ত হিটিং**,
  জানালা খোলা/বন্ধ এবং **২৪ ঘণ্টার চার্ট**
- **মানুষ**: জোনসহ মানচিত্র, কে কোথায় এবং বাড়ি থেকে কত দূরে
- **একাধিক Home Assistant ইনস্ট্যান্স**, **ডেস্কটপ উইজেট**, **লাইভ আপডেট** (WebSocket)
- সিস্টেমের ভাষা অনুযায়ী **৮টি ভাষা**

## ডাউনলোড ও ইনস্টলেশন

সব ফাইল [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest)-এ পাবেন:

- **KDE Plasma 6**: `homeassistant-toolbox.plasmoid` → `kpackagetool6 -t Plasma/Applet -i homeassistant-toolbox.plasmoid`,
  তারপর প্যানেলে রাইট-ক্লিক → উইজেট যোগ করুন → «Home Assistant ToolBox» ([নির্দেশিকা](../plasma/README.md))
- **macOS 14+**: `HomeAssistantToolBox-macOS-x.y.z.zip` খুলুন, Applications-এ টেনে আনুন এবং একবার চালান
  `xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"` ([নির্দেশিকা](../macos/README.md))
- **iPhone/iPad**: `HomeAssistantToolBox.js` Scriptable ফোল্ডারে সংরক্ষণ করুন ([নির্দেশিকা](../ios/README.md))

আপনার Home Assistant-এর ঠিকানা এবং একটি **দীর্ঘমেয়াদি অ্যাক্সেস টোকেন** লাগবে
(Home Assistant → আপনার প্রোফাইল → *নিরাপত্তা* → *দীর্ঘমেয়াদি অ্যাক্সেস টোকেন* → *টোকেন তৈরি করুন*)।

## গোপনীয়তা

অ্যাপগুলো কেবল **আপনার নিজের Home Assistant**-এর সাথে যোগাযোগ করে – কোনো ক্লাউড নেই, কোনো ট্র্যাকিং নেই। এছাড়া: GitHub
(আপডেট পরীক্ষা) এবং OpenStreetMap মানচিত্র। macOS ও iOS-এ টোকেন কীচেইনে রাখা হয়।

## অনুবাদ

অনুবাদ যন্ত্রের সাহায্যে তৈরি। `i18n/bn.json`-এ সংশোধন স্বাগত!

## লাইসেন্স ও ট্রেডমার্ক

GPL-3.0-or-later. Home Assistant ToolBox একটি স্বাধীন প্রকল্প এবং Home Assistant, Nabu Casa বা Open Home Foundation-এর সাথে
**কোনোভাবে যুক্ত নয়**। «Home Assistant» এর মালিকের ট্রেডমার্ক।
