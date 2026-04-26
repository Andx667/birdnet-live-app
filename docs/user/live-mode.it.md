# Modalità dal vivo

La modalità live è il modo più veloce per ascoltare attraverso il microfono del telefono e rivedere i rilevamenti man mano che appaiono.

## Come aprirlo

Dalla schermata Home, tocca la scheda **Modalità live** con l'icona :material-microphone:.

## Barra superiore

La barra superiore contiene tre elementi:

- :material-arrow-left: - lascia la modalità Live
- Testo dello stato del centro: "Inizializzazione in corso", "Caricamento del modello", "Pronto", "Identificazione della specie", "In pausa" o "Errore"
- :material-tune: — apre la vista Impostazioni specifiche di Live

## Pulsante di azione principale

Il grande pulsante circolare in basso al centro cambia stato:

- :material-microphone: — inizia ad ascoltare
- :material-stop: — interrompe la sessione attiva
- :material-play: - riprendi da uno stato di pausa-pronto

## Cosa vedi mentre ascolti

### Spettrogramma

Lo spettrogramma scorre continuamente mentre la cattura è attiva. Mostra il contenuto della frequenza nel tempo e utilizza la mappa dei colori, la dimensione FFT, l'intervallo di frequenza e la durata dalle Impostazioni.

### Elenco rilevamenti

I rilevamenti recenti vengono visualizzati sotto lo spettrogramma. Ogni riga può mostrare:

- immagine della specie
- nome comune
- nome scientifico facoltativo
- valore di fiducia

Tocca la riga di una specie per aprire la sovrapposizione dei dettagli della specie.

### Barra delle informazioni sulla sessione

La linea informativa compatta sotto lo spettrogramma riassume la sessione corrente, ad esempio:

- rilevamenti attuali mostrati ora
- conteggio delle specie uniche (`spp`)
- rilevazioni totali (`det`)
- durata trascorsa
- dimensione di registrazione stimata quando la registrazione è abilitata

## Comportamento in registrazione

La registrazione è controllata in [Impostazioni](settings.md).

- **Completo** registra l'intera sessione.
- **Solo rilevamenti** registra clip attorno ai rilevamenti.
- **Off** disabilita la registrazione.

Quando interrompi la modalità Live, BirdNET Live salva la sessione e apre [Revisione sessione](session-review.md).