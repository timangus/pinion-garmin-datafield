using Toybox.Activity;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class PinionDataField extends WatchUi.SimpleDataField
{
    const BATTERY_DISPLAY_INTERVAL = 15;
    const BATTERY_DISPLAY_DURATION = 5;

    private var _app as App;
    private var _currentGear as Lang.Number = 0;
    private var _batteryLevel as Lang.Number = 0;

    public function initialize(app as App)
    {
        SimpleDataField.initialize();

        _app = app;
        label = Application.loadResource(Rez.Strings.DataFieldLabel) as Lang.String;
    }

    public function compute(info as Activity.Info) as Lang.Numeric or Time.Duration or Lang.String or Null
    {
        _app.update();

        var showGearSetting = Application.Storage.getValue(_app.activityKey("showGear"));
        var showGear = showGearSetting != null ? showGearSetting as Lang.Boolean : true;

        var showBatterySetting = Application.Storage.getValue(_app.activityKey("showBattery"));
        var showBattery = showBatterySetting != null ? showBatterySetting as Lang.Boolean : false;

        if(showBattery && _batteryLevel > 0)
        {
             if(!showGear || Time.now().value() % BATTERY_DISPLAY_INTERVAL < BATTERY_DISPLAY_DURATION)
             {
                return (_batteryLevel / 100.0).format("%.1f") + "%";
             }
        }

        if(showGear && _currentGear > 0)
        {
            return _currentGear;
        }

        return "--";
    }


    public function setCurrentGear(currentGear as Lang.Number) as Void
    {
        _currentGear = currentGear;
    }

    public function setBatteryLevel(batteryLevel as Lang.Number) as Void
    {
        _batteryLevel = batteryLevel;
    }

    public function reset() as Void
    {
        _currentGear = 0;
        _batteryLevel = 0;
    }
}