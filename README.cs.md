# EasyLauncher

[English](README.md) | **Čeština**

Lehký launcher pro Android, určený primárně pro telefony s černobílým e-ink displejem. Černý text na bílém pozadí, velké dlaždice bez ikon a přechody bez animací.

## Stav projektu

Verze **0.1.1 je první veřejné sestavení**. Aplikace je fyzicky testovaná na telefonu **Bigme HiBreak Pro BW s Androidem 14**, včetně zobrazení při systémové velikosti písma 180 %.

Teď začíná každodenní používání. Podle zkušeností z provozu budou přicházet opravy chyb a úpravy ovládání; další funkce mohou přibývat později podle skutečných potřeb. EasyLauncher vždy zůstane lehký a jednoduchý.

## Ovládání

- Klepnutí na hodiny otevře budík, na datum vybraný kalendář.
- Oblíbené aplikace mají dva sloupce. Dlouhé podržení otevře přejmenování, odebrání a úpravu pořadí. Při přejmenování vloží Enter nový řádek; název uložíš tlačítkem Uložit.
- Tažení nahoru otevře abecední seznam ostatních aplikací s hledáním bez ohledu na diakritiku. Tažením dolů na začátku seznamu nebo přes jeho záhlaví se vrátíš na oblíbené a zavřeš klávesnici. Dlouhým podržením aplikaci přidáš mezi oblíbené.
- Tažení zprava doleva otevře fotoaparát, zleva doprava kontakty a dolů na ploše oznámení. Gesta fungují také přes dlaždice; při větším počtu oblíbených nebo delších víceřádkových názvech lze mřížkou posouvat.
- Nastavení umožňuje změnit cílové aplikace, počet sloupců, velikost názvů a automatické otevření klávesnice. Systémové tlačítko Domů vrací na plochu a zavírá hledání i klávesnici.
- V nastavení lze zapnout tmavý režim s černým pozadím a ikony aplikací na ploše i v seznamu.

V nastavení lze EasyLauncher vybrat jako výchozí domovskou aplikaci. Pro gesto oznámení povol jeho službu ve zpřístupnění Androidu. Služba pouze otevírá systémovou lištu; nečte její obsah ani obsah ostatních oken.

## TV launcher pro Linux

Linuxová verze se otevře na celé obrazovce s hodinami a mřížkou oblíbených aplikací. Dlaždici vybereš šipkami na klávesnici nebo ovladači a spustíš Enterem. Funguje i kliknutí myší.

```sh
flutter build linux --release
```

Vytvoř soubor `easylauncher/apps.json` ve složce `$XDG_CONFIG_HOME` (obvykle `~/.config`). Pořadí v poli `favorites` určuje pořadí dlaždic. Po úpravě souboru EasyLauncher spusť znovu.

Volitelné pole `icon` zobrazí obrázek PNG, JPEG nebo WebP z absolutní cesty.

```json
{
  "schemaVersion": 1,
  "favorites": [
    {"label": "Kodi", "command": "kodi", "icon": "/home/you/.config/easylauncher/kodi.png"},
    {"label": "ScummVM", "command": "scummvm"}
  ]
}
```

Pro spuštění s labwc vlož do `~/.config/labwc/autostart` následující řádek s absolutní cestou ke svému sestavení. Celou složku `bundle` ponech pohromadě.

```sh
GDK_BACKEND=x11 /cesta/k/easylauncher/build/linux/x64/release/bundle/easylauncher &
```

Na Waylandu vlákno vykreslování Flutteru 3.50 neustále volá `wl_display.sync` (asi 4 000 synchronizací za sekundu a o 2,8 W vyšší spotřeba NASu). Při spuštění přes Xwayland je vlákno v klidu. Potřebuje to labwc s nainstalovaným Xwaylandem a proměnnou zdědí i spouštěné aplikace. Jde o chybu Flutteru [#196529](https://github.com/flutter/flutter/issues/196529); až ji některé vydání opraví, proměnnou vynech.

## Sestavení

Sestavení používá Flutter 3.50.1 s Dartem 3.14.0, Android SDK a JDK podporovaný přibaleným Gradlem. Minimální podporovaná verze je Android 7.0 (API 24).

```sh
flutter pub get
flutter analyze
flutter test
python3 tool/build_apk.py
```

APK pro ARM64 je v `build/app/outputs/flutter-apk/app-release.apk`. Lokální sestavení používá vývojový podpis; pro vydání nastav vlastní podpis v Android projektu.

Volitelný osobní profil se vloží jen do prvního spuštění. Pozdější aktualizace zachovávají nastavení uložené v telefonu.

```sh
python3 tool/build_apk.py --profile private/launcher-profile.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Profil je JSON se `schemaVersion: 1`, polem `favorites` a volitelnými `layout`, `actions`, `labels` a `autoKeyboard`. Každá aplikace má `packageName`, plný `activityName` a `label`. Akce mají typ `launchApp`; podporované klíče jsou `clockTap`, `dateTap`, `swipeRight` a `swipeLeft`. Prázdný profil začíná bez oblíbených aplikací.

Osobní profily patří do ignorované složky `private/`. Při osobním sestavení budou součástí APK; veřejnou verzi sestav bez parametru `--profile`.

## Test na zařízení

```sh
flutter test integration_test/app_test.dart -d DEVICE_ID
```

Integrační test ověřuje nativní seznam aplikací, uložené nastavení, bezpečné odmítnutí neexistující aplikace a hledání. Test používá samostatné vývojové sestavení s identifikátorem `one.jiri.easylauncher.debug`; nastavení běžně nainstalované aplikace zůstává oddělené. Zobrazení a kvalitu obnovování e-inku je potřeba posoudit na fyzickém displeji.

Vydané APK nevyžaduje přístup k internetu, kontaktům, událostem kalendáře ani k fotoaparátu. Otevírá příslušné aplikace systémovými rozhraními Androidu.
