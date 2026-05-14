# Recenze relace

Session Review je místo, kde BirdNET Live promění detekce na upravitelný záznam.

## Jak toho dosáhnete

BirdNET Live otevře Session Review automaticky po dokončení:

- Živá relace
- počet bodů
- Průzkum
- Spuštění analýzy souborů

Můžete také znovu otevřít jakoukoli uloženou relaci z [Knihovna relací] (session-library.md).

## Hlavní oblasti

### Shrnutí a přehrávání

Session Review kombinuje přehrávání, navigaci spektrogramem a seznam druhů. U průzkumných relací může také zobrazit mapovaný kontext.

Hlavička souhrnu nahoře nese datum, štítek polohy (lat/lon plus volitelně vyřešený název místa, když je **Nastavení → Soukromí → Povolit vyhledávání názvu místa** zapnuto) a — pokud bylo při záznamu zapnuto **Nastavení → Soukromí → Povolit vyhledávání počasí** — **řádek počasí** pod polohou s podmínkami zachycenými ke konci relace: jednoradák typu *„20,1 °C · Slabý déšť · 3,2 m/s SZ“* s ikonou počasí na začátku. Klepnutím na řádek se rozbalí malý panel s teplotou, větrem, srážkami a oblačností včetně atribuce Open-Meteo. Týž snapshot se objevuje v JSON exportu, bloku metadat a HTML reportu.

### Seznam druhů

Druhy jsou seskupeny do rozbalitelných řad. Detekce můžete prohlížet podle druhů a procházet záznamem při jejich prohlížení.

### Mapa trasy průzkumu

Průzkumné relace zobrazují malou inline mapu trasy GPS a detekční značky. Klepnutím na značku v inline mapě zaměříte detekci – mapa se na ni vycentruje. Klepnutím na tlačítko :material-fullscreen: **rozbalit** (vpravo nahoře v inline mapě) otevřete **mapu na celou obrazovku**; pokud byla detekce zaměřena, otevře se mapa vycentrovaná a přiblížená přímo na ni, takže neztratíte své místo.

#### Kódování značek

- **Spolehlivost je barevně kódována** s paletou bezpečnou pro barvoslepost (CVD): nízká až vysoká spolehlivost přechází z fialovo-modré přes tyrkysovou/žlutou až k červené. Jas palety se mění monotónně, aby zůstala čitelná i v jednobarevném zobrazení a pro uživatele s poruchou rozlišování červené a zelené.
- **Detekce se zvukem** mají kolem fotografie druhu barevný kruh a v rohu odznak přehrávání – klepnutím na ně přehrajete nahraný klip v listu.
- **Tiché detekce** (bez klipu na disku) se vykreslují menší, vybledlé a s neutrálně šedým kruhem, takže detekce se zvukem vždy vyniknou jako primární obsah.
- **Překrývající se značky na stejném místě** jsou vrstveny podle důležitosti: zvýrazněná > se zvukem > vyšší spolehlivost, takže tichá značka s nízkou spolehlivostí nikdy nemůže zakrýt silnou zvukovou detekci.
- **Pod úrovní zoomu 14,5** se siluety degradují na barevné body s velikostí podle spolehlivosti a husté shluky se sbalují do bubliny s počtem (clustering se vypíná na zoomu 15).

#### Filtrování

Mapa na celou obrazovku má trvalý **filtrovací čip** ukotvený vpravo nahoře. Klepnutím na něj otevřete filtrovací list; popisek čipu vždy ukazuje, co je aktuálně aktivní (*„Všechny druhy“*, *„Se zvukem“*, *„≥ 80 %“* nebo název jednoho druhu). Dostupné filtry:

- **Všechny detekce** (výchozí).
- **Se zvukovým klipem** – pouze detekce, jejichž klip je stále na disku a lze jej přehrát.
- **Ruční přidání** – pouze detekce, které jste přidali v relace Review (kromě automaticky zjištěných).

Detekce můžete také omezit podle úrovně spolehlivosti. Posuvník nastavuje minimální spolehlivost (začíná na 10 %).

Pod posuvníkem spolehlivosti je výběr **Limit to species**, který vám umožní sbalit mapu na jeden druh – užitečné při otázce „kde přesně na trase jsem slyšel drozda lesního?“. Položka *Všechny druhy* ruší omezení druhu. Filtry se kombinují: např. *Se zvukovým klipem* + *Wood Thrush* + *> 80 %* zobrazuje pouze hratelné značky drozda lesního, které dosáhly více než 80 %.

Když je filtr aktivní, název lišty aplikace získá titulek s počtem shod (např. *„7 detekcí“*). *Reset* v listu se vrátí na výchozí.

## Ikony lišty nástrojů

Panel nástrojů používá stejný význam ikon, jaký je popsán v [Ikony a ovládací prvky] (icons-and-controls.md):

- :material-plus-circle-outline: — přidat obsah
- :material-undo-variant: / :material-redo-variant: — procházet úpravami
- :material-content-cut: — režim trimování
- :material-content-save: — uložit úpravy
- :material-share-variant: — export nebo podíl
- :material-delete-outline: — vyřazení relace
- :material-play: — pokračovat v průzkumu, když je tato akce k dispozici
- :material-help-circle-outline: — otevřete list nápovědy Session Review
- :material-tune: — otevřete Nastavení

## Typické kontrolní úkoly

- kontrola detekcí proti přehrávání a kontextu spektrogramu
- přidat druh nebo anotaci
- ořízněte záznam na užitečný interval
- exportovat zkontrolovanou sadu výsledků

## Export

Chování exportu závisí na možnostech vybraných v [Settings] (settings.md). Aplikace může zabalit detekce a volitelně i zvuk do zvoleného formátu exportu. Každý export se nyní dodává s úplnými metadaty provenience – verzí aplikace, názvem a verzí modelu, národním prostředím, časovým razítkem exportu a snímkem všech nastavení v době exportu – zapsanými do postranního souboru „<prefix>.metadata.json“ (ZIP) nebo do bloku „meta“ nejvyšší úrovně (JSON), takže exporty jsou samy popisovatelné a reprodukovatelné.