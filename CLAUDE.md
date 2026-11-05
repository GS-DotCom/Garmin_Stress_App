# CLAUDE.md – StressGuard

App Garmin Connect IQ in Monkey C che monitora lo stress e mostra un pop-up con vibrazione
("Stai calmo, livello stress in aumento") quando la media supera una soglia.
Prototipo (fase 1-2 del piano in `Agents/linee_guida_app.md`); istruzioni originali in `Agents/Instruction.md`.

- Target: **fenix6pro** (CIQ 3.4.5, schermo rotondo 260x260, background max **32 KB**, icona 40x40)
- Tipo: `watch-app` (diventerà widget), `minApiLevel` 3.3.0 (serve `SensorHistory.getStressHistory`)
- Permessi: `Background`, `SensorHistory`
- SDK in uso: Connect IQ SDK 9.3.0 in `%APPDATA%\Garmin\ConnectIQ\Sdks\`

## Comandi (Git Bash / PowerShell, da questa cartella)

```bash
SDK="$APPDATA/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.3.0-2026-10-20-95888f262/bin"
KEY="$USERPROFILE/.garmin/developer_key.der"   # chiave FUORI dalla repo

# Build di sviluppo (-w mostra tutti gli avvisi: la build deve restare senza warning)
"$SDK/monkeyc.bat" -f monkey.jungle -d fenix6pro -o bin/StressGuard.prg -y "$KEY" -w

# Build di release per l'installazione sull'orologio (senza simboli di debug)
"$SDK/monkeyc.bat" -f monkey.jungle -d fenix6pro -o bin/StressGuard.prg -y "$KEY" -r

# Simulatore + esecuzione
"$SDK/connectiq.bat"                     # avvia il simulatore (una volta)
"$SDK/monkeydo.bat" bin/StressGuard.prg fenix6pro
```

Non esistono test automatici: la verifica è build pulita + prova nel simulatore.

## Architettura

```
StressGuardApp (entry, :background)
 ├─ getInitialView()      -> registra evento temporale ogni 5 min, MainView + MainDelegate
 ├─ getServiceDelegate()  -> BackgroundService
 └─ onBackgroundData()    -> AlertView subito, oppure "in sospeso" se MainView non è visibile

BackgroundService.onTemporalEvent()  (:background, ogni 5 min anche ad app chiusa)
   StressMonitor.getAverage() -> AlertEngine.shouldAlert()
   -> markAlert() + Background.requestApplicationWake(msg) -> Background.exit({avg, alert, time})

MainView (timer one-shot rischedulato: 30 s, 1 s in debug)
   StressMonitor.getAverage() -> AlertEngine.shouldAlert() -> getApp().showAlert() -> AlertView
```

| File | Ruolo |
| --- | --- |
| `source/StressGuardApp.mc` | AppBase, registrazione background, smistamento avvisi |
| `source/StressMonitor.mc` | `getStressHistory` + media finestra, fallback `ActivityMonitor.Info.stressScore`, simulazione debug |
| `source/AlertEngine.mc` | Lettura impostazioni, soglia, periodo di silenzio, stato foreground |
| `source/BackgroundService.mc` | `ServiceDelegate` eseguito ogni 5 minuti |
| `source/views/MainView.mc` | Anello verde/giallo/rosso, numero centrale, badge DEBUG |
| `source/views/AlertView.mc` | Pop-up a schermo intero, `Attention.vibrate` + backlight |
| `source/delegates/` | `MainDelegate` (START = toggle debug), `AlertDelegate` (qualsiasi tasto chiude) |
| `resources/settings/` | `properties.xml` (default) + `settings.xml` (Garmin Connect) |
| `resources/strings/`, `resources-eng/strings/` | Testi italiano (default) e inglese |

### Stato condiviso (Application.Storage, valori in secondi epoch)
- `lastAlert`: ultimo avviso; scritto sia dal background (consentito da CIQ 3.2) sia dal foreground,
  così il periodo di silenzio vale anche se l'utente rifiuta il dialogo di sistema.
- `lastAlertFast`: ultimo avviso della simulazione accelerata (debug in primo piano). Separata da
  `lastAlert`, altrimenti il foreground in debug terrebbe il background sempre in silenzio.
- `fgSeen`: "battito" dell'app aperta (max ogni 20 s). Se recente (< 90 s) il background non
  chiama `requestApplicationWake`: l'avviso arriva via `onBackgroundData`.

### Impostazioni (`properties.xml`)
`StressThreshold`=70 (avviso se media **>** soglia), `WindowMinutes`=10, `QuietMinutes`=30,
`AlertMessage`="" (vuoto = stringa `Rez.Strings.AlertMessage`, che ha `scope="background"`), `DebugMode`=false.

### Modalità debug
Stress simulato 25 → 100 (+3/minuto) su un ciclo di 30 minuti, calcolato solo dall'orario (il
background non ha stato). In primo piano 1 minuto simulato = 2 s (`fast = true`) e anche il
periodo di silenzio è scalato allo stesso modo (chiave `lastAlertFast`); nel background il ciclo
va a velocità reale.

Test del background nel simulatore: *Simulation → Background Events → Temporal Event*. Ad app
chiusa va selezionata **StressGuard come Target app**, altrimenti il simulatore crasha.

## Convenzioni

- Commenti e testi in **italiano**; ogni nuova stringa va anche in `resources-eng/strings/strings.xml`.
- Controlli `has` su ogni API non garantita (`Toybox has :SensorHistory`, `Attention has :vibrate`,
  `WatchUi has :showToast`, `Graphics has :fitTextToArea`, `dc has :setAntiAlias`, …).
- Codice usato dal background annotato `(:background)` e **minimale** (32 KB). Non usare
  `WatchUi` né le viste dal codice di background; per le stringhe usare `Application.loadResource`
  con risorse `scope="background"`.
- Evitare metodi privati con lo stesso nome di un simbolo controllato con `has` (il compilatore avvisa).
- Non committare mai la developer key (`*.der`, `*.pem`) né `bin/` (vedi `.gitignore`).

## Prossime fasi (da `Agents/linee_guida_app.md`)
Notifica al telefono (`PhoneNotifier`, ntfy via `makeWebRequest`, permesso `Communications`),
storico episodi (`EpisodeStore`, `HistoryView`), respirazione guidata (`BreathView`),
rilevamento della salita rapida, filtro durante l'attività sportiva, modalità "situazione delicata",
glance/widget.
