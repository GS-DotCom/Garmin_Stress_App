import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Entry point di StressGuard (vedi manifest.xml).
//
// La classe è annotata (:background) perché il sistema la carica anche per
// eseguire il servizio in background; i metodi che usano le viste vengono
// chiamati solo in primo piano.
(:background)
class StressGuardApp extends Application.AppBase {

    // Intervallo del servizio in background: 5 minuti, il minimo consentito
    const BACKGROUND_INTERVAL_SECONDS = 5 * 60;

    // Avviso arrivato dal background quando la vista principale non era
    // visibile (ad esempio durante l'avvio): viene mostrato appena possibile.
    private var _pendingAlert as Boolean = false;
    private var _pendingAverage as Number? = null;
    private var _mainViewActive as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    // onStart/onStop sono chiamati sia in primo piano sia in background:
    // qui non si fa nulla di specifico.
    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Vista iniziale (solo primo piano): è anche il punto in cui si
    // registra il servizio in background.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        registerBackground();
        var view = new MainView();
        return [view, new MainDelegate(view)];
    }

    // Delegate eseguito dal sistema a ogni evento temporale.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BackgroundService()];
    }

    // Risultato del background (Background.exit). Se l'app non era attiva,
    // il sistema lo consegna al successivo avvio, per esempio dopo che
    // l'utente ha confermato il dialogo di requestApplicationWake.
    function onBackgroundData(data as Application.PersistableType) as Void {
        if (!(data instanceof Dictionary) || data["alert"] != true) {
            return;
        }
        var average = data["avg"];
        var averageNumber = (average instanceof Number) ? average : null;

        if (_mainViewActive) {
            showAlert(averageNumber);
        } else {
            _pendingAlert = true;
            _pendingAverage = averageNumber;
        }
    }

    // Impostazioni cambiate da Garmin Connect o dal simulatore.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // --- Metodi usati dalla vista principale ----------------------------------

    function setMainViewActive(active as Boolean) as Void {
        _mainViewActive = active;
    }

    // Mostra l'avviso in sospeso, se c'è. Restituisce true se l'ha mostrato.
    function showPendingAlert() as Boolean {
        if (!_pendingAlert) {
            return false;
        }
        _pendingAlert = false;
        showAlert(_pendingAverage);
        _pendingAverage = null;
        return true;
    }

    // Apre il pop-up "Stai calmo" a schermo intero.
    function showAlert(average as Number?) as Void {
        var view = new AlertView(AlertEngine.getMessage(), average);
        WatchUi.pushView(view, new AlertDelegate(), WatchUi.SLIDE_UP);
    }

    // --- Background -----------------------------------------------------------

    // Registra l'evento periodico ogni 5 minuti, se non è già registrato.
    // La registrazione resta valida anche dopo la chiusura dell'app.
    private function registerBackground() as Void {
        if (!(Toybox.System has :ServiceDelegate)) {
            return; // dispositivo senza supporto al background
        }
        if ((Background has :getTemporalEventRegisteredTime)
                && Background.getTemporalEventRegisteredTime() != null) {
            return;
        }
        Background.registerForTemporalEvent(new Time.Duration(BACKGROUND_INTERVAL_SECONDS));
    }
}

// Accesso tipizzato all'istanza dell'app dalle viste.
function getApp() as StressGuardApp {
    return Application.getApp() as StressGuardApp;
}
