# Datenschutzerklärung

**Zuletzt aktualisiert:** April 2026

BirdNET Live respektiert Ihre Privatsphäre. Dieses Dokument erklärt, wie die App mit Ihren Daten umgeht.

## Lokale Verarbeitung auf dem Gerät

Die gesamte Audioanalyse und Vogelartenbestimmung findet **vollständig auf Ihrem Gerät** statt. Die App verwendet zwei neuronale Netzwerkmodelle, die lokal ausgeführt werden:

- **BirdNET+ Audio-Klassifikator** — analysiert das Mikrofon-Audio, um Vogelarten zu identifizieren.
- **BirdNET Geo-Modell** — sagt vorher, welche Arten an Ihrem Standort und zu dieser Jahreszeit wahrscheinlich sind.

Es werden niemals Audiodaten an externe Server übertragen.

## Datenerfassung

BirdNET Live sammelt, überträgt oder teilt **keine** personenbezogenen Daten. Es gibt keine Analysen, kein Tracking und keine Telemetrie.

### Lokal auf Ihrem Gerät gespeicherte Daten:

| Datentyp | Zweck | Speicherort |
|-----------|---------|---------|
| Audioaufnahmen | Vogelbestimmung, Wiedergabe, Export | Lokale Dateien |
| Erkennungsergebnisse | Arten, Konfidenz, Zeitstempel | SQLite-Datenbank |
| GPS-Koordinaten | Geotagging von Erkennungen, Survey-Tracks, Geo-Modell-Vorhersagen | SQLite-Datenbank |
| Sitzungs-Metadaten | Sitzungsverlauf, Überprüfung, Export | SQLite-Datenbank |
| App-Einstellungen | Benutzereinstellungen | SharedPreferences |

### Gebündelte Offline-Daten

Artenbilder, Beschreibungen und Taxonomie-Daten sind **in die App integriert** und werden aus lokalen Assets geladen. Es werden keine Netzwerkanfragen für Arteninformationen gestellt.

## Externe Ressourcen

Die App kann auf die folgenden externen Ressourcen zugreifen:

| Ressource | Zweck | Wann |
|----------|---------|------|
| Kartenkacheln (OpenTopoMap) | Visualisierung von GPS-Tracks in Surveys | Beim Öffnen einer Kartenansicht (Zustimmung erforderlich) |
| Reverse Geocoding (OpenStreetMap Nominatim) | Auflösung von GPS-Koordinaten in einen lesbaren Ortsnamen (z. B. "Berlin, Deutschland") für die Sitzungsansicht | Einmal pro Sitzung, wenn eine Sitzung mit GPS-Koordinaten überprüft wird, das Gerät online ist **und der Benutzer dem Netzwerkzugriff auf OpenStreetMap zugestimmt hat** |

Anfragen für Kartenkacheln sind standardmäßige HTTPS-GET-Anfragen an 	ile.opentopomap.org. Es werden nur Kachelkoordinaten gesendet — keine persönlich identifizierbaren Informationen.

Reverse-Geocoding-Anfragen senden den Breiten- und Längengrad der Sitzung über HTTPS an 
ominatim.openstreetmap.org, zusammen mit einem generischen BirdNETLive/<version> User-Agent-String, wie von den [Nominatim-Nutzungsbedingungen](https://operations.osmfoundation.org/policies/nominatim/) gefordert. Der ermittelte Ortsname wird lokal mit der Sitzung gespeichert, sodass eine Sitzung nur einmal geocodiert wird. Reverse Geocoding ist an dieselbe einmalige Zustimmungsabfrage wie die Kartenkacheln gebunden: Solange Sie dem Netzwerkzugriff für OpenStreetMap nicht zustimmen (wird beim ersten Öffnen einer Kartenansicht angezeigt), werden keine Reverse-Geocoding-Anfragen gestellt. Wenn die Sitzung keine GPS-Koordinaten enthält oder das Gerät offline ist, erfolgt keine Anfrage. Der Entzug der Standortberechtigung auf Betriebssystemebene verhindert, dass neue Sitzungen Koordinaten erfassen und somit geocodiert werden.

**Es werden keine weiteren Netzwerkanfragen gestellt.** Die App funktioniert vollständig offline.

## GPS & Standort

Die App verwendet den GPS-Standort für:

- **Artenfilterung** — Vorhersage, welche Arten an Ihrem Standort wahrscheinlich sind.
- **Survey-Modus** — Aufzeichnung von GPS-Tracks und Geotagging von Erkennungen entlang eines Transekts.
- **Point-Count-Modus** — Markierung des Beobachtungsorts.

GPS-Daten werden lokal gespeichert und nur dann in Exporte einbezogen, wenn Sie eine Sitzung ausdrücklich teilen oder exportieren. Der Standortzugriff erfordert Ihre Erlaubnis und kann jederzeit über die Systemeinstellungen widerrufen werden.

## Datenexport

Sie können Sitzungsdaten in verschiedenen Formaten exportieren (Raven-Auswahltabellen, CSV, JSON, GPX). Exporte werden lokal generiert und über das Teilen-Menü des Systems geteilt. Die App lädt keine Exportdaten auf Server hoch.

## Datenlöschung

Alle App-Daten (Sitzungen, Aufnahmen, Einstellungen) können über **Einstellungen > Gefahrenzone > Alle Daten löschen** gelöscht werden. Die Deinstallation der App entfernt alle gespeicherten Daten.

## Kontakt

Für Fragen zum Datenschutz: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
