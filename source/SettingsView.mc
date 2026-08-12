using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;

class SettingsViewInputDelegate extends WatchUi.Menu2InputDelegate
{
    private var _view as SettingsView;

    public function initialize(view as SettingsView)
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

class SettingsView extends WatchUi.Menu2
{
    private var _app as App;

    public function initialize(app as App)
    {
        _app = app;

        WatchUi.Menu2.initialize(null);
        setTitle(Rez.Strings.Settings);

        var deviceSerialNumber = Application.Storage.getValue(_app.activityKey("deviceSerialNumber"));
        if(deviceSerialNumber != null)
        {
            addItem(new WatchUi.MenuItem(Rez.Strings.Unpair,
                deviceSerialNumber.toString(), "unpair", null));
        }

        var showGearSetting = Application.Storage.getValue(_app.activityKey("showGear"));
        var showGear = showGearSetting != null ? showGearSetting as Lang.Boolean : true;
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.ShowGear,
            {:enabled => Rez.Strings.Enabled, :disabled => Rez.Strings.Disabled},
            "show.gear", showGear, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));

        var showBatterySetting = Application.Storage.getValue(_app.activityKey("showBattery"));
        var showBattery = showBatterySetting != null ? showBatterySetting as Lang.Boolean : false;
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.ShowBattery,
            {:enabled => Rez.Strings.Enabled, :disabled => Rez.Strings.Disabled},
            "show.battery", showBattery, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        var showGearToggleMenuItemIndex = findItemById("show.gear");
        var showBatteryToggleMenuItemIndex = findItemById("show.battery");

        if(showGearToggleMenuItemIndex < 0 || showBatteryToggleMenuItemIndex < 0)
        {
            Debug.error("Can't find menu items");
        }

        var showGearToggleMenuItem = getItem(showGearToggleMenuItemIndex) as WatchUi.ToggleMenuItem;
        var showBatteryToggleMenuItem = getItem(showBatteryToggleMenuItemIndex) as WatchUi.ToggleMenuItem;
        var deviceSerialNumber = Application.Storage.getValue(_app.activityKey("deviceSerialNumber"));

        var id = item.getId() as Lang.String or Lang.Symbol;

        // Enforce at least one of Show Gear or Show Battery being enabled
        if(id.equals("show.gear"))
        {
            if(!showGearToggleMenuItem.isEnabled()) { showBatteryToggleMenuItem.setEnabled(true); }
        }
        else if(id.equals("show.battery"))
        {
            if(!showBatteryToggleMenuItem.isEnabled()) { showGearToggleMenuItem.setEnabled(true); }
        }
        else if(id.equals("unpair") && deviceSerialNumber != null)
        {
            _app.unpair();
            var unpairMenuItem = getItem(findItemById("unpair")) as WatchUi.MenuItem;
            unpairMenuItem.setSubLabel(Rez.Strings.Disconnected);
        }

        Application.Storage.setValue(_app.activityKey("showGear"), showGearToggleMenuItem.isEnabled());
        Application.Storage.setValue(_app.activityKey("showBattery"), showBatteryToggleMenuItem.isEnabled());
    }

    public function onBack() as Void
    {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
