import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Schermata principale: anello colorato che si riempie in proporzione allo
// stress medio, numero grande al centro, finestra della media sotto.
// Pensata per lo schermo rotondo 260x260 del fenix6pro, ma calcolata sulle
// dimensioni reali del display.
class MainView extends WatchUi.View {

    // Aggiornamento: ogni 30 s con i dati reali, ogni secondo in debug
    const REFRESH_MS = 30000;
    const REFRESH_DEBUG_MS = 1000;
    const FIRST_REFRESH_MS = 200;

    // "Battito" verso il background al massimo ogni 20 s (vedi AlertEngine)
    const FOREGROUND_MARK_SECONDS = 20;

    // Geometria dell'anello
    const RING_WIDTH = 16;
    const RING_MARGIN = 6;

    // Sotto questo valore l'anello è verde; tra questo e la soglia è giallo
    const GREEN_LIMIT = 40;

    private var _timer as Timer.Timer?;
    private var _average as Number? = null;
    private var _windowMinutes as Number = 10;
    private var _threshold as Number = 70;
    private var _debug as Boolean = false;
    private var _lastForegroundMark as Number = 0;

    // Testi caricati una sola volta
    private var _labelMain as String;
    private var _labelWindow as String;
    private var _labelNoData as String;
    private var _labelDebug as String;

    function initialize() {
        View.initialize();
        _labelMain = WatchUi.loadResource(Rez.Strings.MainLabel) as String;
        _labelWindow = WatchUi.loadResource(Rez.Strings.MainWindow) as String;
        _labelNoData = WatchUi.loadResource(Rez.Strings.NoData) as String;
        _labelDebug = WatchUi.loadResource(Rez.Strings.DebugBadge) as String;
    }

    // --- Ciclo di vita ---------------------------------------------------------

    function onShow() as Void {
        getApp().setMainViewActive(true);
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        // Primo aggiornamento quasi immediato: mostra anche un eventuale
        // avviso arrivato dal background durante l'avvio.
        scheduleRefresh(FIRST_REFRESH_MS);
    }

    function onHide() as Void {
        getApp().setMainViewActive(false);
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
    }

    // Callback del timer (deve essere pubblica per method(:onTimer)).
    function onTimer() as Void {
        refresh();
        markForeground();

        // 1. avviso già deciso dal background
        if (getApp().showPendingAlert()) {
            return; // il timer riparte in onShow, al ritorno dal pop-up
        }
        // 2. controllo in primo piano, con la stessa logica del background
        if (AlertEngine.shouldAlert(_average, _debug)) {
            AlertEngine.markAlert(_debug);
            getApp().showAlert(_average);
            return;
        }

        scheduleRefresh(_debug ? REFRESH_DEBUG_MS : REFRESH_MS);
        WatchUi.requestUpdate();
    }

    // Attiva/disattiva la modalità debug (tasto START, vedi MainDelegate).
    function toggleDebug() as Void {
        var enabled = !AlertEngine.isDebugMode();
        Properties.setValue("DebugMode", enabled);

        // showToast esiste da API 3.4.0: controllo di compatibilità
        if (WatchUi has :showToast) {
            WatchUi.showToast(enabled ? Rez.Strings.DebugOn : Rez.Strings.DebugOff, null);
        }
        scheduleRefresh(FIRST_REFRESH_MS);
    }

    // --- Dati ------------------------------------------------------------------

    private function refresh() as Void {
        _debug = AlertEngine.isDebugMode();
        _threshold = AlertEngine.getThreshold();
        _windowMinutes = AlertEngine.getWindowMinutes();
        // fast = true: in primo piano la simulazione è accelerata
        _average = StressMonitor.getAverage(_windowMinutes, _debug, true);
    }

    private function markForeground() as Void {
        var now = Time.now().value();
        if (now - _lastForegroundMark >= FOREGROUND_MARK_SECONDS) {
            AlertEngine.markForeground();
            _lastForegroundMark = now;
        }
    }

    private function scheduleRefresh(delayMs as Number) as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            timer.start(method(:onTimer), delayMs, false);
        }
    }

    // --- Disegno ---------------------------------------------------------------

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;
        var size = width < height ? width : height;
        var radius = size / 2 - RING_MARGIN - RING_WIDTH / 2;

        // Antialiasing disponibile da API 3.2.0
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        drawRing(dc, cx, cy, radius);
        drawTexts(dc, cx, cy);
    }

    // Anello: traccia grigia + arco colorato in senso orario da ore 12.
    private function drawRing(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number) as Void {
        dc.setPenWidth(RING_WIDTH);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        var average = _average;
        if (average == null || average <= 0) {
            return;
        }

        dc.setColor(levelColor(average), Graphics.COLOR_TRANSPARENT);
        if (average >= 100) {
            dc.drawCircle(cx, cy, radius);
        } else {
            // 0° = ore 3, angoli in senso antiorario: si parte da 90° (ore 12)
            var sweep = average * 360 / 100;
            var endAngle = (90 - sweep + 360) % 360;
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, endAngle);
        }
        dc.setPenWidth(1);
    }

    // Numero centrale, etichette e badge della modalità debug.
    private function drawTexts(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var smallFont = Graphics.FONT_XTINY;
        var smallHeight = dc.getFontHeight(smallFont);
        var average = _average;

        var numberFont = Graphics.FONT_NUMBER_THAI_HOT;
        var numberHeight = dc.getFontHeight(numberFont);
        var top = cy - numberHeight / 2;
        var bottom = cy + numberHeight / 2;

        // Etichetta sopra il numero
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top - smallHeight / 2, smallFont, _labelMain, center);

        // Numero grande (i font numerici contengono solo cifre)
        if (average != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, numberFont, average.toString(), center);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, _labelNoData, center);
        }

        // Finestra della media sotto il numero
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bottom + smallHeight / 2, smallFont,
            Lang.format(_labelWindow, [_windowMinutes]), center);

        if (_debug) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bottom + smallHeight * 3 / 2 + 2, smallFont, _labelDebug, center);
        }
    }

    // Verde sotto GREEN_LIMIT, rosso oltre la soglia, giallo in mezzo.
    private function levelColor(value as Number) as Graphics.ColorType {
        if (value > _threshold) {
            return Graphics.COLOR_RED;
        }
        if (value >= GREEN_LIMIT) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_GREEN;
    }
}
