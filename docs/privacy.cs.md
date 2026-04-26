# Zásady ochrany osobních údajů

**Poslední aktualizace:** Duben 2026

BirdNET Live respektuje vaše soukromí. Tento dokument vysvětluje, jak aplikace nakládá s vašimi údaji.

## Zpracování na zařízení

Veškerá analýza zvuku a identifikace ptačích druhů probíhá **zcela ve vašem zařízení**. Aplikace využívá dva modely neuronových sítí spouštěné lokálně:

- **Zvukový klasifikátor BirdNET+** — analyzuje zvuk z mikrofonu a identifikuje ptačí druhy.
- **Geomodel BirdNET** — předpovídá, jaké druhy se s největší pravděpodobností vyskytují ve vaší lokalitě a v daném ročním období.

Žádná zvuková data nejsou nikdy přenášena na externí servery.

## Shromažďování dat

BirdNET Live **neshromažďuje, nepřenáší ani nesdílí** žádné osobní údaje. Neobsahuje analytiku, sledování ani telemetrii.

### Data uložená lokálně ve vašem zařízení:

| Typ dat | Účel | Úložiště |
|-----------|---------|---------|
| Zvukové nahrávky | Identifikace ptáků, přehrávání, export | Lokální soubory |
| Výsledky detekce | Druhy, spolehlivost, časové značky | Databáze SQLite |
| GPS souřadnice | Geotagging detekcí, trasy průzkumu, geomodel | Databáze SQLite |
| Metadata relace | Historie, kontrola, export | Databáze SQLite |
| Nastavení | Uživatelské předvolby | SharedPreferences |

### Přibalená offline data

Obrázky druhů, popisy a taxonomická data jsou **přibalena v aplikaci** a načítají se z lokálních souborů. Pro informace o druzích nejsou prováděny žádné síťové požadavky.

## Externí zdroje

Aplikace může přistupovat k následujícím externím zdrojům:

| Zdroj | Účel | Kdy |
|----------|---------|------|
| Mapové dlaždice (OpenTopoMap) | Vizualizace GPS tras v průzkumech | Při otevření mapy (vyžadován souhlas uživatele) |
| Reverzní geokódování (OSM Nominatim) | Překlad GPS na názvy míst (např. "Berlín, Německo") | Jednou za relaci, když je online a uživatel udělil souhlas |

Mapové požadavky a reverzní geokódování zahrnují pouze parametry jako souřadnice a probíhají přes HTTPS podle podmínek OpenStreetMap (Nominatim). **Žádné další síťové požadavky se neprovádějí.**

## GPS a Poloha
Poloha se používá pro filtrování druhů, průzkumy a bodové sčítání. Vše je lokální a lze to zakázat v nastavení systému.

## Export a Smazání dat
Nahrávky lze exportovat (CSV, JSON, RAVEN atd.). Všechna data lze kdykoli zcela vymazat z Nastavení aplikace.

## Kontakt
Otázky ohledně soukromí: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
