import Toybox.Lang;
import Toybox.WatchUi;

// Tasti del pop-up di avviso: qualsiasi tasto lo chiude e torna alla
// schermata principale.
class AlertDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return close();
    }

    function onBack() as Boolean {
        return close();
    }

    function onNextPage() as Boolean {
        return close();
    }

    function onPreviousPage() as Boolean {
        return close();
    }

    function onMenu() as Boolean {
        return close();
    }

    private function close() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
