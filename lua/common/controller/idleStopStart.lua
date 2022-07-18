local M = {}

M.type = "auxilliary"
M.relevantDevice = nil
M.defaultOrder = 1000

local disabled = false
local engineTempOff = false
local startedIdling = false
local idleStartedAt = 0
local idleTimeRequired = nil
local initialEngineStarterTorque
local initialEngineStarterMaxAV
local initialEngineStarterTime
local initialEngineStartCoef

local function init(jbeamData)
    --log("D", "idleStopStart", "init") --[Debug]

    idleTimeRequired = jbeamData.ISS_requiredIdleTime
end

local function reset()
    engineTempOff = false
    startedIdling = false
    idleStartedAt = 0
    disabled = false
end

-- Stop the engine
local function stop_engine(engine)
    initialEngineStarterTorque = engine.starterTorque
    initialEngineStarterMaxAV = engine.starterMaxAV
    initialEngineStarterTime = engine.starterThrottleKillTime
    initialEngineStartCoef = engine.idleStartCoef

    engine.starterTorque = (initialEngineStarterTorque * 2) or engine.starterTorque
    engine.starterMaxAV = (engine.idleAV * 0.5) or engine.starterMaxAV
    engine.starterThrottleKillTime = (initialEngineStarterTime / 2) or engine.starterThrottleKillTime
    engine.idleStartCoef = 0.85 or engine.idleStartCoef

    engine:activateStarter()

    engineTempOff = true

    engine.starterTorque = initialEngineStarterTorque
    engine.starterMaxAV = initialEngineStarterMaxAV
    engine.starterThrottleKillTime = initialEngineStarterTime
    engine.idleStartCoef = initialEngineStartCoef
end

-- Restart the engine
local function start_engine(engine)
    engine.starterTorque = (initialEngineStarterTorque * 2) or engine.starterTorque
    engine.starterMaxAV = (engine.idleAV * 0.5) or engine.starterMaxAV
    engine.starterThrottleKillTime = (initialEngineStarterTime / 2) or engine.starterThrottleKillTime
    engine.idleStartCoef = 0.85 or engine.idleStartCoef

    engine:activateStarter()

    engineTempOff = false

    engine.starterTorque = initialEngineStarterTorque
    engine.starterMaxAV = initialEngineStarterMaxAV
    engine.starterThrottleKillTime = initialEngineStarterTime
    engine.idleStartCoef = initialEngineStartCoef

    initialEngineStarterTorque = nil
    initialEngineStarterMaxAV = nil
    initialEngineStarterTime = nil
    initialEngineStartCoef = nil
end

local function automatic_based_gearbox(engine, gearbox, speed, throttle_input, brake_input, clutch_input, parkingbrake, engine_running)
    -- Check if the vehicle is idling and is in the required gear
    if speed < (idleTimeRequired and 0.9 or 0.2) and throttle_input == 0 and brake_input > 0.2 and parkingbrake == 0 and gearbox.mode == "drive" then
        -- Start the required idle countdown
        if startedIdling == false and engineTempOff == false then
            --log("D", "idleStopStart.automatic", "Started idling...") --[Debug]

            startedIdling = true
            idleStartedAt = os.time()

            return
        end

        -- Stop the engine after the required idle countdown
        if startedIdling == true and engineTempOff == false and (os.time() - idleStartedAt) >= idleTimeRequired then
            --log("D", "idleStopStart.automatic", string.format("Idled for %s seconds, stopping engine...", idleTimeRequired)) --[Debug]

            stop_engine(engine)

            startedIdling = false
            idleStartedAt = 0

            gui.message({txt = "Engine stopped while idling. Apply throttle or release brake to restart engine.", context = {}}, 10, "vehicle.info")

            return
        end
    end

    -- Checks to run if the throttle is pressed in
    if throttle_input > 0 then
        -- Stop the idle countdown if the throttle is pressed in during the required period
        if startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
            --log("D", "idleStopStart.automatic", "Stopped idling (throttle input detected)") --[Debug]

            startedIdling = false
            idleStartedAt = 0

            return

        -- Restart the engine if the throttle is pressed while it is temporarily stopped
        elseif engineTempOff == true then
            --log("D", "idleStopStart.automatic", "Restarting engine (throttle input detected)") --[Debug]

            start_engine(engine)

            gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

            return
        end
    end

    -- Restart the engine if it is off and the brake is released
    if engineTempOff == true and brake_input < 0.2 then
        --log("D", "idleStopStart.automatic", "Restarting engine (brake released)") --[Debug]

        start_engine(engine)

        gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

        return
    end

    -- Cancel the idle countdown if the vehicle is shifted out of the required gear during idling
    if gearbox.mode ~= "drive" and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
        --log("D", "idleStopStart.automatic", "Stopped idling (shifted out of required gear)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the parking brake is applied
    if parkingbrake == 1 and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
        --log("D", "idleStopStart.automatic", "Stopped idling (parking brake applied)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the brake is removed
    if brake_input == 0 and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
        --log("D", "idleStopStart.automatic", "Stopped idling (brake removed)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Reset the engine temp off status if the engine is turned on for some reason (eg. manually turned on after being turned off due to idling)
    if engineTempOff == true and engine_running == 1 then
        --log("D", "idleStopStart.automatic", "Engine temp off status reset (engine was manually restarted)") --[Debug]

        engineTempOff = false

        gui.message({txt = "Engine was restarted manually while temporarily off due to idling", context = {}}, 10, "vehicle.error")

        return
    end
end

local function manual_based_gearbox(engine, gearbox, speed, throttle_input, brake_input, clutch_input, parkingbrake, engine_running)
    -- Check if the vehicle is idling and is in the required gear
    if speed < (idleTimeRequired and 0.9 or 0.2) and throttle_input == 0 and brake_input > 0.2 and parkingbrake == 0 and gearbox.gearIndex == 0 then
        -- Start the required idle countdown
        if startedIdling == false and engineTempOff == false then
            --log("D", "idleStopStart.manual", "Started idling...") --[Debug]

            startedIdling = true
            idleStartedAt = os.time()

            return
        end

        -- Stop the engine after the required idle countdown, and if the clutch is not engaged
        if startedIdling == true and engineTempOff == false and (os.time() - idleStartedAt) >= idleTimeRequired and clutch_input < 0.5 then
            --log("D", "idleStopStart.manual", string.format("Idled for %s seconds, stopping engine...", idleTimeRequired)) --[Debug]

            stop_engine(engine)

            startedIdling = false
            idleStartedAt = 0

            gui.message({txt = "Engine stopped while idling. Apply throttle or clutch, or release brake to restart engine.", context = {}}, 10, "vehicle.info")

            return
        end
    end

    -- Checks to run if the throttle is pressed in
    if throttle_input > 0 then
        -- Stop the idle countdown if the throttle is pressed in during the required period
        if startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
            --log("D", "idleStopStart.manual", "Stopped idling (throttle input detected)") --[Debug]

            startedIdling = false
            idleStartedAt = 0

            return

        -- Restart the engine if the throttle is pressed while it is temporarily stopped
        elseif engineTempOff == true then
            --log("D", "idleStopStart.manual", "Restarting engine... (throttle input detected)") --[Debug]

            start_engine(engine)

            gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

            return
        end
    end

    -- Restart the engine if it is off and the clutch is applied
    if engineTempOff == true and clutch_input > 0.5 then
        --log("D", "idleStopStart.manual", "Restarting engine (clutch input detected)") --[Debug]

        start_engine(engine)

        gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

        return
    end

    -- Restart the engine if it is off, the brake is released and the clutch is not engaged
    if engineTempOff == true and brake_input < 0.2 and clutch_input < 0.5 then
        log("D", "idleStopStart.manual", "Restarting engine (brake released)") --[Debug]

        start_engine(engine)

        gui.message({txt = "Engine restarted", context = {}}, 10, "vehicle.info")

        return
    end

    -- Cancel the idle countdown if the vehicle is shifted out of the required gear during idling
    if gearbox.gearIndex ~= 0 and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
        --log("D", "idleStopStart.manual", "Stopped idling (shifted out of required gear)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the parking brake is applied
    if parkingbrake == 1 and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
        --log("D", "idleStopStart.manual", "Stopped idling (parking brake applied)") --[Debug]

        startedIdling = false
        idleStartedAt = 0

        return
    end

    -- Cancel the idle countdown if the brake is removed
    if brake_input == 0 and startedIdling == true and (os.time() - idleStartedAt) <= idleTimeRequired then
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
    -- Stop running if disabled for some reason
    if disabled == true then
        --log("D", "idleStopStart", "System is disabled") --[Debug]

        return
    end

    -- Stop if idleTimeRequired isn't defined yet
    if idleTimeRequired == nil then
        --log("D", "idleStopStart", "idleTimeRequired not yet defined") --[Debug]

        return
    end

    local engine = powertrain.getDevice("mainEngine") or nil
    local gearbox = powertrain.getDevice("gearbox") or nil

    local speed = electrics.values["airspeed"]
    local throttle_input = electrics.values["throttle_input"]
    local brake_input = electrics.values["brake_input"]
    local clutch_input = electrics.values["clutch_input"] or 0
    local parkingbrake = electrics.values["parkingbrake"]
    local engine_running = electrics.values["engineRunning"]

    if engine == nil then
        gui.message({txt = "Idle Stop-Start could not find a main engine and cannot function; this usually happens with electric motors or some modded motors", context = {}}, 10, "vehicle.error")

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
        func(engine, gearbox, speed, throttle_input, brake_input, clutch_input, parkingbrake, engine_running)
    else
        --log("D", "idleStopStart", "No appropriate gearbox function found") --[Debug]
    end
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX

return M