-- ============================================================
-- FS25_AdvancedDamageSystem
-- Fix für synchronisierte Motortemperatur
-- by Marcus (Cobra Modding)
--
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================


FRC_ADSIngameTimeFix = FRC_ADSIngameTimeFix or {}

local Fix = FRC_ADSIngameTimeFix

if Fix.installed then
    return
end

Fix.installed = true

if g_modIsLoaded == nil
    or not g_modIsLoaded["FS25_AdvancedDamageSystem"] then

    return
end

local MAX_ENGINE_THERMAL_STEP_MS = 5000

local MAX_ENGINE_THERMAL_STEPS = 72

local function getIngameTimeScale()

    if g_currentMission == nil then
        return 1
    end


    local missionInfo =
        g_currentMission.missionInfo


    if missionInfo == nil then
        return 1
    end


    local timeScale =
        tonumber(
            missionInfo.timeScale
        ) or 1


    if timeScale < 0 then
        timeScale = 0
    end


    return timeScale

end

local function getScaledEngineDt(dt)

    local realDt =
        tonumber(dt) or 0


    if realDt < 0 then
        realDt = 0
    end


    return
        realDt
        * getIngameTimeScale()

end

local function hasActiveCVTAddon(vehicle)

    if vehicle == nil then
        return false
    end


    local specCVT =
        vehicle.spec_CVTaddon


    if specCVT == nil then
        return false
    end


    local cvtConfig =
        tonumber(
            specCVT.CVTconfig
        ) or 0


    return
        specCVT.CVTcfgExists == true
        and cvtConfig ~= 0
        and cvtConfig ~= 8

end

local function syncVanillaMotorTemperature(vehicle)

    if vehicle == nil then
        return
    end


    local adsSpec =
        vehicle.spec_AdvancedDamageSystem


    if adsSpec == nil then
        return
    end


    if adsSpec.isExcludedVehicle then
        return
    end

    if hasActiveCVTAddon(vehicle) then
        return
    end


    local motorized =
        vehicle.spec_motorized


    if motorized == nil
        or motorized.motorTemperature == nil then

        return
    end


    local engineTemperature =
        tonumber(
            adsSpec.engineTemperature
        )


    if engineTemperature == nil then
        return
    end

    local valueMin =
        tonumber(
            motorized.motorTemperature.valueMin
        ) or -80


    local valueMax =
        tonumber(
            motorized.motorTemperature.valueMax
        ) or 160


    engineTemperature =
        math.max(
            valueMin,
            math.min(
                valueMax,
                engineTemperature
            )
        )

    motorized.motorTemperature.value =
        engineTemperature

end

local function createEngineThermalWrapper(originalFunction)

    return function(vehicle, dt, ...)

        if vehicle == nil
            or vehicle.spec_AdvancedDamageSystem == nil then

            return originalFunction(
                vehicle,
                dt,
                ...
            )

        end


        local adsSpec =
            vehicle.spec_AdvancedDamageSystem

        if adsSpec.isExcludedVehicle then

            return originalFunction(
                vehicle,
                dt,
                ...
            )

        end

        local scaledDt =
            getScaledEngineDt(dt)

        if scaledDt <= 0 then

            return originalFunction(
                vehicle,
                0,
                ...
            )

        end

        local steps =
            math.ceil(
                scaledDt
                / MAX_ENGINE_THERMAL_STEP_MS
            )


        steps =
            math.max(
                1,
                math.min(
                    steps,
                    MAX_ENGINE_THERMAL_STEPS
                )
            )


        local stepDt =
            scaledDt
            / steps

        local result = nil


        for _ = 1, steps do

            result =
                originalFunction(
                    vehicle,
                    stepDt,
                    ...
                )

        end


        return result

    end

end

local function createSmoothingWrapper(originalFunction)

    return function(vehicle, dt, ...)

        if vehicle == nil
            or vehicle.spec_AdvancedDamageSystem == nil then

            return originalFunction(
                vehicle,
                dt,
                ...
            )

        end


        local adsSpec =
            vehicle.spec_AdvancedDamageSystem

        if adsSpec.isExcludedVehicle then

            return originalFunction(
                vehicle,
                dt,
                ...
            )

        end


        local realDt =
            math.max(
                tonumber(dt) or 0,
                0
            )


        local engineDt =
            getScaledEngineDt(dt)

        if math.abs(engineDt - realDt) < 0.001 then

            local result =
                originalFunction(
                    vehicle,
                    realDt,
                    ...
                )


            syncVanillaMotorTemperature(
                vehicle
            )


            return result

        end

        local transmissionBefore =
            adsSpec.transmissionTemperature

        local result =
            originalFunction(
                vehicle,
                engineDt,
                ...
            )


        local engineAfterScaledSmoothing =
            adsSpec.engineTemperature

        adsSpec.transmissionTemperature =
            transmissionBefore

        originalFunction(
            vehicle,
            realDt,
            ...
        )

        adsSpec.engineTemperature =
            engineAfterScaledSmoothing

        syncVanillaMotorTemperature(
            vehicle
        )


        return result

    end

end

local originalRegisterFunction =
    SpecializationUtil.registerFunction


SpecializationUtil.registerFunction =
    function(
        objectType,
        funcName,
        func
    )

        if funcName
            == "updateEngineThermalModel" then


            func =
                createEngineThermalWrapper(
                    func
                )


            Fix.engineThermalRegistered =
                true

        elseif funcName
            == "getSmoothedTemperature" then


            func =
                createSmoothingWrapper(
                    func
                )


            Fix.smoothingRegistered =
                true

        end

        return originalRegisterFunction(
            objectType,
            funcName,
            func
        )

    end
