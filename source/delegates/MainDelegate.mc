import Toybox.Lang;
import Toybox.WatchUi;

// Tasti della schermata principale.
//   START (select) -> attiva/disattiva la modalità debug con valori simulati,
//                     utile per provare l'avviso nel simulatore
//   BACK           -> comportamento di sistema (chiude l'app)
class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _view as MainView;

    function initialize(view as MainView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.toggleDebug();
        return true;
    }
}
