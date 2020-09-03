-- Multiplies the speed of calendar time by the specified value.  The parameter can be any positive number, though going over 10 is likely to cause bugs.  1 is normal speed.

args={...}
local rate=tonumber(args[1])
local desired_fps = tonumber(args[2])
local debug_mode = tonumber(args[3])

local prev_tick = 0
local ticks_left = 0
local simulating_desired_fps = false
local prev_frames = df.global.world.frame_counter
local prev_time = df.global.enabler.clock

if rate == nil then
	rate = 1
elseif rate < 0 then
	rate = 0
end
if desired_fps == nil or desired_fps <= 0 then
    desired_fps = 100
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
            if rate > 0 then
                print('Time running at x'..rate..".")
            else
                print('Time running dynamically to simulate '..desired_fps..' FPS.')
                prev_time = df.global.enabler.clock
                simulating_desired_fps = true
                prev_frames = df.global.world.frame_counter
                rate = 1
            end
            if debug_mode then
                print("Debug mode is on.")
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
		end
	elseif code==SC_MAP_UNLOADED then
	end
end

function update()
	prev_tick = df.global.cur_year_tick
	if rate ~= 1 or simulating_desired_fps then
		timestream = 0
		
		if rate < 1 then
			if df.global.cur_year_tick - math.floor(df.global.cur_year_tick/10)*10 == 5 then
				if counter > 1 then
					counter = counter - 1
					timestream = -1
				else
					counter = counter + math.floor(ticks_left)
				end
			end
		else
			--counter = counter + rate-1
            counter = counter + math.floor(ticks_left)
			while counter >= 10 do
				counter = counter - 10
				timestream = timestream + 1
			end
		end
        ticks_left = ticks_left - math.floor(ticks_left)
		
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
        ticks_left = ticks_left + rate
        if simulating_desired_fps then
            if df.global.world.frame_counter - prev_frames >= desired_fps then
                local current_time = df.global.enabler.clock
                local current_fps = (desired_fps/(current_time - prev_time))*1000
                rate = desired_fps/current_fps
                print("current_time: "..current_time..", prev_frames: "..prev_frames..", current_fps: " ..current_fps.. ", current_time - prev_time: "..(current_time - prev_time).. ", rate: "..rate)
                prev_time = current_time
                prev_frames = df.global.world.frame_counter
            end
        end
        dfhack.timeout(1,"ticks",function() update() end)
	end
end

--Initial call

if dfhack.isMapLoaded() then 
	dfhack.onStateChange.loadTimestream(SC_MAP_LOADED)
end