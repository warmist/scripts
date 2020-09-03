--[[ 

Multiplies the speed of calendar time by the specified value.  The parameter can be any positive number, though going over 10 is likely to cause bugs.  1 is normal speed.

The below is experimental.

Values below 1 will cause the calendar to run at dynamic speeds such that it progresses at the same speed it would were the game being played at a constant frame rate. Example:

timestream -1 100     <-  Will cause the calendar to run as though the game was being played at 100 FPS.
timestream -1 100 1   <-  Will cause both calendar and creatures to behave as though the game was being played at 100 FPS, very crudely.

--]]

args={...}
local rate=tonumber(args[1])
local desired_fps = tonumber(args[2])
local simulating_units = tonumber(args[3])
local debug_mode = tonumber(args[4])

turbo_on = false -- Used to differentiate between external and internal debug_turbospeed
local prev_tick = 0
local ticks_left = 0
local simulating_desired_fps = false
local minimal_fps = 10 -- This ensures you won't get crazy values on pausing/saving.
local prev_frames = df.global.world.frame_counter
local frame_sum = 0
local avg_fps = desired_fps
local last_frame_sped_up = 0
local splicing_threshold = 0.25 -- This controls how generously the script decides to speed up units. Higher values mean that units will be sped up more often than not.

if turbo_on then
    df.global.debug_turbospeed = false
    turbo_on = false
end

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

if simulating_units == 1 then
    simulating_units = true
else
    simulating_units = false
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
                prev_time = df.global.enabler.clock
                simulating_desired_fps = true
                prev_frames = df.global.world.frame_counter
                rate = 1
                if simulating_units then
                    print("Unit simulation is on.")
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
            local counted_frames = df.global.world.frame_counter - prev_frames
            frame_sum = frame_sum + df.global.enabler.calculated_fps
            if counted_frames >= desired_fps then
                avg_fps = frame_sum/counted_frames
                if avg_fps <= desired_fps then
                    rate = desired_fps/avg_fps  -- We don't want to slow down the game
                end
                if debug_mode then
                    print("prev_frame: "..prev_frames..", avg_fps: " ..avg_fps.. ", rate: "..rate)
                end
                prev_frames = df.global.world.frame_counter
                frame_sum = 0
            end
            if simulating_units and avg_fps > 0 and avg_fps <= desired_fps then  -- God forbid avg_fps is not positive...
                local missing_frames = desired_fps - avg_fps
                local speedy_frame_delta = desired_fps/missing_frames
                local speedy_frame = counted_frames/speedy_frame_delta
                if speedy_frame - math.floor(speedy_frame) <= splicing_threshold and last_frame_sped_up ~= df.global.world.frame_counter then
                    if debug_mode then
                        print("avg_fps: ".. avg_fps .. ", speedy_frame_delta: "..speedy_frame_delta..", speedy_frame: "..counted_frames.."/"..desired_fps)
                    end
                    df.global.debug_turbospeed = true
                    turbo_on = true
                    last_frame_sped_up = df.global.world.frame_counter
                else 
                    df.global.debug_turbospeed = false
                    turbo_on = false
                end
            end
        end
        dfhack.timeout(1,"ticks",function() update() end)
	end
end

--Initial call

if dfhack.isMapLoaded() then 
	dfhack.onStateChange.loadTimestream(SC_MAP_LOADED)
end
