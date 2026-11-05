import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Pop-up di avviso a schermo intero: "Stai calmo, livello stress in aumento".
// All'apertura vibra con Toybox.Attention e accende la retroilluminazione.
// Si chiude con qualsiasi tasto (vedi AlertDelegate).
class AlertView extends WatchUi.View {

    // Sfondo rosso scuro: leggibile e coerente con l'anello "rosso"
    const BACKGROUND_COLOR = 0xAA0000;

    // Area del messaggio rispetto allo schermo rotondo (in percentuale)
    const TEXT_AREA_WIDTH_PCT = 78;
    const TEXT_AREA_HEIGHT_PCT = 44;

    // Posizioni verticali (percentuale dell'altezza dello schermo)
    const NUMBER_Y_PCT = 16;
    const MESSAGE_Y_PCT = 53;
    const HINT_Y_PCT = 88;

    private var _message as String;
    private var _average as Number?;
    private var _hint as String;

    // Messaggio già mandato a capo e font scelto (calcolati una volta sola)
    private var _wrappedMessage as String? = null;
    private var _messageFont as Graphics.FontType = Graphics.FONT_SMALL;

    function initialize(message as String, average as Number?) {
        View.initialize();
        _message = message;
        _average = average;
        _hint = WatchUi.loadResource(Rez.Strings.AlertHint) as String;
    }

    function onShow() as Void {
        startVibration();
        turnOnBacklight();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, BACKGROUND_COLOR);
        dc.clear();

        // Valore medio che ha fatto scattare l'avviso, in alto
        var average = _average;
        if (average != null) {
            dc.drawText(cx, height * NUMBER_Y_PCT / 100, Graphics.FONT_NUMBER_MEDIUM, average.toString(), center);
        }

        // Messaggio al centro, mandato a capo per stare nel cerchio
        var message = wrapMessage(width, height);
        dc.drawText(cx, height * MESSAGE_Y_PCT / 100, _messageFont, message, center);

        // Suggerimento in basso
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * HINT_Y_PCT / 100, Graphics.FONT_XTINY, _hint, center);
    }

    // Manda a capo il messaggio scegliendo il font più grande in cui entra
    // per intero; solo con il font più piccolo si accetta il troncamento.
    // fitTextToArea esiste da API 3.1.0: senza, si disegna il testo così com'è.
    private function wrapMessage(width as Number, height as Number) as String {
        var wrapped = _wrappedMessage;
        if (wrapped != null) {
            return wrapped;
        }
        if (!(Graphics has :fitTextToArea)) {
            _wrappedMessage = _message;
            return _message;
        }

        var areaWidth = width * TEXT_AREA_WIDTH_PCT / 100;
        var areaHeight = height * TEXT_AREA_HEIGHT_PCT / 100;
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY];
        for (var i = 0; i < fonts.size(); i += 1) {
            var isLast = (i == fonts.size() - 1);
            // truncate = false: restituisce null se il testo non entra
            var fitted = Graphics.fitTextToArea(_message, fonts[i], areaWidth, areaHeight, isLast);
            if (fitted != null) {
                _messageFont = fonts[i];
                _wrappedMessage = fitted;
                return fitted;
            }
        }
        _wrappedMessage = _message;
        return _message;
    }

    // Tre impulsi di vibrazione, l'ultimo più lungo.
    private function startVibration() as Void {
        if (!(Attention has :vibrate)) {
            return; // dispositivo senza motore di vibrazione
        }
        Attention.vibrate([
            new Attention.VibeProfile(100, 400),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 400),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 700)
        ]);
    }

    // Accende lo schermo per rendere visibile il messaggio.
    private function turnOnBacklight() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        try {
            Attention.backlight(true);
        } catch (e instanceof Attention.BacklightOnTooLongException) {
            // Retroilluminazione accesa troppo a lungo: il sistema la limita
        }
    }
}
