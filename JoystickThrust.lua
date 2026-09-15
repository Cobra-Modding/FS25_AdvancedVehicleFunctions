-- ============================================================
-- FS25_JoystickThrust.lua
-- by Marcus (Cobra Modding)
--
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================


JoystickThrust = {}

local JoystickThrust_mt =
    Class(JoystickThrust)

JoystickThrust.JOYSTICK_THROTTLE_ACTION =
    "FRC_THROTTLE_AXIS"

JoystickThrust.JOYSTICK_THROTTLE_INVERTED =
    true

JoystickThrust.JOYSTICK_THROTTLE_DEADZONE =
    0.05

JoystickThrust.JOYSTICK_THROTTLE_DEFAULT_ENABLED =
    false


JoystickThrust.THRUST_LEVER_ACTION =
    "FRC_THRUST_LEVER_AXIS"

JoystickThrust.THRUST_LEVER_INVERTED =
    true

JoystickThrust.THRUST_LEVER_DEADZONE =
    0.02

JoystickThrust.THRUST_LEVER_DEFAULT_ENABLED =
    true

function JoystickThrust.new()

    local self =
        setmetatable(
            {},
            JoystickThrust_mt
        )

    self.hookInstalled =
        false

    return self
end

function JoystickThrust.getJoystickThrottleAndBrake(
    inputValue
)

    local value =
        math.max(
            -1,
            math.min(
                1,
                inputValue or 0
            )
        )

    if JoystickThrust.JOYSTICK_THROTTLE_INVERTED then

        value =
            -value
    end

    local deadzone =
        JoystickThrust.JOYSTICK_THROTTLE_DEADZONE

    local throttle =
        0

    local brake =
        0

    if value > deadzone then

        throttle =
            (
                value
                - deadzone
            )
            /
            (
                1
                - deadzone
            )

    elseif value < -deadzone then

        brake =
            (
                -value
                - deadzone
            )
            /
            (
                1
                - deadzone
            )
    end

    throttle =
        math.max(
            0,
            math.min(
                1,
                throttle
            )
        )

    brake =
        math.max(
            0,
            math.min(
                1,
                brake
            )
        )

    return throttle,
           brake
end

function JoystickThrust.normalizeThrustLever(
    inputValue
)

    local value =
        math.max(
            -1,
            math.min(
                1,
                inputValue or -1
            )
        )

    local throttle =
        (
            value
            + 1
        )
        * 0.5

    if JoystickThrust.THRUST_LEVER_INVERTED then

        throttle =
            1
            - throttle
    end

    local deadzone =
        JoystickThrust.THRUST_LEVER_DEADZONE

    if throttle <= deadzone then

        return 0

    elseif throttle >=
        1 - deadzone then

        return 1
    end

    return throttle
end

function JoystickThrust:loadMap()

    if not self.hookInstalled then

        Enterable.onRegisterActionEvents =
            Utils.appendedFunction(
                Enterable.onRegisterActionEvents,
                JoystickThrust.onRegisterActionEvents
            )

        Drivable.onUpdate =
            Utils.overwrittenFunction(
                Drivable.onUpdate,
                JoystickThrust.drivableOnUpdateWithJoystickThrottle
            )

        self.hookInstalled =
            true
    end

end

function JoystickThrust:deleteMap()
end

function JoystickThrust.registerVehicleAction(
    vehicle,
    inputAction,
    callback,
    triggerUp,
    triggerDown,
    triggerAlways
)

    if inputAction == nil then
        return
    end

    if triggerDown == nil then

        triggerDown =
            true
    end

    local registered,
          actionEventId =
        vehicle:
            addActionEvent(
                vehicle.JoystickThrustActionEvents,
                inputAction,
                vehicle,
                callback,
                triggerUp == true,
                triggerDown == true,
                triggerAlways == true,
                true,
                nil,
                nil,
                true
            )

    if actionEventId ~= nil then

        g_inputBinding:
            setActionEventActive(
                actionEventId,
                true
            )

        g_inputBinding:
            setActionEventTextVisibility(
                actionEventId,
                false
            )

    elseif not registered then

        Logging.warning(
            "JoystickThrust: action event %s could not be registered",
            tostring(
                inputAction
            )
        )
    end
end


function JoystickThrust.onRegisterActionEvents(
    vehicle,
    isActiveForInput,
    isActiveForInputIgnoreSelection
)

    if vehicle == nil
        or not vehicle.isClient then

        return
    end

    vehicle.JoystickThrustActionEvents =
        vehicle.JoystickThrustActionEvents
        or {}

    vehicle:
        clearActionEventsTable(
            vehicle.JoystickThrustActionEvents
        )

    if not isActiveForInputIgnoreSelection
        or vehicle.spec_drivable == nil then

        return
    end

    if vehicle.frcJoystickThrottleEnabled == nil then

        vehicle.frcJoystickThrottleEnabled =
            JoystickThrust.JOYSTICK_THROTTLE_DEFAULT_ENABLED
    end

    JoystickThrust.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_JOYSTICK_THROTTLE,
        JoystickThrust.actionEventToggleJoystickThrottle
    )

    local throttleAction =
        InputAction[
            JoystickThrust.JOYSTICK_THROTTLE_ACTION
        ]

    JoystickThrust.registerVehicleAction(
        vehicle,
        throttleAction,
        JoystickThrust.actionEventJoystickThrottle,
        false,
        false,
        true
    )

    if vehicle.frcThrustLeverEnabled == nil then

        vehicle.frcThrustLeverEnabled =
            JoystickThrust.THRUST_LEVER_DEFAULT_ENABLED
    end

    JoystickThrust.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_THRUST_LEVER,
        JoystickThrust.actionEventToggleThrustLever
    )

    local thrustLeverAction =
        InputAction[
            JoystickThrust.THRUST_LEVER_ACTION
        ]

    JoystickThrust.registerVehicleAction(
        vehicle,
        thrustLeverAction,
        JoystickThrust.actionEventThrustLever,
        false,
        false,
        true
    )
end

function JoystickThrust.actionEventToggleJoystickThrottle(
    vehicle,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    if vehicle == nil
        or vehicle.spec_drivable == nil then

        return
    end

    vehicle.frcJoystickThrottleEnabled =
        not (
            vehicle.frcJoystickThrottleEnabled
            == true
        )

    if not vehicle.frcJoystickThrottleEnabled then

        vehicle.frcJoystickThrottle =
            0

        vehicle.frcJoystickBrake =
            0

        vehicle.frcJoystickThrottleRaw =
            0
    end

    if g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                vehicle.frcJoystickThrottleEnabled
                    and "Joystick-Gashebel: EIN"
                    or "Joystick-Gashebel: AUS",
                1500
            )
    end
end

function JoystickThrust.actionEventJoystickThrottle(
    vehicle,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    if vehicle == nil
        or vehicle.spec_drivable == nil then

        return
    end

    if vehicle.getIsAIActive ~= nil
        and vehicle:getIsAIActive() then

        return
    end

    vehicle.frcJoystickThrottleRaw =
        inputValue or 0

    local throttle,
          brake =
        JoystickThrust.getJoystickThrottleAndBrake(
            inputValue
        )

    vehicle.frcJoystickThrottle =
        throttle

    vehicle.frcJoystickBrake =
        brake
end

function JoystickThrust.actionEventToggleThrustLever(
    vehicle,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    if vehicle == nil
        or vehicle.spec_drivable == nil then

        return
    end

    vehicle.frcThrustLeverEnabled =
        not (
            vehicle.frcThrustLeverEnabled
            == true
        )

    if not vehicle.frcThrustLeverEnabled then

        vehicle.frcThrustLeverThrottle =
            0

        vehicle.frcThrustLeverRaw =
            -1
    end

    if g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                vehicle.frcThrustLeverEnabled
                    and "Schubhebel: EIN"
                    or "Schubhebel: AUS",
                1500
            )
    end
end

function JoystickThrust.actionEventThrustLever(
    vehicle,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    if vehicle == nil
        or vehicle.spec_drivable == nil then

        return
    end

    if vehicle.getIsAIActive ~= nil
        and vehicle:getIsAIActive() then

        return
    end

    vehicle.frcThrustLeverRaw =
        inputValue or -1

    vehicle.frcThrustLeverThrottle =
        JoystickThrust.normalizeThrustLever(
            inputValue
        )
end

function JoystickThrust.drivableOnUpdateWithJoystickThrottle(
    vehicle,
    superFunc,
    dt,
    isActiveForInput,
    isActiveForInputIgnoreSelection,
    isSelected
)

    if vehicle ~= nil
        and vehicle.spec_drivable ~= nil
        and isActiveForInputIgnoreSelection then

        local joystickEnabled =
            vehicle.frcJoystickThrottleEnabled
            == true

        local thrustLeverEnabled =
            vehicle.frcThrustLeverEnabled
            == true

        if joystickEnabled
            or thrustLeverEnabled then

            local aiActive =
                vehicle.getIsAIActive ~= nil
                and vehicle:getIsAIActive()
                or false

            if not aiActive then

                local allowed =
                    true

                if vehicle.getIsPlayerVehicleControlAllowed ~= nil then

                    allowed =
                        vehicle:
                            getIsPlayerVehicleControlAllowed()
                end

                if allowed then

                    local spec =
                        vehicle.spec_drivable

                    local pedalThrottle =
                        0

                    local pedalBrake =
                        0

                    if spec.lastInputValues ~= nil then

                        pedalThrottle =
                            spec.lastInputValues.axisAccelerate
                            or 0

                        pedalBrake =
                            spec.lastInputValues.axisBrake
                            or 0
                    end

                    local joystickThrottle =
                        joystickEnabled
                        and (
                            vehicle.frcJoystickThrottle
                            or 0
                        )
                        or 0

                    local joystickBrake =
                        joystickEnabled
                        and (
                            vehicle.frcJoystickBrake
                            or 0
                        )
                        or 0

                    local thrustLeverThrottle =
                        thrustLeverEnabled
                        and (
                            vehicle.frcThrustLeverThrottle
                            or 0
                        )
                        or 0

                    local combinedThrottle =
                        math.max(
                            math.max(
                                0,
                                pedalThrottle
                            ),
                            math.max(
                                0,
                                joystickThrottle
                            ),
                            math.max(
                                0,
                                thrustLeverThrottle
                            )
                        )

                    local combinedBrake =
                        math.max(
                            math.max(
                                0,
                                pedalBrake
                            ),
                            math.max(
                                0,
                                joystickBrake
                            )
                        )

                    if vehicle.setAccelerationPedalInput ~= nil then

                        vehicle:
                            setAccelerationPedalInput(
                                combinedThrottle
                            )
                    end

                    if vehicle.setBrakePedalInput ~= nil then

                        vehicle:
                            setBrakePedalInput(
                                combinedBrake
                            )
                    end
                end
            end
        end
    end

    return superFunc(
        vehicle,
        dt,
        isActiveForInput,
        isActiveForInputIgnoreSelection,
        isSelected
    )
end

g_JoystickThrust =
    JoystickThrust.new()

addModEventListener(
    g_JoystickThrust
)
