local M = {}

M.type = "auxilliary"
M.relevantDevice = nil
M.defaultOrder = 1100

local engineTempOff = false
local startedIdling = false
local idleStartedAt = 0
local disabled = false

local function init()
    --log("D", "idleStopStart", "init") --[Debug]
end

local function reset()
    engineTempOff = false
    startedIdling = false
    idleStartedAt = 0
    disabled = false
end

local function automatic_based_gearbox(engine, gearbox, speed, throttle_input, brake_input, parkingbrake, engine_running)
    -- Check if the vehicle is idling and is in the required gear
    if speed < 0.025 and throttle_input == 0 and brake_input > 0.2 and parkingbrake == 0 and gearbox.mode == "drive" then
        -- Start the 5 second idle countdown
        if startedIdling == false and engineTempOff == false then
            --log("D", "idleStopStart.automatic", "Started idling...") --[Debug]

            startedIdling = true
            idleStartedAt = os.time()

            return
        end

        -- Stop the engine after the 5 second idle countdown
        if startedIdling == true and engineTempOff == false and (os.time() - idleStartedAt) >= 5 then
            --log("D", "idleStopStart.automatic", "Idled for 5 seconds, stopping engine...") --[Debug]

            engine:activateStarter()
            gui.message({txt = "Engine stopped while idling. Apply throttle to restart engine.", context = {}}, 10, "vehicle.info")

            engineTempOff = true
            startedIdling = false
            idleStartedAt = 0

            return
        end
    end

    -- Checks to run if the throttle is pressed in
    if throttle_input > 0 then
        -- Stop the idle countdown if the throttle is pressed in during the 5 second period
        if startedIdling == true and (os.time() - idleStartedAt) < 5 then
            --log("D", "idleStopStart.automatic", "Stopped idling (throttle input detected)") --[Debug]

            startedIdling = false
            idleStartedAt = 0

            return

        -- Restart the engine if the throttle is pressed while it is temporarily stopped
        elseif engineTempOff == true then
            --log("D", "idleStopStart.automatic", "Restarting engine...") --[Debug]

            engine:activateStarter()
            gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

            engineTempOff = false

            return
        end
    end

    -- Cancel the idle countdown if the vehicle is shifted out of the required gear during idling
    if gearbox.mode ~= "drive" and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.automatic", "Stopped idling (shifted out of required gear)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the parking brake is applied
    if parkingbrake == 1 and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.automatic", "Stopped idling (parking brake applied)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the brake is removed
    if brake_input == 0 and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.automatic", "Stopped idling (brake removed)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Reset the engine temp off status if the engine is turned on for some reason (eg. manually turned on after being turned off due to idling)
    if engineTempOff == true and engine_running == 1 then
        --log("D", "idleStopStart.automatic", "Engine temp off status reset (engine was manually restarted)") --[Debug]

        engineTempOff = false

        return
    end
end

local function manual_based_gearbox(engine, gearbox, speed, throttle_input, brake_input, parkingbrake, engine_running)
    -- Check if the vehicle is idling and is in the required gear
    if speed < 0.025 and throttle_input == 0 and brake_input > 0.2 and parkingbrake == 0 and gearbox.gearIndex == 1 then
        -- Start the 5 second idle countdown
        if startedIdling == false and engineTempOff == false then
            --log("D", "idleStopStart.automatic", "Started idling...") --[Debug]

            startedIdling = true
            idleStartedAt = os.time()

            return
        end

        -- Stop the engine after the 5 second idle countdown
        if startedIdling == true and engineTempOff == false and (os.time() - idleStartedAt) >= 5 then
            --log("D", "idleStopStart.manual", "Idled for 5 seconds, stopping engine...") --[Debug]

            engine:activateStarter()
            gui.message({txt = "Engine stopped while idling. Apply throttle to restart engine.", context = {}}, 10, "vehicle.info")

            engineTempOff = true
            startedIdling = false
            idleStartedAt = 0

            return
        end
    end

    -- Checks to run if the throttle is pressed in
    if throttle_input > 0 then
        -- Stop the idle countdown if the throttle is pressed in during the 5 second period
        if startedIdling == true and (os.time() - idleStartedAt) < 5 then
            --log("D", "idleStopStart.manual", "Stopped idling (throttle input detected)") --[Debug]

            startedIdling = false
            idleStartedAt = 0

            return

        -- Restart the engine if the throttle is pressed while it is temporarily stopped
        elseif engineTempOff == true then
            --log("D", "idleStopStart.manual", "Restarting engine...") --[Debug]

            engine:activateStarter()
            gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

            engineTempOff = false

            return
        end
    end

    -- Cancel the idle countdown if the vehicle is shifted out of the required gear during idling
    if gearbox.gearIndex ~= 1 and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.manual", "Stopped idling (shifted out of required gear)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the parking brake is applied
    if parkingbrake == 1 and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.manual", "Stopped idling (parking brake applied)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the brake is removed
    if brake_input == 0 and startedIdling == true and (os.time() - idleStartedAt) < 5 then
        --log("D", "idleStopStart.manual", "Stopped idling (brake removed)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Reset the engine temp off status if the engine is turned on for some reason (eg. manually turned on after being turned off due to idling)
    if engineTempOff == true and engine_running == 1 then
        --log("D", "idleStopStart.manual", "Engine temp off status reset (engine was manually restarted)") --[Debug]

        engineTempOff = false

        return
    end
end

local gearbox_functions = {
    [1] = automatic_based_gearbox,
    [2] = manual_based_gearbox,
  }

local function updateGFX()
    if disabled == true then
        --log("D", "idleStopStart", "System is disabled") --[Debug]

        return
    end

    local engine = powertrain.getDevice("mainEngine") or nil
    local gearbox = powertrain.getDevice("gearbox") or nil

    local speed = electrics.values["airspeed"]
    local throttle_input = electrics.values["throttle_input"]
    local brake_input = electrics.values["brake_input"]
    local parkingbrake = electrics.values["parkingbrake"]
    local engine_running = electrics.values["engineRunning"]

    if engine == nil then
        gui.message({txt = "Idle Stop-Start could not find a main engine and cannot function; this usually happens with electric motors", context = {}}, 10, "vehicle.error")

        disabled = true
  
        return
    end
    
    if gearbox == nil then
        gui.message({txt = "Idle Stop-Start could not find a gearbox and cannot function", context = {}}, 10, "vehicle.error")

        disabled = true
  
        return
    end

    if engine.type ~= "combustionEngine" then
        gui.message({txt = "Idle Stop-Start only works with combustion engines", context = {}}, 10, "vehicle.error")

        disabled = true

        return
    end

    local func

    if gearbox.type == "automaticGearbox" then func = gearbox_functions[1] end
    if gearbox.type == "dctGearbox" then func = gearbox_functions[1] end
    if gearbox.type == "cvtGearbox" then func = gearbox_functions[1] end
    if gearbox.type == "manualGearbox" then func = gearbox_functions[2] end
    if gearbox.type == "sequentialGearbox" then func = gearbox_functions[2] end

    if func then
        func(engine, gearbox, speed, throttle_input, brake_input, parkingbrake, engine_running)
    else
        --log("D", "idleStopStart", "No appropriate gearbox function found") --[Debug]
    end
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX

return M