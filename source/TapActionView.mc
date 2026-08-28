using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class TapActionViewInputDelegate extends WatchUi.Menu2InputDelegate
{
    private var _view as TapActionView;

    public function initialize(view as TapActionView)
    {
        WatchUi.Menu2InputDelegate.initialize();
        _view = view;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        _view.onSelect(item);
    }

    public function onBack() as Void
    {
        _view.onBack();
    }
}

class TapActionView extends WatchUi.Menu2
{
    private var _app as App;
    private var _settingsView as SettingsView;

    public function initialize(app as App, settingsView as SettingsView)
    {
        _app = app;
        _settingsView = settingsView;

        WatchUi.Menu2.initialize(null);
        setTitle(Rez.Strings.TapActionTitle);

        Debug.assert(System.getDeviceSettings().isTouchScreen,
            "TapActionView shouldn't be instantiated on a non-touchscreen device");

        addItem(new WatchUi.MenuItem(Rez.Strings.NoAction, null, "no.action", null));
        addItem(new WatchUi.MenuItem(Rez.Strings.TogglePreSelect, null, "pre.select", null));
        addItem(new WatchUi.MenuItem(Rez.Strings.ToggleStartSelect, null, "start.select", null));
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        var id = item.getId() as Lang.String or Lang.Symbol;

        if(id.equals("no.action"))
        {
            Application.Storage.setValue(_app.activityKey("tapAction"), App.NO_ACTION);
            Debug.log("TapActionView.onSelect NO_ACTION");
        }
        else if(id.equals("pre.select"))
        {
            Application.Storage.setValue(_app.activityKey("tapAction"), App.TOGGLE_PRE_SELECT);
            Debug.log("TapActionView.onSelect TOGGLE_PRE_SELECT");
        }
        else if(id.equals("start.select"))
        {
            Application.Storage.setValue(_app.activityKey("tapAction"), App.TOGGLE_START_SELECT);
            Debug.log("TapActionView.onSelect TOGGLE_START_SELECT");
        }

        _settingsView.refreshTapActionMenuItemText();
        _app.syncTapActionState();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    public function onBack() as Void
    {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
