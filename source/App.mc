using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.BluetoothLowEnergy as Ble;

class App extends Application.AppBase
{
    const RECONNECTION_DELAY = 1000;

    enum State
    {
        STARTING,
        SCANNING,
        CONNECTING,
        CONNECTED,
        STOPPING,
    }

    private var _state as State = STARTING;

    private var _pinionInterface as Pinion.AbstractInterface?;

    private var _deviceHandle as Pinion.DeviceHandle? = null;

    private var _pinionDataField as PinionDataField = new PinionDataField(self);

    private var _retryTimer as Timer.Timer or Pinion.DataFieldTimer = Pinion.createTimer();
    private var _batteryLevelTimer as Timer.Timer or Pinion.DataFieldTimer = Pinion.createTimer();

    private function pinionInterface() as Pinion.AbstractInterface
    {
        Debug.assert(_pinionInterface != null, "_pinionInterface not set");
        return _pinionInterface as Pinion.AbstractInterface;
    }

    public function initialize()
    {
        AppBase.initialize();
    }

    public function state() as State
    {
        return _state;
    }

    private function setState(state as State) as Void
    {
        if(_state == state)
        {
            return;
        }

        _state = state;
        onStateChanged();
    }

    private function onStateChanged() as Void
    {
        switch(_state)
        {
        case STARTING:      Debug.log("onStateChanged STARTING");   break;
        case SCANNING:      Debug.log("onStateChanged SCANNING");   break;
        case CONNECTING:    Debug.log("onStateChanged CONNECTING"); break;
        case CONNECTED:     Debug.log("onStateChanged CONNECTED");  break;
        case STOPPING:      Debug.log("onStateChanged STOPPING");   break;
        }
    }

    public function updateState() as Void
    {
        if(_deviceHandle == null)
        {
            setState(SCANNING);
        }
        else if(_state != CONNECTED)
        {
            setState(CONNECTING);
        }

        if(state != CONNECTED)
        {
            _pinionDataField.reset();
        }

        switch(_state)
        {
        case SCANNING:
            pinionInterface().startScan();
            break;

        case CONNECTING:
            pinionInterface().stopScan();

            if(_deviceHandle == null)
            {
                Debug.error("In CONNECTING state with no device handle");
            }

            var connectResult = pinionInterface().connect(_deviceHandle as Pinion.DeviceHandle);
            if(!connectResult)
            {
                // If the connection failed, call updateState again in the near future
                _retryTimer.start(method(:updateState), RECONNECTION_DELAY, false);
            }

            break;

        default:
        case STARTING:
        case CONNECTED:
        case STOPPING:
            // NO-OP
            break;
        }
    }

    public function onStart(state as Lang.Dictionary?) as Void
    {
        Debug.log("----- Application Start -----");

        restore();
        _pinionInterface = Pinion.createInterface();

        if(_pinionInterface instanceof Pinion.Interface && _deviceHandle != null && _deviceHandle.scanResult() == null)
        {
            // On a real device, the scanResult should never be null, forget it
            unstore();
        }

        pinionInterface().setDelegate(self);
        updateState();
    }

    private function onDisconnectOrStop() as Void
    {
        _batteryLevelTimer.stop();
        _pinionDataField.reset();
    }

    public function onStop(state as Lang.Dictionary?) as Void
    {
        if(_state == STOPPING)
        {
            // There is a Connect IQ bug where onStop seems to get called twice, hence this guard
            return;
        }

        setState(STOPPING);
        onDisconnectOrStop();
        pinionInterface().disconnect();
        store();

        Debug.log("----- Application Stop -----");
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates]
    {
        return [_pinionDataField];
    }

    public function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null
    {
        var settingsView = new SettingsView(self);
        var settingsViewInputDelegate = new SettingsViewInputDelegate(settingsView);

        return [settingsView, settingsViewInputDelegate];
    }

    public function _readBatteryLevel() as Void
    {
        readParameter(Pinion.BATTERY_LEVEL);
    }

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        Debug.log("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        Debug.log("PinionDelegate.onConnected");

        setState(CONNECTED);
        readParameter(Pinion.CURRENT_GEAR);
        readParameter(Pinion.BATTERY_LEVEL);
        _batteryLevelTimer.start(method(:_readBatteryLevel), 60000, true);
    }

    public function _attemptReconnection() as Void
    {
        setState(CONNECTING);
        updateState();
    }

    public function onDisconnected() as Void
    {
        Debug.log("PinionDelegate.onDisconnected");

        onDisconnectOrStop();

        if(_state != STOPPING)
        {
            _retryTimer.start(method(:_attemptReconnection), RECONNECTION_DELAY, false);
        }
    }

    public function onConnectionTimeout() as Void
    {
        Debug.log("PinionDelegate.onConnectionTimeout");

        _attemptReconnection();
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        var maxRssi = -1000.0;
        var selectedIndex = -1;

        // Find strongest advertising device
        for(var i = 0; i < foundDevices.size(); i++)
        {
            var foundDevice = foundDevices[i];
            var rssi = foundDevice.rssi();

            if(rssi > maxRssi)
            {
                maxRssi = rssi;
                selectedIndex = i;
            }
        }

        if(selectedIndex >= 0)
        {
            selectDevice(foundDevices[selectedIndex]);
        }
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        Debug.log("onCurrentGearChanged(" + currentGear + ")");

        _pinionDataField.setCurrentGear(currentGear);
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        Debug.log("onParameterRead(" + Pinion.stringForParameter(parameter) + ", " + value + ")");

        switch(parameter)
        {
            case Pinion.CURRENT_GEAR:   _pinionDataField.setCurrentGear(value); break;
            case Pinion.BATTERY_LEVEL:  _pinionDataField.setBatteryLevel(value); break;
            default: break;
        }
    }

    public function onParameterWrite(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        Debug.log("onParameterWrite(" + Pinion.stringForParameter(parameter) + ", " + value + ")");
    }

    public function selectDevice(deviceHandle as Pinion.DeviceHandle) as Void
    {
        _deviceHandle = deviceHandle;
        updateState();
        store();
    }

    public function readParameter(parameter as Pinion.ParameterType) as Void
    {
        pinionInterface().read(parameter);
    }

    public function writeParameter(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        pinionInterface().write(parameter, value);
    }

    public function activityKey(key as Application.PropertyKeyType) as Application.PropertyKeyType
    {
        var profileName = Activity.getProfileInfo().name;
        return profileName + "." + key;
    }

    public function store() as Void
    {
        if(_deviceHandle != null)
        {
            var deviceHandle = _deviceHandle as Pinion.DeviceHandle;
            Storage.setValue(activityKey("deviceSerialNumber"), deviceHandle.serialNumber());
            Storage.setValue(activityKey("deviceScanResult"), deviceHandle.scanResult() as Ble.ScanResult);
        }
    }

    public function restore() as Void
    {
        var deviceSerialNumber = Storage.getValue(activityKey("deviceSerialNumber"));
        if(deviceSerialNumber != null)
        {
            var scanResult = Storage.getValue(activityKey("deviceScanResult"));
            _deviceHandle = new Pinion.DeviceHandle(deviceSerialNumber as Lang.Long, scanResult as Ble.ScanResult);
        }
    }

    public function unstore() as Void
    {
        Storage.deleteValue(activityKey("deviceSerialNumber"));
        Storage.deleteValue(activityKey("deviceScanResult"));
        _deviceHandle = null;
    }

    public function unpair() as Void
    {
        Debug.log("App.unpair");

        unstore();

        if(_state == CONNECTED)
        {
            onDisconnectOrStop();
            pinionInterface().disconnect();
        }

        updateState();
    }

    public function update() as Void
    {
        if(_pinionInterface != null)
        {
            _pinionInterface.update();
        }

        if(_retryTimer has :update)
        {
            _retryTimer.update();
        }

        if(_batteryLevelTimer has :update)
        {
            _batteryLevelTimer.update();
        }
    }
}