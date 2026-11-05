import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Servizio eseguito dal sistema ogni 5 minuti (evento temporale registrato
// in StressGuardApp), anche quando l'app è chiusa.
//
// Flusso:
//   1. calcola la media dello stress sulla finestra configurata;
//   2. se supera la soglia ed è fuori dal periodo di silenzio, registra
//      l'avviso e chiede al sistema di aprire l'app con il messaggio;
//   3. termina con Background.exit(), passando il risultato all'app.
(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // In background la simulazione debug procede a velocità reale
        var average = StressMonitor.getAverage(
            AlertEngine.getWindowMinutes(), AlertEngine.isDebugMode(), false);
        var alert = AlertEngine.shouldAlert(average, false);

        if (alert) {
            AlertEngine.markAlert(false);
            // Se l'app è già aperta non serve il pop-up di sistema:
            // l'avviso arriva tramite onBackgroundData().
            if (!AlertEngine.isForegroundActive()) {
                requestWake(AlertEngine.getMessage());
            }
        }

        // Il dialogo di requestApplicationWake compare solo dopo exit()
        Background.exit({
            "avg" => average,
            "alert" => alert,
            "time" => Time.now().value()
        });
    }

    // Mostra il dialogo di sistema che propone di aprire StressGuard.
    private function requestWake(message as String) as Void {
        if (!(Background has :requestApplicationWake)) {
            return;
        }
        try {
            Background.requestApplicationWake(message);
        } catch (e instanceof Background.MessageSizeLimitException) {
            // Messaggio personalizzato oltre 255 byte: si usa quello di riserva
            Background.requestApplicationWake(AlertEngine.DEFAULT_MESSAGE);
        }
    }
}
