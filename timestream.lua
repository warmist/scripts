-- speeds up the calendar, units, or both

--[====[

timestream
==========
This is only for fortress mode.

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

local minimal_fps = 10 -- This ensures you won't get crazy values on pausing/saving, or other artefacts on extremely low FPS.
local splicing_threshold = 0.25 -- This controls how generously the script decides to speed up units. Higher values mean that units will be sped up more often than not. This is only for when using debug_turbospeed.

local current_fps = desired_fps
local prev_tick = 0
local ticks_left = 0
local simulating_desired_fps = false
local prev_frames = df.global.world.frame_counter
local last_frame = df.global.world.frame_counter
local prev_time = df.global.enabler.clock

if rate == nil then
    rate = 1
elseif rate < 0 then
    rate = 0
end

if desired_fps == nil or desired_fps <= 0 then
    desired_fps = 100
    current_fps = desired_fps
end

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
            last_frame = df.global.world.frame_counter - 1
            --if rate > 0 then            -- Won't behave well with unit simulation
            if rate > 1 then
                print('Time running at x'..rate..".")
            else
                print('Time running dynamically to simulate '..desired_fps..' FPS.')
                simulating_desired_fps = true
                prev_frames = df.global.world.frame_counter
                prev_time = df.global.enabler.clock
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
                dfhack.timeout(1,"frames",function() update() end)
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
        if last_frame + 1 == df.global.world.frame_counter then
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
                if counted_frames >= desired_fps then
                    current_fps = 1000 * desired_fps / (df.global.enabler.clock - prev_time)
                    if current_fps < desired_fps then
                        rate = desired_fps/current_fps
                    else
                        rate = 1     -- We don't want to slow down the game
                    end
                    prev_frames = df.global.world.frame_counter
                    prev_time = df.global.enabler.clock
                    if current_fps < minimal_fps then
                        current_fps = minimal_fps
                    end
                    if debug_mode then
                        print("prev_frames: " .. prev_frames .. ", current_fps: ".. current_fps)
                    end
                end

                if simulating_units == 2 then
                    local missing_frames = desired_fps - current_fps
                    local speedy_frame_delta = desired_fps/missing_frames
                    local speedy_frame = counted_frames/speedy_frame_delta
                    if speedy_frame - math.floor(speedy_frame) <= splicing_threshold and last_frame_sped_up ~= df.global.world.frame_counter then
                        if debug_mode then
                            print("speedy_frame_delta: "..speedy_frame_delta..", speedy_frame: "..counted_frames.."/"..desired_fps)
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
                                    local d = action.data.move.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.move.timer = d
                                    
                                elseif action.type == df.unit_action_type.Attack then
                                    local d = action.data.attack.timer1 - dec
                                    if d <= 1 then
                                        d = 1
                                        action.data.attack.timer2 = 1   -- I don't know why, but if I don't add this line then there's a bug where people just dogpile each other and don't fight.
                                    end
                                    d = action.data.attack.timer2 - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.attack.timer2 = d
                                elseif action.type == df.unit_action_type.HoldTerrain then
                                    local d = action.data.holdterrain.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.holdterrain.timer = d
                                elseif action.type == df.unit_action_type.Climb then
                                    local d = action.data.climb.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.climb.timer = d
                                elseif action.type == df.unit_action_type.Job then
                                    local d = action.data.job.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.job.timer = d
                                elseif action.type == df.unit_action_type.Talk then
                                    local d = action.data.talk.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.talk.timer = d
                                elseif action.type == df.unit_action_type.Unsteady then
                                    local d = action.data.unsteady.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.unsteady.timer = d
                                elseif action.type == df.unit_action_type.StandUp then
                                    local d = action.data.standup.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.standup.timer = d
                                elseif action.type == df.unit_action_type.LieDown then
                                    local d = action.data.liedown.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.liedown.timer = d
                                elseif action.type == df.unit_action_type.Job2 then
                                    local d = action.data.job2.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.job2.timer = d
                                elseif action.type == df.unit_action_type.PushObject then
                                    local d = action.data.pushobject.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.pushobject.timer = d
                                elseif action.type == df.unit_action_type.SuckBlood then
                                    local d = action.data.suckblood.timer - dec
                                    if d < 1 then
                                        d = 1
                                    end
                                    action.data.suckblood.timer = d
                                end
                            end
                        end
                    end
                end
            end
            ticks_left = ticks_left - math.floor(ticks_left) + rate
            last_frame = df.global.world.frame_counter
        else
            if debug_mode then
                print("last_frame("..last_frame..") + 1 != df.global.world.frame_counter("..df.global.world.frame_counter.."), resetting fps count")
            end
            prev_time = df.global.enabler.clock
            prev_frames = df.global.world.frame_counter
        end
        dfhack.timeout(1,"frames",function() update() end)
    end
end

--Initial call

if dfhack.isMapLoaded() then
    dfhack.onStateChange.loadTimestream(SC_MAP_LOADED)
end