# Calm Guard – App Connect IQ anti-stress per Garmin

## Obiettivo

App per orologi Garmin (Fenix 6 Pro e compatibili) che monitora il livello di stress di chi la indossa e, quando sale oltre una soglia per un tempo minimo, mostra un pop-up con vibrazione ("Stai calmo, livello stress in aumento") e invia opzionalmente una notifica allo smartphone.

## Tecnologie

- **Linguaggio**: Monkey C (linguaggio Garmin, simile a Java/C#).
- **SDK**: Garmin Connect IQ SDK (SDK Manager) + estensione ufficiale Monkey C per VS Code / Cursor.
- **Java JDK 11+** richiesto per compilare.
- **API principali**: `Toybox.SensorHistory.getStressHistory()` (API 3.3.0+), `Toybox.ActivityMonitor.getInfo().stressScore` come fallback, `Toybox.Background` e `Toybox.System.ServiceDelegate` per il controllo periodico, `Toybox.Attention` per vibrazione e suono, `Toybox.Communications.makeWebRequest()` per la notifica al telefono, `Toybox.Application.Storage` e `Properties` per storico e impostazioni.
- **Notifica al telefono**: servizio push esterno raggiungibile via HTTPS, a scelta tra ntfy.sh (gratuito, nessun account) o un bot Telegram. La richiesta parte dall'orologio e passa via Bluetooth attraverso l'app Garmin Connect sul telefono.
- **Simulatore**: Connect IQ Simulator per testare con dati di stress simulati.

## Tipo di app e architettura

Tipo consigliato: **widget** (o "device app" con background), perché serve un servizio in background che giri anche quando l'app non è aperta.

Flusso:

1. Il servizio in background si risveglia ogni 5 minuti (minimo consentito da Garmin) tramite `Background.registerForTemporalEvent`.
2. Legge gli ultimi campioni di stress e calcola la media sugli ultimi N minuti.
3. Confronta con la soglia personale e con la durata minima.
4. Se superata e fuori dal periodo di silenzio, salva l'episodio e chiama `Background.requestApplicationWake()` con il messaggio, che fa comparire il pop-up "Apri Calm Guard?".
5. In parallelo, se attivato, invia la richiesta web al servizio push, che manda la notifica sul telefono.
6. Aprendo l'app si vede il messaggio, lo stress attuale e il pulsante per avviare la respirazione guidata.

## Struttura del progetto

```
CalmGuard/
  manifest.xml            permessi: Background, SensorHistory, Communications
  monkey.jungle           configurazione build e dispositivi
  resources/
    strings/strings.xml   testi (italiano e inglese)
    settings/settings.xml impostazioni modificabili da Garmin Connect
    settings/properties.xml valori di default
    drawables/            icona e grafica
    layouts/              layout delle schermate
  source/
    CalmGuardApp.mc       entry point, registra il background
    StressMonitor.mc      lettura stress e calcolo medie
    AlertEngine.mc        logica soglie, durata, silenzio, anti-falsi positivi
    BackgroundService.mc  ServiceDelegate eseguito ogni 5 minuti
    PhoneNotifier.mc      invio notifica via makeWebRequest
    EpisodeStore.mc       storico episodi in Storage
    views/MainView.mc     schermata principale con stress attuale
    views/AlertView.mc    pop-up "Stai calmo"
    views/BreathView.mc   respirazione guidata con vibrazioni
    views/HistoryView.mc  storico episodi
    delegates/            gestione tasti e input
```

## Impostazioni per l'utente

Modificabili dall'app Garmin Connect sul telefono:

- Soglia di stress (default 70 su 100).
- Durata minima sopra soglia (default 10 minuti).
- Modalità di rilevamento: soglia fissa oppure aumento rapido rispetto alla propria media.
- Messaggio personalizzato del pop-up.
- Periodo di silenzio tra un avviso e l'altro (default 30 minuti).
- Fasce orarie attive e "non disturbare" notturno.
- Notifica al telefono attiva sì/no, con topic ntfy o token Telegram.
- Intensità della vibrazione.

## Elementi distintivi rispetto alle altre app

1. **Trasparenza**: a differenza del promemoria Garmin, soglia e durata sono visibili e regolabili.
2. **Rilevamento della salita, non solo del valore**: avvisa quando lo stress cresce rapidamente rispetto alla propria media del giorno, intercettando il momento in cui ci si sta agitando.
3. **Filtro anti-falsi positivi**: nessun avviso durante un'attività sportiva registrata o con battito da movimento, perché lì lo stress Garmin non è affidabile.
4. **Messaggi personalizzati e a rotazione**, scritti dall'utente.
5. **Respirazione guidata immediata** dal pop-up, con ritmo a vibrazione (per esempio 4 secondi inspira, 6 espira).
6. **Notifica allo smartphone** e, opzionale, a una persona di fiducia.
7. **Diario degli episodi**: ora, picco, durata e nota rapida ("lavoro", "traffico") per capire i fattori scatenanti.
8. **Modalità situazione delicata**: attivabile prima di una riunione o un colloquio, abbassa temporaneamente la soglia e rende l'avviso solo vibrazione, discreto.
9. **Privacy**: dati solo sull'orologio, nessun server proprio.

## Design dell'interfaccia

Scelta: niente quadrante. Calm Guard è un widget o un'app, con al massimo un piccolo dato di stress da mostrare nel quadrante predefinito.

- **Linee guida**: seguire le [linee guida UX ufficiali Connect IQ](https://developer.garmin.com/connect-iq/user-experience-guidelines/) per viste, menu, conferme e barre di avanzamento, così l'app sembra nativa.
- **Perché non un quadrante**: i quadranti restano sempre attivi, consumano più batteria e hanno meno accesso alle funzioni di sistema.
- **Schermo**: Fenix 6 Pro rotondo, 260x260 pixel, pochi colori. Contenuti dentro il cerchio, con margini sui bordi. Layout per forma e risoluzione con cartelle come resources-round-260x260.

Schermate proposte:

1. **Principale**: anello colorato che si riempie col livello di stress (verde, giallo, rosso), numero grande al centro, sotto una piccola linea con l'andamento dell'ultima ora.
2. **Pop-up di avviso**: a schermo intero, poco testo ("Stai calmo"), vibrazione, tasto per avviare la respirazione o chiudere.
3. **Respirazione guidata**: cerchio che si allarga in inspirazione e si stringe in espirazione, con vibrazione a ogni cambio.
4. **Storico**: lista degli episodi con ora, picco e durata.
5. **Glance**: una riga nella lista dei widget con lo stress attuale e il colore del livello.

## Pubblicazione

Per ora progetto personale da portfolio: sito personale e GitHub. Lo Store Connect IQ non è obbligatorio. L'app si installa sul proprio orologio copiando il file .prg compilato nella cartella GARMIN/APPS via USB.

## Confronto con le app esistenti

Le app attuali leggono lo stress e al massimo avvisano sopra una soglia fissa; nessuna notifica il telefono né rileva la salita rapida.

| App | Cosa fa | Avviso | Notifica telefono | Respirazione | Storico episodi |
| --- | --- | --- | --- | --- | --- |
| Promemoria rilassamento Garmin (di serie) | Avviso quando lo stress è insolitamente alto | Sì, soglia non dichiarata | No | Sì | No |
| Body Accounting | Storico Body Battery e stress, promemoria riposo | Sì, beep, vibrazione, riepilogo | No | No | Grafici |
| [JMG-APP Alert HR & Stress](https://apps.garmin.com/en-US/apps/7276d064-a2a9-45f1-b6f2-d059025b918e) | Controllo superamento battito e stress | Sì, soglia | No | No | No |
| [PSX-4](https://apps.garmin.com/en-US/apps/976fb6e7-b289-4606-adf4-1eb643215ec0) | Battito, respirazione e stress in diretta | No | No | No | No |
| Stress Meter, Heart Rate Stress Score | Misura dello stress | No | No | No | No |
| **Calm Guard** | Monitoraggio con soglia e salita rapida | Sì, regolabile e personalizzato | Sì, anche persona di fiducia | Sì, dal pop-up | Sì, con etichette |

Punti unici di Calm Guard: notifica allo smartphone, rilevamento della salita, modalità situazione delicata, messaggi personali, filtro durante lo sport, diario con cause.

## Tempi di sviluppo con Claude Code

Stima per sviluppo serale o nel weekend, con Claude Code nel terminale di Cursor; la parte più lenta è il test sull'orologio reale, non la scrittura del codice.

| Fase | Contenuto | Tempo stimato |
| --- | --- | --- |
| 0. Setup | SDK Connect IQ, JDK, estensione Monkey C, simulatore, progetto vuoto | 2-4 ore |
| 1. Prototipo embrionale | Lettura stress, soglia fissa, pop-up con vibrazione nel simulatore | 1 weekend |
| 2. Background e impostazioni | Servizio ogni 5 minuti, impostazioni da Garmin Connect, silenzio | 1 settimana |
| 3. Notifica telefono | makeWebRequest verso ntfy | 2-3 serate |
| 4. Respirazione e storico | Schermate dedicate, Storage | 1 settimana |
| 5. Funzioni distintive | Salita rapida, filtro sport, modalità delicata, design | 1-2 settimane |
| 6. Test e portfolio | Prove sul Fenix 6 Pro, README, screenshot, pagina sul sito | 1 settimana |

Stima in ore con 5-6 ore al giorno disponibili:

| Fase | Ore |
| --- | --- |
| 0. Setup | 3 |
| 1. Prototipo | 10 |
| 2. Background e impostazioni | 12 |
| 3. Notifica telefono | 6 |
| 4. Respirazione e storico | 12 |
| 5. Funzioni distintive e design | 18 |
| 6. Test e portfolio | 10 |
| **Totale** | **circa 70 (+20% margine)** |

Prototipo (fasi 0-1): circa 13 ore, cioè 2-3 giorni. Progetto completo: 12-14 giorni lavorativi, circa due settimane e mezza.

## Setup di Cursor per il prototipo

1. Installare **Java JDK 17** e verificare con `java -version`.
2. Scaricare il **Connect IQ SDK Manager** dal sito developer Garmin, installare l'ultimo SDK e il dispositivo **fenix6pro**.
3. In Cursor installare l'estensione **Monkey C** di Garmin; se non compare nel marketplace di Cursor, scaricare il file .vsix e installarlo da "Install from VSIX".
4. Dalla palette comandi: **Monkey C: Verify Installation**, poi **Monkey C: Generate a Developer Key** (salvare la chiave fuori dalla repo).
5. Installare **Claude Code** con `npm install -g @anthropic-ai/claude-code` (serve Node.js 18+), aprire la cartella CalmGuard in Cursor e lanciare `claude` nel terminale integrato.
6. Utili ma facoltative: estensione **GitLens** e **XML** di Red Hat per i file di risorse.

## Prompt per Claude Code (prototipo)

```
Sei un esperto sviluppatore Garmin Connect IQ in Monkey C.
Crea da zero in questa cartella il prototipo dell'app "CalmGuard" per Garmin fenix6pro (Connect IQ API 3.3+).

Obiettivo del prototipo:
- App di tipo watch-app (widget in seguito) che legge lo stress con Toybox.SensorHistory.getStressHistory, con fallback su ActivityMonitor.getInfo().stressScore.
- Calcola la media degli ultimi 10 minuti.
- Se la media supera una soglia (default 70, in resources/settings/properties.xml) mostra una AlertView a schermo intero con il testo "Stai calmo, livello stress in aumento" e vibra con Toybox.Attention.vibrate.
- Schermata principale: anello colorato verde/giallo/rosso proporzionale allo stress, numero grande al centro, schermo rotondo 260x260.
- Per testare nel simulatore, aggiungi una modalita' debug che simula valori di stress crescenti.

Struttura:
manifest.xml (permesso SensorHistory), monkey.jungle, resources/strings, resources/settings, resources/drawables, source/CalmGuardApp.mc, source/StressMonitor.mc, source/AlertEngine.mc, source/views/MainView.mc, source/views/AlertView.mc, source/delegates.

Regole:
- Codice commentato in italiano, controlli "has" sulle API per compatibilita'.
- Crea un CLAUDE.md con contesto del progetto e comandi di build.
- Crea README.md per GitHub e .gitignore (escludi bin/ e la developer key).
- Alla fine spiegami come compilare ed eseguire nel simulatore e come installare il .prg sul Fenix via USB nella cartella GARMIN/APPS.
Procedi un file alla volta e chiedimi conferma prima di passare alla fase successiva.
```

## Limiti da conoscere

- Il background gira al massimo ogni 5 minuti: si intercetta lo stress che sale e persiste, non lo scatto istantaneo. Per il tempo reale serve tenere l'app aperta in primo piano (modalità sessione).
- Lo stress Garmin si basa sull'HRV: caffè, caldo, salire le scale lo alzano come la rabbia.
- Memoria limitata per il background (pochi KB): codice del servizio essenziale.
- La notifica al telefono richiede l'orologio collegato via Bluetooth e Garmin Connect attivo.

## Piano di sviluppo

1. **MVP**: lettura stress, soglia fissa, pop-up con vibrazione, test nel simulatore.
2. Impostazioni da Garmin Connect e periodo di silenzio.
3. Notifica al telefono con ntfy.
4. Respirazione guidata e storico episodi.
5. Rilevamento della salita, filtro attività, modalità situazione delicata.
6. Test sul Fenix 6 Pro reale, poi pubblicazione sul Connect IQ Store e su GitHub.

## Prompt di partenza per Cursor

"Crea un progetto Garmin Connect IQ in Monkey C chiamato CalmGuard, target fenix6pro, con la struttura di cartelle indicata in questo documento. Implementa un servizio in background ogni 5 minuti che legge SensorHistory.getStressHistory, calcola la media degli ultimi 10 minuti e, se supera la soglia definita in properties.xml, chiama Background.requestApplicationWake con un messaggio. Aggiungi una AlertView che vibra con Toybox.Attention e mostra il messaggio."
