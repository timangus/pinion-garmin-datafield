using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class Rect
{
    public var x as Lang.Float = 0.0;
    public var y as Lang.Float = 0.0;
    public var w as Lang.Float = 0.0;
    public var h as Lang.Float = 0.0;

    public function initialize(_x as Lang.Float, _y as Lang.Float,
        _w as Lang.Float, _h as Lang.Float)
    {
        x = _x;
        y = _y;
        w = _w;
        h = _h;
    }

    public function centreX() as Lang.Float { return x + (w * 0.5); }
    public function centreY() as Lang.Float { return y + (h * 0.5); }

    public function _scaled(xf as Lang.Float, yf as Lang.Float) as Rect
    {
        var sx = centreX() - (w * xf * 0.5);
        var sy = centreY() - (h * yf * 0.5);
        var sw = w * xf;
        var sh = h * yf;

        return new Rect(sx, sy, sw, sh);
    }

    public function scaled(f as Lang.Float) as Rect
    {
        return _scaled(f, f);
    }

    public function scaledToAspectRatio(ar as Lang.Float) as Rect
    {
        var currentAspectRatio = w / h;

        if(currentAspectRatio >= ar)
        {
            return _scaled(ar * h / w, 1.0);
        }
        else
        {
            return _scaled(1.0, w / (ar * h));
        }
    }
}

class PinionDataField extends WatchUi.DataField
{
    private const DEBUG_RECTANGLES = false;
    private const LABEL_HEIGHT_FRACTION = 0.30;
    private const DIVIDER_LENGTH = 0.75;
    private const DIVIDER_WIDTH = 0.02;

    private const MIN_NUMBER_FONT = Graphics.FONT_NUMBER_MILD;
    private const MAX_NUMBER_FONT = Graphics.FONT_NUMBER_THAI_HOT;
    private const MIN_TEXT_FONT = Graphics.FONT_XTINY;
    private const MAX_TEXT_FONT = Graphics.FONT_NUMBER_MEDIUM;

    private var _app as App;

    private var _label as Lang.String = "";

    private var _showGear as Lang.Boolean = true;
    private var _showBattery as Lang.Boolean = true;

    private var _currentGear as Lang.Number = 0;
    private var _batteryLevel as Lang.Number = 0;

    private var _labelFont as Graphics.FontType = Graphics.FONT_SMALL;

    public function initialize(app as App)
    {
        DataField.initialize();

        _app = app;
    }

    public function compute(info as Activity.Info) as Void
    {
        _app.update();

        var showGearSetting = Application.Storage.getValue(_app.activityKey("showGear"));
        _showGear = showGearSetting != null ? showGearSetting as Lang.Boolean : true;

        var showBatterySetting = Application.Storage.getValue(_app.activityKey("showBattery"));
        _showBattery = showBatterySetting != null ? showBatterySetting as Lang.Boolean : false;
    }

    private function selectFont(dc as Graphics.Dc,
        minFont as Graphics.FontType, maxFont as Graphics.FontType,
        maxWidth as Lang.Numeric, maxHeight as Lang.Numeric,
        text as Lang.String) as Graphics.FontType
    {
        // Find the biggest font that fits the constraints
        for(var fontNumber = maxFont as Lang.Number; fontNumber >= minFont as Lang.Number; fontNumber--)
        {
            var font = fontNumber as Graphics.FontType;
            var width = dc.getTextWidthInPixels(text, font);
            var height = dc.getFontHeight(font);

            if(width <= maxWidth && height <= maxHeight)
            {
                return font;
            }
        }

        return minFont;
    }

    (:useNon_xx30Fonts) function useNon_xx30FontsSwitch() as Void { }

    function labelFont(dc as Graphics.Dc) as Graphics.FontType
    {
        if(self has :useNon_xx30FontsSwitch)
        {
            return selectFont(dc, Graphics.FONT_GLANCE, Graphics.FONT_GLANCE_NUMBER,
                0, (dc.getHeight() * LABEL_HEIGHT_FRACTION).toNumber(), "");
        }

        // Edge xx30 devices seem to just use a fixed size font at all scales
        return Graphics.FONT_SMALL;
    }

    public function onLayout(dc as Graphics.Dc) as Void
    {
        _label = Application.loadResource(Rez.Strings.DataFieldLabel) as Lang.String;
        _labelFont = labelFont(dc);
    }

    private function ltrbToScreen(ltrb as [Lang.Float, Lang.Float, Lang.Float, Lang.Float],
        w as Lang.Float, h as Lang.Float, vOffset as Lang.Float) as Rect
    {
        var left =      ltrb[0];
        var top =       ltrb[1];
        var right =     ltrb[2];
        var bottom =    ltrb[3];

        return new Rect(left * w, vOffset + (top * h), (right - left) * w, (bottom - top) * h);
    }

    private function drawDebugRectangle(dc as Graphics.Dc, rect as Rect, color as Graphics.ColorValue) as Void
    {
        if(!DEBUG_RECTANGLES)
        {
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2.0);
        dc.drawRectangle(rect.x + 1.0, rect.y + 1.0, rect.w - 2.0, rect.h - 2.0);
        dc.fillCircle(rect.centreX(), rect.centreY(), 2.0);
    }

    private function drawBattery(dc as Graphics.Dc,
        rect as Rect, color as Graphics.ColorValue) as Void
    {
        var infillColor = (color == Graphics.COLOR_BLACK) ?
            Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var lineWidth = rect.w * 0.04;
        var cornerRadius = lineWidth;
        var blockGap = lineWidth * 0.75;
        var terminalWidth = lineWidth;
        var terminalHeight = rect.h / 2.5;

        var bodyWidth = rect.w - terminalWidth;
        var levelFullWidth = bodyWidth - ((lineWidth + blockGap) * 2.0);
        var levelWidth = (bodyWidth - ((lineWidth + blockGap) * 2.0)) * (_batteryLevel / 10000.0);
        levelWidth = levelWidth > levelFullWidth ? levelFullWidth : levelWidth;
        var levelHeight = rect.h - ((lineWidth + blockGap) * 2.0);
        var levelColor =
            _batteryLevel < 1000 && (Time.now().value() % 2 == 0) ? infillColor :
            _batteryLevel < 2000 ? Graphics.COLOR_RED :
            _batteryLevel < 4000 ? Graphics.COLOR_ORANGE :
            Graphics.COLOR_DK_GREEN;

        // Outline
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rect.x, rect.y, bodyWidth, rect.h, cornerRadius);

        // Terminal
        dc.setPenWidth(lineWidth);
        dc.fillRoundedRectangle(rect.x, rect.y + ((rect.h - terminalHeight) * 0.5),
            rect.w, terminalHeight, cornerRadius * 0.5);

        // Infill
        dc.setColor(infillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(rect.x + lineWidth, rect.y + lineWidth,
            bodyWidth - (lineWidth * 2.0), rect.h - (lineWidth * 2.0));

        // Level
        dc.setColor(levelColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(rect.x + (lineWidth + blockGap), rect.y + (lineWidth + blockGap),
            levelWidth, levelHeight);

        // Gaps
        dc.setColor(infillColor, Graphics.COLOR_TRANSPARENT);

        var numGaps = 4;
        var start = rect.x + lineWidth;
        var stride = (levelFullWidth + blockGap) / (numGaps + 1);
        for(var i = 0; i < numGaps; i++)
        {
            var x = start + (stride * (i + 1));

            dc.fillRectangle(x, rect.y + lineWidth,
                blockGap, rect.h - (lineWidth * 2.0));
        }
    }

    private function drawConnecting(dc as Graphics.Dc,
        rect as Rect, color as Graphics.ColorValue) as Void
    {
        var angle = 90;
        var halfAngle = angle / 2;
        var minAngle = (450 - halfAngle) % 360;
        var maxAngle = (450 + halfAngle) % 360;

        var numArcs = 3;
        var radialLength = rect.h * ((numArcs + 0.5) / (numArcs + 1.0));

        var degreesToRadians = Math.PI / 180.0;
        var width = Math.cos((90 - halfAngle) * degreesToRadians) * radialLength * 2.0;
        var scale = rect.w / width;

        if(scale < 1.0)
        {
            // It's too wide to fit in the original rect, so scale it down
            rect = rect.scaled(scale as Lang.Float);
        }

        var top = rect.y;
        var bottom = rect.y + rect.h;
        var lineWidth = (bottom - top) / ((numArcs + 1) * 2);

        dc.setPenWidth(lineWidth);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        dc.fillCircle(rect.centreX(), bottom - lineWidth, lineWidth);

        for(var i = 0; i < numArcs; i++)
        {
            var offset = (lineWidth * 0.5) + ((i + 1) * (lineWidth * 2.0));

            dc.drawArc(rect.centreX(), bottom - lineWidth, offset,
                Graphics.ARC_COUNTER_CLOCKWISE, minAngle, maxAngle);
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void
    {
        var backgroundColor = getBackgroundColor();
        var foregroundColor = (backgroundColor == Graphics.COLOR_BLACK) ?
            Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var w = dc.getWidth() as Lang.Float;
        var h = dc.getHeight() as Lang.Float;
        var aspectRatio = w / h;

        var labelOffset = dc.getFontHeight(_labelFont) as Lang.Float;

        dc.setAntiAlias(true);

        dc.setColor(Graphics.COLOR_TRANSPARENT, backgroundColor);
        dc.clear();
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(w * 0.5, dc.getFontHeight(_labelFont) * 0.22,
            _labelFont, _label, Graphics.TEXT_JUSTIFY_CENTER);

        if(!hasData())
        {
            var connectingLocation = [0.0, 0.0, 1.0, 1.0];
            var c = ltrbToScreen(connectingLocation, w, h - labelOffset, labelOffset);

            drawConnecting(dc, c.scaledToAspectRatio(1.0).scaled(0.9), foregroundColor);
            drawDebugRectangle(dc, c, Graphics.COLOR_RED);
            return;
        }

        // Force battery display if it's at a very low level
        var showBattery = _showBattery || _batteryLevel <= 500;

        // The units here are left, top, right, bottom

        // These are the default values used when showing the gear xor the battery
        var gearLocation =          [0.0, 0.0, 1.0, 1.0];
        var dividerLocation =       [0.0, 0.0, 1.0, 1.0];
        var batteryTextLocation =   aspectRatio < 1.0 ? [0.0, 0.0, 1.0, 0.5] : [0.0, 0.0, 0.5, 1.0];
        var batteryIconLocation =   aspectRatio < 1.0 ? [0.0, 0.5, 1.0, 1.0] : [0.5, 0.0, 1.0, 1.0];

        if(_showGear && showBattery)
        {
            if(aspectRatio < 1.0)
            {
                // Vertical
                gearLocation =          [0.0,  0.0,  1.0,  0.4  ];
                dividerLocation =       [0.0,  0.38, 1.0,  0.42 ];
                batteryTextLocation =   [0.0,  0.4,  1.0,  0.65 ];
                batteryIconLocation =   [0.0,  0.65, 1.0,  1.0  ];
            }
            else if(aspectRatio < 2.0)
            {
                // Horizontal
                gearLocation =          [0.0,  0.0,  0.5,  1.0  ];
                dividerLocation =       [0.48, 0.0,  0.52, 1.0  ];
                batteryTextLocation =   [0.5,  0.05, 1.0,  0.5  ];
                batteryIconLocation =   [0.5,  0.5,  1.0,  0.95 ];
            }
            else
            {
                // Wide, horizontal
                gearLocation =         [0.0,  0.0,  0.33, 1.0  ];
                dividerLocation =      [0.31, 0.0,  0.35, 1.0  ];
                batteryTextLocation =  [0.33, 0.0,  0.64, 1.0  ];
                batteryIconLocation =  [0.64, 0.0,  1.0,  1.0  ];
            }
        }

        var g = ltrbToScreen(gearLocation,         w, h - labelOffset, labelOffset);
        var d = ltrbToScreen(dividerLocation,      w, h - labelOffset, labelOffset);
        var t = ltrbToScreen(batteryTextLocation,  w, h - labelOffset, labelOffset);
        var i = ltrbToScreen(batteryIconLocation,  w, h - labelOffset, labelOffset);

        if(_showGear)
        {
            var gearText = _currentGear.toString();
            var font = selectFont(dc, MIN_NUMBER_FONT, MAX_NUMBER_FONT, g.w, g.h, gearText);
            var textY = g.centreY() - (Graphics.getFontHeight(font) * 0.5);
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(g.centreX(), textY, font, gearText, Graphics.TEXT_JUSTIFY_CENTER);
            drawDebugRectangle(dc, g, Graphics.COLOR_RED);
        }

        if(_showGear && showBattery)
        {
            // Divider
            var dividerColor = (backgroundColor == Graphics.COLOR_BLACK) ?
                Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;

            dc.setColor(dividerColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(h * DIVIDER_WIDTH);

            if(d.h > d.w)
            {
                // Vertical
                var halfLength = d.h * DIVIDER_LENGTH * 0.5;
                dc.drawLine(d.centreX(), d.centreY() - halfLength, d.centreX(), d.centreY() + halfLength);
            }
            else
            {
                // Horizontal
                var halfLength = d.w * DIVIDER_LENGTH * 0.5;
                dc.drawLine(d.centreX() - halfLength, d.centreY(), d.centreX() + halfLength, d.centreY());
            }

            drawDebugRectangle(dc, d, Graphics.COLOR_PINK);
        }

        if(showBattery)
        {
            var batteryText = (_batteryLevel / 100.0).format("%.0f") + "%";
            var font = selectFont(dc, MIN_TEXT_FONT, MAX_TEXT_FONT, t.w, t.h, batteryText);
            var textY = t.centreY() - (Graphics.getFontHeight(font) * 0.5);
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(t.centreX(), textY, font, batteryText, Graphics.TEXT_JUSTIFY_CENTER);
            drawDebugRectangle(dc, t, Graphics.COLOR_GREEN);

            drawBattery(dc, i.scaledToAspectRatio(2.5).scaled(0.8), foregroundColor);
            drawDebugRectangle(dc, i, Graphics.COLOR_PURPLE);
        }
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

    public function hasData() as Lang.Boolean
    {
        return _currentGear != 0 && _batteryLevel != 0;
    }
}