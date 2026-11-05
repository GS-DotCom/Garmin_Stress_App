import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;

// Lettura dello stress e calcolo della media sugli ultimi N minuti.
//
// Il modulo è annotato (:background) perché viene usato sia dall'app in
// primo piano sia dal servizio in background (memoria limitata a 32 KB):
// il codice deve restare essenziale.
(:background)
module StressMonitor {

    // --- Modalità debug -----------------------------------------------------
    // La simulazione genera uno stress che sale di 3 punti al "minuto"
    // (da 25 fino a 100) e riparte da capo ogni 30 minuti simulati.
    // In primo piano un minuto simulato dura 2 secondi, così nel simulatore
    // l'avviso scatta dopo circa 40 secondi; in background dura un minuto reale.
    const DEBUG_CYCLE_MINUTES = 30;
    const DEBUG_SECONDS_PER_MINUTE = 2;
    const DEBUG_START_VALUE = 25;
    const DEBUG_STEP = 3;

    // Restituisce la media dello stress (0-100) sugli ultimi windowMinutes
    // minuti, oppure null se non ci sono dati disponibili.
    //   debug -> usa i valori simulati invece dei sensori
    //   fast  -> simulazione accelerata (solo per l'app in primo piano)
    function getAverage(windowMinutes as Number, debug as Boolean, fast as Boolean) as Number? {
        if (debug) {
            return simulatedAverage(simulatedMinute(fast), windowMinutes);
        }

        var average = averageFromHistory(windowMinutes);
        if (average == null) {
            // Fallback: valore istantaneo, se il dispositivo lo espone
            average = currentStressScore();
        }
        return average;
    }

    // Media dei campioni di SensorHistory.getStressHistory() nella finestra.
    function averageFromHistory(windowMinutes as Number) as Number? {
        // Controllo di compatibilità: getStressHistory esiste da API 3.3.0
        if (!((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory))) {
            return null;
        }

        var iterator = SensorHistory.getStressHistory({
            :period => new Time.Duration(windowMinutes * 60),
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });

        // Alcuni dispositivi restituiscono anche campioni più vecchi del
        // periodo richiesto: si scartano confrontando l'orario del campione.
        var cutoff = Time.now().value() - windowMinutes * 60;
        var sum = 0.0;
        var count = 0;

        var sample = iterator.next();
        while (sample != null) {
            var when = sample.when;
            if (when != null && when.value() < cutoff) {
                break; // ordine dal più recente: i successivi sono più vecchi
            }
            var value = sample.data;
            // Si ignorano i campioni nulli o fuori scala (stress non misurato)
            if (value != null && value >= 0 && value <= 100) {
                sum += value;
                count += 1;
            }
            sample = iterator.next();
        }

        if (count == 0) {
            return null;
        }
        return (sum / count + 0.5).toNumber(); // arrotondamento all'intero
    }

    // Valore di stress istantaneo da ActivityMonitor (fallback).
    // stressScore non è disponibile su tutti i dispositivi (ad esempio manca
    // sul fenix6pro): il controllo "has" evita l'errore a runtime.
    function currentStressScore() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info has :stressScore) {
            var score = info.stressScore;
            if (score != null) {
                return score.toNumber();
            }
        }
        return null;
    }

    // --- Simulazione ---------------------------------------------------------

    // Minuto corrente all'interno del ciclo di simulazione (0..29).
    // Dipende solo dall'orologio, quindi funziona anche nel background, che
    // non mantiene stato tra un'esecuzione e l'altra.
    function simulatedMinute(fast as Boolean) as Number {
        var secondsPerMinute = fast ? DEBUG_SECONDS_PER_MINUTE : 60;
        return (Time.now().value() / secondsPerMinute) % DEBUG_CYCLE_MINUTES;
    }

    // Valore simulato al minuto indicato: cresce in modo lineare fino a 100.
    function simulatedValue(minute as Number) as Number {
        var value = DEBUG_START_VALUE + minute * DEBUG_STEP;
        return value > 100 ? 100 : value;
    }

    // Media dei valori simulati negli ultimi windowMinutes minuti del ciclo.
    function simulatedAverage(minute as Number, windowMinutes as Number) as Number {
        var sum = 0;
        var count = 0;
        for (var m = minute; m >= 0 && m > minute - windowMinutes; m -= 1) {
            sum += simulatedValue(m);
            count += 1;
        }
        return (sum + count / 2) / count; // count è sempre >= 1
    }
}
