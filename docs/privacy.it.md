# Informativa sulla Privacy

**Ultimo aggiornamento:** Maggio 2026

BirdNET Live rispetta la tua privacy. Nessun dato audio o identificazione animale viene trasmesso online; tutta l'attività neurale (**BirdNET+ Audio e Geo-model**) avviene **localmente** sul tuo dispositivo.

## Raccolta Dati
La nostra applicazione non include telemetria, tracker o database in cloud.
- Audio, database SQLite (risultati, GPS, log), e preferenze vengono salvati nella memoria del dispositivo.
- Quando **Consenti ricerca meteo** è attivo, ogni sessione salva localmente uno snapshot di temperatura, precipitazioni, vento, nuvolosità e codice meteo alle coordinate della sessione.

## Servizi di Terze Parti

L'app può contattare i seguenti servizi esterni. Ciascuno è controllato da un interruttore indipendente in **Impostazioni → Privacy**, e **tutti e tre sono disattivati per impostazione predefinita** su una nuova installazione. Nulla esce dal dispositivo finché non lo autorizzi.

| Risorsa | Scopo | Interruttore | Inviato per ogni richiesta |
|---------|-------|--------------|----------------------------|
| Tile della mappa (OpenStreetMap) | Mappa di base per selettore di posizione, mappa live di Survey, mappa della sessione e prescaricamento | **Impostazioni → Privacy → Consenti tile della mappa** | Solo coordinate del tile `(z, x, y)` — nessun PII |
| Geocoding inverso (OpenStreetMap Nominatim) | Risolvere coordinate GPS in un nome di luogo (es. “Roma, Italia”) | **Impostazioni → Privacy → Consenti ricerca nome luogo** | Lat/lon della sessione e un user-agent generico `BirdNET-Live/<versione>` |
| Snapshot meteo (Open-Meteo) | Cattura una tantum delle condizioni (temperatura, precipitazioni, vento, nuvolosità, codice WMO) alle coordinate e all'orario di fine | **Impostazioni → Privacy → Consenti ricerca meteo** | Lat/lon della sessione e timestamp di fine, più un user-agent generico `BirdNET-Live/<versione>` |

Le richieste di tile sono HTTPS GET standard verso `tile.openstreetmap.org`; il geocoding inverso va a `nominatim.openstreetmap.org` secondo la [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/); le richieste meteo vanno a `api.open-meteo.com`. [Open-Meteo](https://open-meteo.com/) è un servizio gratuito e non richiede né account né chiave API.

**Conservazione:** nessuno dei servizi sopra elencati conserva i tuoi dati. I valori restituiti (nome del luogo, snapshot meteo) vivono solo nel record locale della sessione e viaggiano solo nei file di esportazione che produci esplicitamente.

**Revoca:** puoi disattivare ciascuno dei tre servizi in qualsiasi momento da **Impostazioni → Privacy**. Per cancellare anche i nomi di luogo e gli snapshot meteo già salvati, usa **Impostazioni → Zona pericolosa → Cancella tutti i dati**.

## Gestione ed Esportazione
Esportazione e cancellazione totale sono manuali (impostazioni dell'app > Danger Zone). Sotto **Impostazioni → Esporta → Formati** puoi spuntare qualsiasi combinazione di formati (Raven Selection Table, CSV, JSON, GPX); i formati selezionati vengono raggruppati in un unico ZIP insieme alle clip audio e al report HTML opzionale. Niente viene inviato in server cloud esterni.

## Contatti
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
