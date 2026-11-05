Sei un esperto sviluppatore Garmin Connect IQ in Monkey C.
Crea da zero in questa cartella il prototipo dell'app "StressGuard" per Garmin fenix6pro (Connect IQ API 3.3+).

Obiettivo del prototipo:
- App di tipo watch-app (widget in seguito) che legge lo stress con Toybox.SensorHistory.getStressHistory, con fallback su ActivityMonitor.getInfo().stressScore.
- Calcola la media degli ultimi 10 minuti.
- Se la media supera una soglia (default 70, in resources/settings/properties.xml) mostra una AlertView a schermo intero con il testo "Stai calmo, livello stress in aumento" e vibra con Toybox.Attention.vibrate.
- Schermata principale: anello colorato verde/giallo/rosso proporzionale allo stress, numero grande al centro, schermo rotondo 260x260.
- Per testare nel simulatore, aggiungi una modalita' debug che simula valori di stress crescenti.

Struttura:
manifest.xml (permesso SensorHistory), monkey.jungle, resources/strings, resources/settings, resources/drawables, source/StressGuardApp.mc, source/StressMonitor.mc, source/AlertEngine.mc, source/views/MainView.mc, source/views/AlertView.mc, source/delegates.

Regole:
- Codice commentato in italiano, controlli "has" sulle API per compatibilita'.
- Crea un CLAUDE.md con contesto del progetto e comandi di build.
- Crea README.md per GitHub e .gitignore (escludi bin/ e la developer key).
- Alla fine spiegami come compilare ed eseguire nel simulatore e come installare il .prg sul Fenix via USB nella cartella GARMIN/APPS.
Procedi un file alla volta e chiedimi conferma prima di passare alla fase successiva.