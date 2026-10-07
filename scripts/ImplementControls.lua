-- ============================================================
-- FS25_Implement_Controls.lua
-- by Marcus (Cobra Modding)
--
--
-- Version 1.0.0.1
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================


Implement_Controls = {}

local Implement_Controls_mt =
    Class(Implement_Controls)

function Implement_Controls.new()

    local self =
        setmetatable(
            {},
            Implement_Controls_mt
        )

    self.hookInstalled =
        false

    return self
end

function Implement_Controls:loadMap()

    if not self.hookInstalled then

        Enterable.onRegisterActionEvents =
            Utils.appendedFunction(
                Enterable.onRegisterActionEvents,
                Implement_Controls.onRegisterActionEvents
            )

        self.hookInstalled =
            true
    end

end

function Implement_Controls:deleteMap()
end

function Implement_Controls:showWarning(
    textKey
)

    if g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                g_i18n:getText(
                    textKey
                ),
                2000
            )
    end
end

function Implement_Controls:getVehicleRoot(
    vehicle
)

    if vehicle == nil then
        return nil
    end

    if vehicle.getRootVehicle ~= nil then

        vehicle =
            vehicle:getRootVehicle()

    elseif vehicle.rootVehicle ~= nil then

        vehicle =
            vehicle.rootVehicle
    end

    return vehicle
end


function Implement_Controls:getRootVehicle(
    vehicle
)

    vehicle =
        self:getVehicleRoot(
            vehicle
        )

    if vehicle == nil
        or vehicle.getAttachedImplements == nil
        or vehicle.rootNode == nil then

        return nil
    end

    return vehicle
end

function Implement_Controls:isImplementOnSide(
    rootVehicle,
    implement,
    wantFront
)

    if implement == nil
        or implement.object == nil then

        return false
    end

    local referenceNode =
        implement.object.rootNode

    if rootVehicle.getAttacherJointByJointDescIndex ~= nil then

        local jointDesc =
            rootVehicle:
                getAttacherJointByJointDescIndex(
                    implement.jointDescIndex
                )

        if jointDesc ~= nil
            and jointDesc.jointTransform ~= nil then

            referenceNode =
                jointDesc.jointTransform
        end
    end

    if referenceNode == nil then
        return false
    end

    local _, _, z =
        localToLocal(
            referenceNode,
            rootVehicle.rootNode,
            0,
            0,
            0
        )

    return wantFront
        and z >= 0
        or not wantFront
        and z < 0
end

function Implement_Controls:getDirectImplements(
    rootVehicle,
    wantFront
)

    local result =
        {}

    for _, implement
        in pairs(
            rootVehicle:getAttachedImplements()
            or {}
        ) do

        if wantFront == nil
            or self:isImplementOnSide(
                rootVehicle,
                implement,
                wantFront
            ) then

            table.insert(
                result,
                implement
            )
        end
    end

    return result
end

function Implement_Controls:isTurnableObject(
    object
)

    return object ~= nil
        and object.getIsTurnedOn ~= nil
        and object.setIsTurnedOn ~= nil
        and object.getCanToggleTurnedOn ~= nil
        and object:getCanToggleTurnedOn()
end


function Implement_Controls:collectTurnableObjects(
    object,
    result,
    seen
)

    if object == nil
        or seen[object] then

        return
    end

    seen[object] =
        true

    if self:isTurnableObject(
        object
    ) then

        table.insert(
            result,
            object
        )
    end

    if object.getAttachedImplements ~= nil then

        for _, implement
            in pairs(
                object:getAttachedImplements()
                or {}
            ) do

            self:
                collectTurnableObjects(
                    implement.object,
                    result,
                    seen
                )
        end
    end
end


function Implement_Controls:hasAttacherControlledTurnOn(
    object,
    seen
)

    if object == nil
        or seen[object] then

        return false
    end

    seen[object] =
        true

    local spec =
        object.spec_turnOnVehicle

    if spec ~= nil
        and spec.turnedOnByAttacherVehicle then

        return true
    end

    if object.getAttachedImplements ~= nil then

        for _, implement
            in pairs(
                object:getAttachedImplements()
                or {}
            ) do

            if self:
                hasAttacherControlledTurnOn(
                    implement.object,
                    seen
                ) then

                return true
            end
        end
    end

    return false
end

function Implement_Controls:collectFoldableObjects(
    object,
    result,
    seen
)

    if object == nil
        or seen[object] then

        return
    end

    seen[object] =
        true

    local spec =
        object.spec_foldable

    local isOnlyLowering =
        spec ~= nil
        and spec.foldMiddleAnimTime ~= nil
        and spec.foldMiddleAnimTime == 1

    if spec ~= nil
        and spec.foldingParts ~= nil
        and #spec.foldingParts > 0
        and not isOnlyLowering
        and object.getToggledFoldDirection ~= nil
        and object.getIsFoldAllowed ~= nil
        and object.setFoldState ~= nil then

        table.insert(
            result,
            object
        )
    end

    if object.getAttachedImplements ~= nil then

        for _, implement
            in pairs(
                object:getAttachedImplements()
                or {}
            ) do

            self:
                collectFoldableObjects(
                    implement.object,
                    result,
                    seen
                )
        end
    end
end

function Implement_Controls:toggleLift(
    vehicle,
    wantFront
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then
        return
    end

    local liftable =
        {}

    local shouldLower =
        false

    for _, implement
        in ipairs(
            self:getDirectImplements(
                rootVehicle,
                wantFront
            )
        ) do

        local object =
            implement.object

        local jointDesc =
            rootVehicle.getAttacherJointByJointDescIndex ~= nil
            and rootVehicle:
                getAttacherJointByJointDescIndex(
                    implement.jointDescIndex
                )
            or nil

        local allowsLowering =
            object.getAllowsLowering ~= nil
            and object:getAllowsLowering()

        local supportsJointLowering =
            allowsLowering
            and jointDesc ~= nil
            and jointDesc.allowsLowering

        local foldableSpec =
            object.spec_foldable

        local supportsFoldMiddleLowering =
            foldableSpec ~= nil
            and foldableSpec.foldMiddleAnimTime ~= nil
            and foldableSpec.foldMiddleAIRaiseDirection ~= nil
            and foldableSpec.foldMiddleAIRaiseDirection ~= 0
            and object.setFoldState ~= nil

        if supportsFoldMiddleLowering
            and object.getIsFoldMiddleAllowed ~= nil then

            supportsFoldMiddleLowering =
                object:getIsFoldMiddleAllowed()
        end

        local pickupSpec = object.spec_pickup

        local supportsPickupLowering =
            pickupSpec ~= nil
            and pickupSpec.animationName ~= nil
            and pickupSpec.animationName ~= ""
            and object.setPickupState ~= nil
            and object.setLoweredAll ~= nil

        if supportsJointLowering
            or supportsFoldMiddleLowering
            or supportsPickupLowering then

            table.insert(
                liftable,
                implement
            )

            local isLowered =
                false

            if object.getIsLowered ~= nil then

                isLowered =
                    object:getIsLowered(
                        false
                    )

            elseif supportsJointLowering then

                isLowered =
                    jointDesc.moveDown

                if rootVehicle.getJointMoveDown ~= nil then

                    isLowered =
                        rootVehicle:
                            getJointMoveDown(
                                implement.jointDescIndex
                            )
                end
            end

            if not isLowered then

                shouldLower =
                    true
            end
        end
    end

    if #liftable == 0 then

        local textKey =
            "frc_noAllLift"

        if wantFront == true then

            textKey =
                "frc_noFrontLift"

        elseif wantFront == false then

            textKey =
                "frc_noRearLift"
        end

        self:
            showWarning(
                textKey
            )

        return
    end

    for _, implement
        in ipairs(
            liftable
        ) do

        local object =
            implement.object

        if object.setLoweredAll ~= nil then

            object:
                setLoweredAll(
                    shouldLower,
                    implement.jointDescIndex
                )

        else

            rootVehicle:
                handleLowerImplementByAttacherJointIndex(
                    implement.jointDescIndex,
                    shouldLower
                )
        end
    end
end

function Implement_Controls:togglePower(
    vehicle,
    wantFront
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then
        return
    end

    local directImplements =
        self:getDirectImplements(
            rootVehicle,
            wantFront
        )

    local objects =
        {}

    local seen =
        {}

    for _, implement
        in ipairs(
            directImplements
        ) do

        self:
            collectTurnableObjects(
                implement.object,
                objects,
                seen
            )
    end

    local hasAttacherControlledObject =
        false

    for _, implement
        in ipairs(
            directImplements
        ) do

        if self:
            hasAttacherControlledTurnOn(
                implement.object,
                {}
            ) then

            hasAttacherControlledObject =
                true

            break
        end
    end

    if hasAttacherControlledObject
        and self:isTurnableObject(
            rootVehicle
        ) then

        table.insert(
            objects,
            rootVehicle
        )
    end

    if #objects == 0 then

        local textKey =
            "frc_noAllPower"

        if wantFront == true then

            textKey =
                "frc_noFrontPower"

        elseif wantFront == false then

            textKey =
                "frc_noRearPower"
        end

        self:
            showWarning(
                textKey
            )

        return
    end

    local shouldTurnOn =
        false

    for _, object
        in ipairs(
            objects
        ) do

        if not object:getIsTurnedOn() then

            shouldTurnOn =
                true

            break
        end
    end

    local changed =
        false

    local warning =
        nil

    for _, object
        in ipairs(
            objects
        ) do

        if shouldTurnOn then

            local allowed =
                object.getCanBeTurnedOn == nil
                or object:getCanBeTurnedOn()

            if allowed then

                object:
                    setIsTurnedOn(
                        true,
                        false
                    )

                changed =
                    true

            elseif warning == nil
                and object.getTurnedOnNotAllowedWarning ~= nil then

                warning =
                    object:getTurnedOnNotAllowedWarning()
            end

        else

            object:
                setIsTurnedOn(
                    false,
                    false
                )

            changed =
                true
        end
    end

    if not changed
        and warning ~= nil
        and g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                warning,
                2000
            )
    end
end

function Implement_Controls:toggleFold(
    vehicle,
    wantFront
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then
        return
    end

    local objects =
        {}

    local seen =
        {}

    for _, implement
        in ipairs(
            self:getDirectImplements(
                rootVehicle,
                wantFront
            )
        ) do

        self:
            collectFoldableObjects(
                implement.object,
                objects,
                seen
            )
    end

    if #objects == 0 then

        local textKey =
            "frc_noAllFold"

        if wantFront == true then

            textKey =
                "frc_noFrontFold"

        elseif wantFront == false then

            textKey =
                "frc_noRearFold"
        end

        self:
            showWarning(
                textKey
            )

        return
    end

    local shouldUnfold =
        false

    for _, object
        in ipairs(
            objects
        ) do

        local direction =
            object:getToggledFoldDirection()

        if direction ==
            object.spec_foldable.turnOnFoldDirection then

            shouldUnfold =
                true

            break
        end
    end

    local changed =
        false

    local warning =
        nil

    for _, object
        in ipairs(
            objects
        ) do

        local direction =
            object:getToggledFoldDirection()

        local unfoldsObject =
            direction ==
            object.spec_foldable.turnOnFoldDirection

        if direction ~= 0
            and unfoldsObject == shouldUnfold then

            local allowed,
                  objectWarning =
                object:
                    getIsFoldAllowed(
                        direction,
                        false
                    )

            if allowed then

                object:
                    setFoldState(
                        direction,
                        unfoldsObject
                    )

                changed =
                    true

            elseif warning == nil then

                warning =
                    objectWarning
            end
        end
    end

    if not changed
        and warning ~= nil
        and g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                warning,
                2000
            )
    end
end

function Implement_Controls.registerVehicleAction(
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
                vehicle.frcImplementControlActionEvents,
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
            "Implement_Controls: action event %s could not be registered",
            tostring(
                inputAction
            )
        )
    end
end


function Implement_Controls.onRegisterActionEvents(
    vehicle,
    isActiveForInput,
    isActiveForInputIgnoreSelection
)

    if vehicle == nil
        or not vehicle.isClient then

        return
    end

    vehicle.frcImplementControlActionEvents =
        vehicle.frcImplementControlActionEvents
        or {}

    vehicle:
        clearActionEventsTable(
            vehicle.frcImplementControlActionEvents
        )

    if not isActiveForInputIgnoreSelection then
        return
    end

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_FRONT_LIFT,
        Implement_Controls.actionEventFrontLift
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_REAR_LIFT,
        Implement_Controls.actionEventRearLift
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_FRONT_POWER,
        Implement_Controls.actionEventFrontPower
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_REAR_POWER,
        Implement_Controls.actionEventRearPower
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_FRONT_FOLD,
        Implement_Controls.actionEventFrontFold
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_REAR_FOLD,
        Implement_Controls.actionEventRearFold
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_ALL_FOLD,
        Implement_Controls.actionEventAllFold
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_ALL_LIFT,
        Implement_Controls.actionEventAllLift
    )

    Implement_Controls.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_ALL_POWER,
        Implement_Controls.actionEventAllPower
    )
end

function Implement_Controls.actionEventFrontLift(
    vehicle
)

    g_Implement_Controls:
        toggleLift(
            vehicle,
            true
        )
end


function Implement_Controls.actionEventRearLift(
    vehicle
)

    g_Implement_Controls:
        toggleLift(
            vehicle,
            false
        )
end


function Implement_Controls.actionEventFrontPower(
    vehicle
)

    g_Implement_Controls:
        togglePower(
            vehicle,
            true
        )
end


function Implement_Controls.actionEventRearPower(
    vehicle
)

    g_Implement_Controls:
        togglePower(
            vehicle,
            false
        )
end


function Implement_Controls.actionEventFrontFold(
    vehicle
)

    g_Implement_Controls:
        toggleFold(
            vehicle,
            true
        )
end


function Implement_Controls.actionEventRearFold(
    vehicle
)

    g_Implement_Controls:
        toggleFold(
            vehicle,
            false
        )
end


function Implement_Controls.actionEventAllFold(
    vehicle
)

    g_Implement_Controls:
        toggleFold(
            vehicle,
            nil
        )
end


function Implement_Controls.actionEventAllLift(
    vehicle
)

    g_Implement_Controls:
        toggleLift(
            vehicle,
            nil
        )
end


function Implement_Controls.actionEventAllPower(
    vehicle
)

    g_Implement_Controls:
        togglePower(
            vehicle,
            nil
        )
end

g_Implement_Controls =
    Implement_Controls.new()

addModEventListener(
    g_Implement_Controls
)
