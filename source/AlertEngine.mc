import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Logica degli avvisi: soglia, periodo di silenzio e lettura delle impostazioni.
//
// Annotato (:background) perché la stessa logica serve al servizio in
// background e all'app in primo piano.
(:background)
module AlertEngine {

    // Chiavi in Application.Storage (valori: secondi epoch, es. 1762365600)
    const KEY_LAST_ALERT = "lastAlert";        // ultimo avviso mostrato/richiesto
    // Ultimo avviso della simulazione accelerata (debug in primo piano).
    // Chiave separata: il suo silenzio dura pochi secondi e non deve far
    // tacere il background, che misura il silenzio in minuti reali.
    const KEY_LAST_ALERT_FAST = "lastAlertFast";
    const KEY_FOREGROUND_SEEN = "fgSeen";      // ultimo "battito" dell'app aperta

    // Se l'app ha dato segni di vita negli ultimi 90 secondi è in primo piano:
    // il background non chiede di aprirla (l'avviso arriva via onBackgroundData).
    const FOREGROUND_TIMEOUT = 90;

    // Testo di riserva, se le risorse non sono caricabili (API < 3.1)
    const DEFAULT_MESSAGE = "Stai calmo, livello stress in aumento";

    // --- Impostazioni (resources/settings/properties.xml) -------------------

    function getThreshold() as Number {
        return readNumber("StressThreshold", 70, 1, 100);
    }

    function getWindowMinutes() as Number {
        return readNumber("WindowMinutes", 10, 5, 60);
    }

    function getQuietMinutes() as Number {
        return readNumber("QuietMinutes", 30, 0, 240);
    }

    function isDebugMode() as Boolean {
        return readValue("DebugMode") == true;
    }

    // Messaggio dell'avviso: quello personalizzato o, se vuoto, il testo
    // tradotto di default (stringa con scope="background").
    function getMessage() as String {
        var custom = readValue("AlertMessage");
        if (custom instanceof String && custom.length() > 0) {
            return custom;
        }
        if (Application has :loadResource) {
            return Application.loadResource($.Rez.Strings.AlertMessage) as String;
        }
        return DEFAULT_MESSAGE;
    }

    // --- Decisione -----------------------------------------------------------

    // true se la media supera la soglia e non si è nel periodo di silenzio.
    //   fast -> simulazione accelerata: il silenzio si misura in "minuti
    //           simulati" (2 secondi), coerente con StressMonitor.
    function shouldAlert(average as Number?, fast as Boolean) as Boolean {
        if (average == null || average <= getThreshold()) {
            return false;
        }
        return !isInQuietPeriod(fast);
    }

    function isInQuietPeriod(fast as Boolean) as Boolean {
        var last = Storage.getValue(lastAlertKey(fast));
        if (!(last instanceof Number)) {
            return false;
        }
        var secondsPerMinute = fast ? StressMonitor.DEBUG_SECONDS_PER_MINUTE : 60;
        return Time.now().value() - last < getQuietMinutes() * secondsPerMinute;
    }

    // Registra l'avviso per far partire il periodo di silenzio.
    //   fast -> avviso della simulazione accelerata: usa la chiave separata
    // Dal background la scrittura è consentita solo da CIQ 3.2.0 in poi:
    // sui dispositivi più vecchi l'eccezione viene ignorata.
    function markAlert(fast as Boolean) as Void {
        safeStore(lastAlertKey(fast), Time.now().value());
    }

    function lastAlertKey(fast as Boolean) as String {
        return fast ? KEY_LAST_ALERT_FAST : KEY_LAST_ALERT;
    }

    // --- Stato dell'app in primo piano ---------------------------------------

    // Chiamata periodicamente dalla vista principale quando è visibile.
    function markForeground() as Void {
        safeStore(KEY_FOREGROUND_SEEN, Time.now().value());
    }

    function isForegroundActive() as Boolean {
        var seen = Storage.getValue(KEY_FOREGROUND_SEEN);
        return (seen instanceof Number) && (Time.now().value() - seen < FOREGROUND_TIMEOUT);
    }

    // --- Utilità --------------------------------------------------------------

    // Legge una property; null se manca o non è leggibile.
    function readValue(key as String) as PropertyValueType? {
        try {
            return Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }

    // Legge una property numerica con default e limiti.
    function readNumber(key as String, defaultValue as Number, min as Number, max as Number) as Number {
        var value = readValue(key);
        if (value instanceof Float) {
            value = value.toNumber();
        }
        if (!(value instanceof Number)) {
            return defaultValue;
        }
        if (value < min) {
            return min;
        }
        return value > max ? max : value;
    }

    function safeStore(key as String, value as Number) as Void {
        try {
            Storage.setValue(key, value);
        } catch (e) {
            // ObjectStoreAccessException (background su CIQ < 3.2) o memoria piena
        }
    }
}
