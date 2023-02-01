-- config ui for autofish

local gui = require("gui")
local widgets = require("gui.widgets")
local script = reqscript("autofish")

local REFRESH_MS = 10000

---
-- Autofish
---
Autofish = defclass(Autofish, widgets.Window)
Autofish.ATTRS = {
    frame_title = "Autofish",
    frame = {w=45, h=12},
    resizable = false
}

function Autofish:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id="enable_toggle",
            frame={t=0, l=0, w=31},
            label="Autofish is",
            key="CUSTOM_CTRL_E",
            options={{value=true, label="Enabled", pen=COLOR_GREEN},
                     {value=false, label="Disabled", pen=COLOR_RED}},
            on_change=function(val) script.setEnabled(val) end
        },
        widgets.EditField{
            view_id="minimum",
            frame={t=2,l=0},
            label_text="minimum fish target: ",
            key="CUSTOM_M",
            on_char=function(ch) return ch:match("%d") end,
            on_submit=function(text)
                script.set_minFish = tonumber(text)
                self:refresh_data()
            end
        },
        widgets.EditField{
            view_id="maximum",
            frame={t=3,l=0},
            label_text="Maximum fish target: ",
            key="CUSTOM_SHIFT_M",
            on_char=function(ch) return ch:match("%d") end,
            on_submit=function(text)
                script.set_maxFish = tonumber(text)
                self:refresh_data()
            end
        },
        widgets.ToggleHotkeyLabel{
            view_id="useRawFish",
            frame={t=5, l=0, w=31},
            label="Counting raw fish:",
            key="CUSTOM_ALT_R",
            options={{value=true, label="Yes", pen=COLOR_GREEN},
                     {value=false, label="No", pen=COLOR_RED}},
            on_change=function(val) script.set_useRaw = val end
        },
        widgets.Label{
            view_id="current_mode",
            frame={t=7, l=0, h=1},
            auto_height=false,
            --visible=false
        }
    }
    self:refresh_data()
end

function Autofish:refresh_data()
    self.subviews.enable_toggle:setOption(script.isEnabled())

    self.subviews.minimum:setText(tostring(script.set_minFish))
    self.subviews.maximum:setText(tostring(script.set_maxFish))
    self.subviews.useRawFish:setOption(script.set_useRaw)

    self.subviews.current_mode.visible=script.isEnabled()
    if script.isFishing then
        self.subviews.current_mode:setText(string.format("Autofish has %s fishing.", (script.isFishing and "enabled" or "disabled")))
    end

    self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS
end

function Autofish:onRenderBody()
    if self.next_refresh_ms <= dfhack.getTickCount() then
        self:refresh_data()
    end
end


---
-- AutofishScreen
---
AutofishScreen = defclass(AutofishScreen, gui.ZScreen)
AutofishScreen.ATTRS = {focus_path = "autofish"}

function AutofishScreen:init()
    self:addviews{Autofish{}}
end

function AutofishScreen:onDismiss()
    view = nil
end
if not dfhack.isMapLoaded then
    qerror("autofish requires a map to be loaded")
end

view = view and view:raise() or AutofishScreen{}:show()
