-- speeds up the calendar, units, or both

--[====[

timestream
==========
Usage:
:timestream <scalar> <fps> <simulate units y/n>
Examples:

:timestream     2:          Calendar runs at x2 normal speed
:timestream    -1 100:      Calendar runs at dynamic speed to simulate 100 FPS
:timestream    -1 100 1:    Calendar & units are simulated at 100 FPS

]====]

args={...}
local rate=tonumber(args[1])
local desired_fps = tonumber(args[2])
local simulating_units = tonumber(args[3])  -- Setting this to 2 instead of 1 will use debug_turbospeed instead of adjusting the timers of all creatures. I don't quite like it because it makes everyone move like insects.
local debug_mode = tonumber(args[4])

local fps_samples = 10   -- Controls how many frames (fps_samples * desired_fps) inside each frame sum that are used to calculate avg_fps.
local minimal_fps = 10 -- This ensures you won't get crazy values on pausing/saving, or other artefacts on extremely low FPS.
local splicing_threshold = 0.25 -- This controls how generously the script decides to speed up units. Higher values mean that units will be sped up more often than not. This is only for when using debug_turbospeed.

local sample_counter = 0
local prev_tick = 0
local ticks_left = 0
local simulating_desired_fps = false
local prev_frames = df.global.world.frame_counter
local frame_sum = 0
local last_frame_sum = desired_fps * desired_fps * fps_samples
local avg_fps = desired_fps
local last_frame_sped_up = 0

if rate == nil then
    rate = 1
elseif rate < 0 then
    rate = 0
end

if desired_fps == nil or desired_fps <= 0 then
    desired_fps = 100
end
avg_fps = desired_fps

if debug_mode == nil or debug_mode ~= 1 then
    debug_mode = false
else
    debug_mode = true
end

eventNow = false
seasonNow = false
timestream = 0
counter = 0
if df.global.cur_season_tick < 3360 then
    month = 1
elseif df.global.cur_season_tick < 6720 then
    month = 2
else
    month = 3
end

dfhack.onStateChange.loadTimestream = function(code)
    if code==SC_MAP_LOADED then
        simulating_desired_fps = false
        if rate ~= 1 then
            --if rate > 0 then            -- Won't behave well with unit simulation
            if rate > 1 then
                print('Time running at x'..rate..".")
            else
                print('Time running dynamically to simulate '..desired_fps..' FPS.')
                simulating_desired_fps = true
                prev_frames = df.global.world.frame_counter
                rate = 1
                if simulating_units == 1 or simulating_units == 2 then
                    print("Unit simulation is on.")
                    if simulating_units ~= 2 then
                        df.global.debug_turbospeed = false
                    end
                end
            end
            ticks_left = rate - 1

            eventNow = false
            seasonNow = false
            timestream = 0
            if df.global.cur_season_tick < 3360 then
                month = 1
            elseif df.global.cur_season_tick < 6720 then
                month = 2
            else
                month = 3
            end
            if loaded ~= true then
                dfhack.timeout(1,"ticks",function() update() end)
                loaded = true
            end
        else
            print('Time set to normal speed.')
            loaded = false
            df.global.debug_turbospeed = false
        end
            if debug_mode then
            print("Debug mode is on.")
        end
    elseif code==SC_MAP_UNLOADED then
    end
end

function update()
    prev_tick = df.global.cur_year_tick
    if rate ~= 1 or simulating_desired_fps then
        timestream = 0

        --[[if rate < 1 then
            if df.global.cur_year_tick - math.floor(df.global.cur_year_tick/10)*10 == 5 then
                if counter > 1 then
                    counter = counter - 1
                    timestream = -1
                else
                    counter = counter + math.floor(ticks_left)
                end
            end
        else
        --]]
        --counter = counter + rate-1
        counter = counter + math.floor(ticks_left)
        while counter >= 10 do
            counter = counter - 10
            timestream = timestream + 1
        end
        --end
        eventFound = false
        for i=0,#df.global.timed_events-1,1 do
            event=df.global.timed_events[i]
            if event.season == df.global.cur_season and event.season_ticks <= df.global.cur_season_tick then
                if eventNow == false then
                    --df.global.cur_season_tick=event.season_ticks
                    event.season_ticks = df.global.cur_season_tick
                    eventNow = true
                end
                eventFound = true
            end
        end
        if eventFound == false then eventNow = false end

        if df.global.cur_season_tick >= 3359 and df.global.cur_season_tick < 6719 and month == 1 then
            seasonNow = true
            month = 2
            if df.global.cur_season_tick > 3359 then
                df.global.cur_season_tick = 3360
            end
        elseif df.global.cur_season_tick >= 6719 and df.global.cur_season_tick < 10079 and month == 2 then
            seasonNow = true
            month = 3
            if df.global.cur_season_tick > 6719 then
                df.global.cur_season_tick = 6720
            end
        elseif df.global.cur_season_tick >= 10079 then
            seasonNow = true
            month = 1
            if df.global.cur_season_tick > 10080 then
                df.global.cur_season_tick = 10079
            end
        else
            seasonNow = false
        end

        if df.global.cur_year > 0 then
            if timestream ~= 0 then
                if df.global.cur_season_tick < 0 then
                    df.global.cur_season_tick = df.global.cur_season_tick + 10080
                    df.global.cur_season = df.global.cur_season-1
                    eventNow = true
                end
                if df.global.cur_season < 0 then
                    df.global.cur_season = df.global.cur_season + 4
                    df.global.cur_year_tick = df.global.cur_year_tick + 403200
                    df.global.cur_year = df.global.cur_year - 1
                    eventNow = true
                end
                if (eventNow == false and seasonNow == false) or timestream < 0 then
                    if timestream > 0 then
                        df.global.cur_season_tick=df.global.cur_season_tick + timestream
                        remainder = df.global.cur_year_tick - math.floor(df.global.cur_year_tick/10)*10
                        df.global.cur_year_tick=(df.global.cur_season_tick*10)+((df.global.cur_season)*100800) + remainder
                    elseif timestream < 0 then
                        df.global.cur_season_tick=df.global.cur_season_tick
                        df.global.cur_year_tick=(df.global.cur_season_tick*10)+((df.global.cur_season)*100800)
                    end
                end
            end
        end

        if simulating_desired_fps then
            local counted_frames = df.global.world.frame_counter - prev_frames
            frame_sum = frame_sum + df.global.enabler.calculated_fps
            if counted_frames >= desired_fps then
                avg_fps = (frame_sum + last_frame_sum)/(counted_frames + desired_fps * (sample_counter + fps_samples))
                if avg_fps <= desired_fps then
                    rate = desired_fps/avg_fps  -- We don't want to slow down the game
                else
                    rate = 1
                end
                if debug_mode then
                    print("prev_frame: "..prev_frames..", avg_fps: " ..avg_fps.. ", rate: "..rate)
                end
                prev_frames = df.global.world.frame_counter
                sample_counter = sample_counter + 1
                if sample_counter >= fps_samples - 1 then
                    last_frame_sum = frame_sum
                    frame_sum = 0
                    sample_counter = 0
                end
            end
            if avg_fps > 0 then -- God forbid avg_fps is not positive...
                if simulating_units == 2 then
                    local missing_frames = desired_fps - avg_fps
                    local speedy_frame_delta = desired_fps/missing_frames
                    local speedy_frame = counted_frames/speedy_frame_delta
                    if speedy_frame - math.floor(speedy_frame) <= splicing_threshold and last_frame_sped_up ~= df.global.world.frame_counter then
                        if debug_mode then
                            print("avg_fps: ".. avg_fps .. ", speedy_frame_delta: "..speedy_frame_delta..", speedy_frame: "..counted_frames.."/"..desired_fps)
                        end
                        df.global.debug_turbospeed = true
                        last_frame_sped_up = df.global.world.frame_counter
                    else
                        df.global.debug_turbospeed = false
                    end
                elseif simulating_units == 1 then
                    local dec = math.floor(ticks_left) - 1
                    for k1, unit in pairs(df.global.world.units.active) do
                        if dfhack.units.isActive(unit) then
                            for k2, action in pairs(unit.actions) do
                                if action.type == df.unit_action_type.Move then
                                    action.data.move.timer = action.data.move.timer - dec
                                elseif action.type == df.unit_action_type.Attack then
                                    action.data.attack.timer1 = action.data.attack.timer1 - dec
                                    action.data.attack.timer2 = action.data.attack.timer2 - dec
                                elseif action.type == df.unit_action_type.HoldTerrain then
                                    action.data.holdterrain.timer = action.data.holdterrain.timer - dec
                                elseif action.type == df.unit_action_type.Climb then
                                    action.data.climb.timer = action.data.climb.timer - dec
                                elseif action.type == df.unit_action_type.Job then
                                    action.data.job.timer = action.data.job.timer - dec
                                elseif action.type == df.unit_action_type.Talk then
                                    action.data.talk.timer = action.data.talk.timer - dec
                                elseif action.type == df.unit_action_type.Unsteady then
                                    action.data.unsteady.timer = action.data.unsteady.timer - dec
                                elseif action.type == df.unit_action_type.Dodge then
                                    action.data.dodge.timer = action.data.doge.timer - dec
                                elseif action.type == df.unit_action_type.StandUp then
                                    action.data.standup.timer = action.data.standup.timer - dec
                                elseif action.type == df.unit_action_type.LieDown then
                                    action.data.liedown.timer = action.data.liedown.timer - dec
                                elseif action.type == df.unit_action_type.Job2 then
                                    action.data.liedown.timer = action.data.liedown.timer - dec
                                elseif action.type == df.unit_action_type.PushObject then
                                    action.data.pushobject.timer = action.data.pushobject.timer - dec
                                elseif action.type == df.unit_action_type.SuckBlood then
                                    action.data.suckblood.timer = action.data.suckblood.timer - dec
                                end
                            end
                        end
                    end
                end
            end
        end
        ticks_left = ticks_left - math.floor(ticks_left) + rate
        dfhack.timeout(1,"ticks",function() update() end)
    end
end

--Initial call

if dfhack.isMapLoaded() then
    dfhack.onStateChange.loadTimestream(SC_MAP_LOADED)
end