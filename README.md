# Wicit

macOS için notch (çentik) rafı: notch'a gelince açılan widget paneli.

## Özellikler

- **Notch paneli** — notch'tan aşağı büyüyen, ters-radius köşeli raf (public `NSScreen` API'leriyle konumlanır)
- **Widget panosu** — Now-Playing (tüm kaynaklar: Music, Spotify, Chrome…), Dock'tan uygulama kısayolları, takvim, hava durumu (Open-Meteo, anahtarsız)
- **AirDrop + Pocket** — dosyayı notch'a sürükle: AirDrop'a gönder veya geçici rafa bırak, sonra dışarı sürükle
- **Pano geçmişi** — Son / Görseller / Renkler / Metin / Dosyalar / Favoriler; kaynak uygulama + zaman
- **Sayaç** — preset'li geri sayım, bitişte ses
- **Space'e özel tema** — her Space için ayrı panel teması (private SkyLight `GetActiveSpace`; sembol yoksa tek tema)
- **TR / EN** dil desteği (Ayarlar'dan anında geçiş)

## Derleme ve çalıştırma

```bash
./build.sh run       # debug derle + .app paketle + başlat
./build.sh release   # optimize derleme
```

Gereksinimler: macOS 14+, Xcode araçları. Paket ad-hoc imzalanır (App Store hedeflenmiyor;
MediaRemote ve Space kimliği private API gerektirir — dağıtım notarize + doğrudan indirme olmalı).

## Now-Playing kaynağı

`Vendor/MediaRemoteAdapter/` — [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
(BSD-3) kaynağından derlendi. Apple imzalı `/usr/bin/perl` üzerinden MediaRemote verisini
JSON olarak akıtır; izin penceresi gerektirmez. `build.sh` bunu `Contents/Resources/`e gömer.

## Mimari

```
Sources/Wicit/
├── App/        AppDelegate — LSUIElement agent, NSStatusItem, servis başlatma
├── Notch/      NotchMetrics/Layout/State/WindowController — pencere + geometri + sürükleme
├── Views/      SwiftUI: kök panel, raf, pano, sayaç, ayarlar, widget panosu
└── Services/   Clipboard, FileShelf, AirDrop, NowPlaying, Weather, AppShortcuts,
                SpaceMonitor, ThemeStore, Localization, CountdownTimer
```
