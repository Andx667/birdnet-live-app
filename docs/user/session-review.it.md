# Revisione della sessione

Session Review è il luogo in cui BirdNET Live trasforma i rilevamenti in un record modificabile.

## Come raggiungerlo

BirdNET Live apre automaticamente la revisione della sessione dopo aver completato:

- una sessione dal vivo
- un conteggio dei punti
- un sondaggio
- un'esecuzione di analisi dei file

Puoi anche riaprire qualsiasi sessione salvata da [Libreria sessioni](session-library.md).

## Aree principali

### Riepilogo e riproduzione

Session Review combina la riproduzione, la navigazione dello spettrogramma e un elenco di specie. Per le sessioni di sondaggio può anche mostrare il contesto mappato.

### Elenco delle specie

Le specie sono raggruppate in righe espandibili. Puoi esaminare i rilevamenti per specie e spostarti nella registrazione mentre li rivedi.

### Mappa del percorso del sondaggio

Le sessioni di sondaggio mostrano una piccola mappa in linea della traccia GPS e degli indicatori di rilevamento. Tocca un indicatore sulla mappa in linea per mettere a fuoco un rilevamento — la mappa si centra su di esso. Tocca il pulsante :material-fullscreen: **espandi** (in alto a destra della mappa in linea) per aprire la **mappa a schermo intero**; se un rilevamento era a fuoco, la mappa a schermo intero si apre centrata e ingrandita su quel rilevamento in modo da mantenere il proprio posto.

#### Codifica degli indicatori

- **La confidenza è codificata per colore** con una palette sicura per i daltonici (CVD): la confidenza da bassa ad alta passa dal viola-blu al turchese/giallo al rosso. La luminosità della palette cambia in modo monotono, quindi rimane leggibile in monocromia e per gli utenti con deficienza visiva rosso-verde.
- **I rilevamenti con audio** mostrano un anello colorato attorno alla foto della specie più un distintivo di riproduzione nell'angolo — toccali per riprodurre il clip registrato in un foglio.
- **I rilevamenti silenziosi** (nessun clip su disco) vengono visualizzati più piccoli, sbiaditi e con un anello grigio neutro, in modo che i rilevamenti audio si leggano sempre come contenuto principale.
- **Gli indicatori sovrapposti nello stesso punto** sono ordinati per importanza: evidenziato > con audio > maggiore confidenza, in modo che un indicatore silenzioso a bassa confidenza non possa mai oscurare un forte rilevamento audio.
- **Al di sotto dello zoom 14,5** le sagome degradano a punti colorati dimensionati per confidenza e i cluster densi si comprimono in una bolla di conteggio (il clustering si disattiva allo zoom 15).

#### Filtraggio

La mappa a schermo intero ha un **chip di filtro** persistente ancorato in alto a destra. Toccalo per aprire il foglio dei filtri; l'etichetta del chip mostra sempre cosa è attualmente attivo (*«Tutte le specie»*, *«Con audio»*, *«≥ 80 %»* o il nome di una singola specie). Filtri disponibili:

- **Tutti i rilevamenti** (predefinito).
- **Con clip audio** — solo rilevamenti il cui clip è ancora su disco e riproducibile.
- **Aggiunte manuali** — solo rilevamenti aggiunti in Revisione sessione (esclude quelli rilevati automaticamente).

Puoi anche limitare i rilevamenti per livello di confidenza. Il cursore configura la soglia minima di confidenza (inizia al 10 %).

Sotto il cursore di confidenza c'è un selettore **Limita alle specie** che ti permette di comprimere la mappa a una singola specie — utile per chiedere «dove esattamente lungo il percorso ho sentito il tordo dei boschi?». Una voce *Tutte le specie* cancella la restrizione di specie. I filtri si combinano: ad es. *Con clip audio* + *Tordo dei boschi* + *> 80 %* mostra solo gli indicatori riproducibili del Tordo dei boschi che hanno superato l'80 %.

Quando un filtro è attivo, il titolo della barra dell'app ottiene un sottotitolo con il numero di corrispondenze (ad es. *«7 rilevamenti»*). *Reimposta* nel foglio torna al valore predefinito.

## Icone della barra degli strumenti

La barra degli strumenti utilizza gli stessi significati delle icone descritti in [Icone e controlli](icons-and-controls.md):

- :material-plus-circle-outline: - aggiungi contenuto
- :material-undo-variant: / :material-redo-variant: - passa attraverso le modifiche
- :material-content-cut: - modalità di ritaglio
- :material-content-save: - salva le modifiche
- :material-share-variant: — esportazione o condivisione
- :material-delete-outline: - sessione di eliminazione
- :material-play: — continua un sondaggio quando l'azione è disponibile
- :material-help-circle-outline: - apre il foglio di aiuto per la revisione della sessione
- :material-tune: - apri Impostazioni

## Attività tipiche di revisione

- verificare i rilevamenti rispetto alla riproduzione e al contesto dello spettrogramma
- aggiungere una specie o un'annotazione
- ritagliare la registrazione all'intervallo utile
- esportare il set di risultati rivisto

## Esporta

Il comportamento dell'esportazione dipende dalle opzioni selezionate in [Impostazioni](settings.md). L'app può comprimere i rilevamenti e, facoltativamente, l'audio nel formato di esportazione scelto. Ogni esportazione ora viene fornita con metadati di provenienza completi (versione dell'app, nome e versione del modello, impostazioni locali della specie, timestamp di esportazione e un'istantanea di tutte le impostazioni al momento dell'esportazione) scritti in un file laterale "<prefix>.metadata.json" (ZIP) o in un blocco "meta" di livello superiore (JSON) in modo che le esportazioni siano autodescrittive e riproducibili.