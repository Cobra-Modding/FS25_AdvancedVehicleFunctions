-- ============================================================
-- FS25_AirBrake.lua
-- by Marcus (Cobra Modding)
--
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================


AirBrake = {}

local AirBrake_mt =
    Class(AirBrake)

AirBrake.MAX_PRESSURE_BAR =
    10.0

AirBrake.COMPRESSOR_CUT_IN =
    8.0

AirBrake.COMPRESSOR_CUT_OUT =
    10.0

AirBrake.COMPRESSOR_IDLE_RATE =
    0.065

AirBrake.COMPRESSOR_HIGH_RATE =
    0.200

AirBrake.COMPRESSOR_SLOWDOWN_START =
    8.5

AirBrake.COMPRESSOR_HIGH_PRESSURE_MIN_FACTOR =
    0.55

AirBrake.SERVICE_BRAKE_APPLY_USE =
    0.40

AirBrake.SERVICE_BRAKE_HOLD_USE =
    0.25

AirBrake.SERVICE_BRAKE_DEADZONE =
    0.03

AirBrake.HANDBRAKE_APPLY_AIR_USE =
    0.35

AirBrake.HANDBRAKE_RELEASE_AIR_USE =
    0.35

AirBrake.HANDBRAKE_RELEASE_PRESSURE =
    1.0

AirBrake.TRAILER_CONNECT_AIR_USE =
    0.80

AirBrake.WARNING_PRESSURE =
    4.0

AirBrake.WEAK_BRAKE_PRESSURE =
    2.0

AirBrake.FAILURE_PRESSURE =
    0.5

AirBrake.NORMAL_PRESSURE =
    6.0

AirBrake.MIN_BRAKE_EFFECT =
    0.02

AirBrake.AUTO_APPLY_HANDBRAKE_ON_FAILURE =
    false

AirBrake.AIR_ICON_BLINK_INTERVAL =
    800

AirBrake.AIR_ICON_BLINK_ON_TIME =
    400

AirBrake.AIR_ARC_RADIUS =
    68

AirBrake.AIR_ARC_THICKNESS =
    3

AirBrake.AIR_ARC_SEGMENTS =
    72

AirBrake.AIR_ARC_START_ANGLE =
    211

AirBrake.AIR_ARC_SWEEP_ANGLE =
    -242

AirBrake.AIR_ARC_BACKGROUND_R =
    0.16

AirBrake.AIR_ARC_BACKGROUND_G =
    0.16

AirBrake.AIR_ARC_BACKGROUND_B =
    0.16

AirBrake.AIR_ARC_BACKGROUND_A =
    0.85

AirBrake.AIR_WARNING_ICON_SIZE =
    20

AirBrake.AIR_WARNING_ICON_GAP_Y =
    2

AirBrake.AIR_WARNING_ICON_X_OFFSET =
    0

AirBrake.AIR_WARNING_ICON_Y_OFFSET =
    0

function AirBrake.new()

    local self =
        setmetatable(
            {},
            AirBrake_mt
        )

    self.hooksInstalled =
        false

    self.handbrakeBridgeInstalled =
        false

    return self
end

function AirBrake:getRootVehicle(
    vehicle
)

    if vehicle == nil then
        return nil
    end

    if vehicle.getRootVehicle ~= nil then

        local rootVehicle =
            vehicle:getRootVehicle()

        if rootVehicle ~= nil then

            return rootVehicle
        end
    end

    if vehicle.rootVehicle ~= nil then

        return vehicle.rootVehicle
    end

    return vehicle
end

function AirBrake:getAirConsumer(
    vehicle
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil
        or rootVehicle.spec_motorized == nil then

        return nil,
               nil
    end

    local spec =
        rootVehicle.spec_motorized

    if spec.consumersByFillTypeName == nil then

        return nil,
               nil
    end

    local consumer =
        spec.consumersByFillTypeName[
            "AIR"
        ]

    if consumer == nil
        or consumer.fillUnitIndex == nil then

        return nil,
               nil
    end

    return rootVehicle,
           consumer
end


function AirBrake:hasAirBrakeSystem(
    vehicle
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    return rootVehicle ~= nil
        and consumer ~= nil
end

function AirBrake:initializeVehicle(
    vehicle
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    if rootVehicle == nil
        or consumer == nil then

        return nil,
               nil
    end

    if rootVehicle.frcAirRealismInitialized
        == true then

        return rootVehicle,
               consumer
    end

    rootVehicle.frcAirRealismInitialized =
        true

    consumer.frcOriginalUsage =
        consumer.usage

    consumer.frcOriginalRefillLitersPerSecond =
        consumer.refillLitersPerSecond

    consumer.frcOriginalRefillCapacityPercentage =
        consumer.refillCapacityPercentage

    consumer.usage =
        0

    consumer.refillLitersPerSecond =
        0

    consumer.refillCapacityPercentage =
        0

    consumer.doRefill =
        false

    rootVehicle.frcAirRealismLastBrakeInput =
        0

    rootVehicle.frcAirRealismHeldBrakeDirection =
        0

    rootVehicle.frcAirRealismRawBrakeInput =
        0

    rootVehicle.frcAirRealismRawBrakeInputTime =
        0

    rootVehicle.frcAirRealismFailure =
        false

    rootVehicle.frcAirRealismCompressorActive =
        false

    rootVehicle.frcAirRealismLastHandbrakeState =
        rootVehicle.frcHandbrakeActive
        == true

    rootVehicle.frcAirRealismLastTrailerAirUsage =
        nil

    if rootVehicle.getBrakeForce ~= nil
        and rootVehicle.frcAirRealismBrakeHookInstalled
            ~= true then

        rootVehicle.getBrakeForce =
            Utils.overwrittenFunction(
                rootVehicle.getBrakeForce,
                AirBrake.vehicleGetBrakeForce
            )

        rootVehicle.frcAirRealismBrakeHookInstalled =
            true
    end

    if rootVehicle.setBrakePedalInput ~= nil
        and rootVehicle.frcAirRealismBrakeInputHookInstalled
            ~= true then

        rootVehicle.setBrakePedalInput =
            Utils.appendedFunction(
                rootVehicle.setBrakePedalInput,
                AirBrake.onSetBrakePedalInput
            )

        rootVehicle.frcAirRealismBrakeInputHookInstalled =
            true
    end

    return rootVehicle,
           consumer
end

function AirBrake.onSetBrakePedalInput(
    vehicle,
    inputValue
)

    local realism =
        g_AirBrake

    if realism == nil then
        return
    end

    local rootVehicle =
        realism:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then
        return
    end

    if not realism:
        hasAirBrakeSystem(
            rootVehicle
        ) then

        return
    end

    rootVehicle.frcAirRealismRawBrakeInput =
        math.clamp(
            inputValue or 0,
            0,
            1
        )

    rootVehicle.frcAirRealismRawBrakeInputTime =
        g_time or 0
end

function AirBrake:getPressureBar(
    vehicle
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    if rootVehicle == nil
        or consumer == nil
        or rootVehicle.getFillUnitFillLevelPercentage
            == nil then

        return nil
    end

    local percentage =
        rootVehicle:
            getFillUnitFillLevelPercentage(
                consumer.fillUnitIndex
            )

    percentage =
        math.clamp(
            percentage or 0,
            0,
            1
        )

    return percentage
        * AirBrake.MAX_PRESSURE_BAR
end

function AirBrake:addPressureBar(
    vehicle,
    amountBar
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    if rootVehicle == nil
        or consumer == nil then

        return
    end

    if rootVehicle.isServer ~= true then

        return
    end

    if rootVehicle.getFillUnitCapacity == nil
        or rootVehicle.addFillUnitFillLevel == nil then

        return
    end

    local capacity =
        rootVehicle:
            getFillUnitCapacity(
                consumer.fillUnitIndex
            )

    if capacity == nil
        or capacity <= 0 then

        return
    end

    local pressure =
        self:getPressureBar(
            rootVehicle
        )

    if pressure == nil then
        return
    end

    local targetPressure =
        math.clamp(
            pressure
            + (
                amountBar or 0
            ),
            0,
            AirBrake.MAX_PRESSURE_BAR
        )

    local actualChange =
        targetPressure
        - pressure

    if math.abs(
        actualChange
    ) < 0.00001 then

        return
    end

    local percentageChange =
        actualChange
        / AirBrake.MAX_PRESSURE_BAR

    local liters =
        capacity
        * percentageChange

    local ownerFarmId =
        0

    if rootVehicle.getOwnerFarmId ~= nil then

        ownerFarmId =
            rootVehicle:
                getOwnerFarmId()
    end

    rootVehicle:
        addFillUnitFillLevel(
            ownerFarmId,
            consumer.fillUnitIndex,
            liters,
            consumer.fillType,
            ToolType.UNDEFINED
        )
end


function AirBrake:consumePressureBar(
    vehicle,
    amountBar
)

    amountBar =
        math.max(
            amountBar or 0,
            0
        )

    if amountBar <= 0 then

        return
    end

    self:addPressureBar(
        vehicle,
        -amountBar
    )
end

function AirBrake:getBrakeInput(
    vehicle,
    currentSpeed,
    acceleration
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then

        return 0
    end

    local brakeInput =
        0

    local currentTime =
        g_time or 0

    local rawTime =
        rootVehicle.frcAirRealismRawBrakeInputTime
        or 0

    if currentTime
        - rawTime <= 250 then

        brakeInput =
            math.max(
                brakeInput,
                rootVehicle.frcAirRealismRawBrakeInput
                    or 0
            )
    end

    local drivableSpec =
        rootVehicle.spec_drivable

    if drivableSpec ~= nil
        and drivableSpec.lastInputValues ~= nil then

        brakeInput =
            math.max(
                brakeInput,
                math.clamp(
                    drivableSpec.lastInputValues.axisBrake
                        or 0,
                    0,
                    1
                )
            )
    end

    local speed =
        currentSpeed or 0

    local input =
        acceleration or 0

    local heldBrakeDirection =
        rootVehicle.frcAirRealismHeldBrakeDirection or 0

    if math.abs(input) <= 0.01
        or input * heldBrakeDirection < 0 then

        heldBrakeDirection = 0
    end

    if speed > 0.0003 and input < -0.01 then

        heldBrakeDirection = -1

    elseif speed < -0.0003 and input > 0.01 then

        heldBrakeDirection = 1

    elseif math.abs(speed) > 0.0003 then

        heldBrakeDirection = 0
    end

    rootVehicle.frcAirRealismHeldBrakeDirection =
        heldBrakeDirection

    if math.abs(speed) <= 0.0003
        and heldBrakeDirection ~= 0
        and input * heldBrakeDirection > 0.01 then

        brakeInput = math.max(
            brakeInput,
            math.clamp(math.abs(input), 0, 1)
        )
    end

    if speed > 0.0003
        and input < -0.01 then

        brakeInput =
            math.max(
                brakeInput,
                math.clamp(
                    -input,
                    0,
                    1
                )
            )

    elseif speed < -0.0003
        and input > 0.01 then

        brakeInput =
            math.max(
                brakeInput,
                math.clamp(
                    input,
                    0,
                    1
                )
            )
    end

    if brakeInput <
        AirBrake.SERVICE_BRAKE_DEADZONE then

        brakeInput =
            0
    end

    return brakeInput
end

function AirBrake:updateServiceBrakeConsumption(
    vehicle,
    dt,
    currentSpeed,
    acceleration
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil
        or rootVehicle.isServer ~= true then

        return
    end

    local brakeInput =
        self:getBrakeInput(
            rootVehicle,
            currentSpeed,
            acceleration
        )

    local lastBrakeInput =
        rootVehicle.frcAirRealismLastBrakeInput
        or 0

    local airUse =
        0

    if brakeInput >
        lastBrakeInput then

        local deltaInput =
            brakeInput
            - lastBrakeInput

        airUse =
            airUse
            + deltaInput
            * AirBrake.SERVICE_BRAKE_APPLY_USE
    end

    if brakeInput >
        AirBrake.SERVICE_BRAKE_DEADZONE then

        local dtSeconds =
            math.min(
                math.max(
                    dt or 0,
                    0
                ),
                100
            )
            / 1000

        airUse =
            airUse
            + brakeInput
            * AirBrake.SERVICE_BRAKE_HOLD_USE
            * dtSeconds
    end

    if airUse > 0 then

        self:
            consumePressureBar(
                rootVehicle,
                airUse
            )
    end

    rootVehicle.frcAirRealismLastBrakeInput =
        brakeInput
end

function AirBrake:getAttachedAirConsumerUsage(
    vehicle
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then

        return 0
    end

    if rootVehicle.getAirConsumerUsage == nil then

        return 0
    end

    local success,
          usage =
        pcall(
            rootVehicle.getAirConsumerUsage,
            rootVehicle
        )

    if not success
        or usage == nil then

        return 0
    end

    return math.max(
        usage,
        0
    )
end

function AirBrake:updateTrailerAirConnection(
    vehicle
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil
        or rootVehicle.isServer ~= true then

        return
    end

    local currentUsage =
        self:
            getAttachedAirConsumerUsage(
                rootVehicle
            )

    local previousUsage =
        rootVehicle.frcAirRealismLastTrailerAirUsage

    if previousUsage == nil then

        rootVehicle.frcAirRealismLastTrailerAirUsage =
            currentUsage

        return
    end

    if currentUsage >
        previousUsage
        + 0.00001 then

        self:
            consumePressureBar(
                rootVehicle,
                AirBrake.TRAILER_CONNECT_AIR_USE
            )
    end

    if currentUsage <
        previousUsage
        - 0.00001 then
    end


    rootVehicle.frcAirRealismLastTrailerAirUsage =
        currentUsage
end

function AirBrake:updateCompressor(
    vehicle,
    dt
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    if rootVehicle == nil
        or consumer == nil then

        return
    end

    local pressure =
        self:getPressureBar(
            rootVehicle
        )

    if pressure == nil then

        return
    end

    if pressure <=
        AirBrake.COMPRESSOR_CUT_IN then

        rootVehicle.frcAirRealismCompressorActive =
            true
    end

    if pressure >=
        AirBrake.COMPRESSOR_CUT_OUT then

        rootVehicle.frcAirRealismCompressorActive =
            false
    end

    local motorRunning =
        false

    if rootVehicle.getMotorState ~= nil then

        motorRunning =
            rootVehicle:getMotorState()
            == MotorState.ON
    end

    if not motorRunning then

        consumer.doRefill =
            false

        return
    end

    if rootVehicle.frcAirRealismCompressorActive
        ~= true then

        consumer.doRefill =
            false

        return
    end

    consumer.doRefill =
        true

    local rpmFactor =
        0

    if rootVehicle.getMotorRpmPercentage ~= nil then

        rpmFactor =
            math.clamp(
                rootVehicle:
                    getMotorRpmPercentage()
                    or 0,
                0,
                1
            )
    end

    local buildRate =
        AirBrake.COMPRESSOR_IDLE_RATE
        +
        (
            AirBrake.COMPRESSOR_HIGH_RATE
            - AirBrake.COMPRESSOR_IDLE_RATE
        )
        * rpmFactor

    local pressureFactor =
        1.0

    if pressure >
        AirBrake.COMPRESSOR_SLOWDOWN_START then

        local slowdownRange =
            AirBrake.COMPRESSOR_CUT_OUT
            - AirBrake.COMPRESSOR_SLOWDOWN_START

        if slowdownRange > 0 then

            local highPressureFactor =
                math.clamp(
                    (
                        pressure
                        - AirBrake.COMPRESSOR_SLOWDOWN_START
                    )
                    / slowdownRange,
                    0,
                    1
                )

            pressureFactor =
                1
                -
                (
                    1
                    - AirBrake.COMPRESSOR_HIGH_PRESSURE_MIN_FACTOR
                )
                * highPressureFactor
        end
    end

    buildRate =
        buildRate
        * pressureFactor

    local dtSeconds =
        math.min(
            math.max(
                dt or 0,
                0
            ),
            100
        )
        / 1000

    local pressureIncrease =
        buildRate
        * dtSeconds

    if pressureIncrease > 0 then

        self:
            addPressureBar(
                rootVehicle,
                pressureIncrease
            )
    end
end

function AirBrake:getBrakeEffectiveness(
    vehicle
)

    local pressure =
        self:getPressureBar(
            vehicle
        )

    if pressure == nil then

        return 1.0
    end

    if pressure >=
        AirBrake.WEAK_BRAKE_PRESSURE then

        return 1.0
    end

    local pressureFactor =
        math.clamp(
            pressure
            / AirBrake.WEAK_BRAKE_PRESSURE,
            0,
            1
        )

    pressureFactor =
        pressureFactor
        * pressureFactor

    return
        AirBrake.MIN_BRAKE_EFFECT
        +
        (
            1
            - AirBrake.MIN_BRAKE_EFFECT
        )
        * pressureFactor
end

function AirBrake.vehicleGetBrakeForce(
    vehicle,
    superFunc
)

    local brakeForce =
        superFunc(
            vehicle
        )

    local realism =
        g_AirBrake

    if realism == nil then

        return brakeForce
    end

    if not realism:
        hasAirBrakeSystem(
            vehicle
        ) then

        return brakeForce
    end

    local rootVehicle =
        realism:
            getRootVehicle(
                vehicle
            )

    if rootVehicle ~= nil
        and rootVehicle.frcHandbrakeActive
            == true then

        return brakeForce
    end

    local effect =
        realism:
            getBrakeEffectiveness(
                rootVehicle
            )

    return brakeForce
        * effect
end

function AirBrake:updateFailureState(
    vehicle
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil then

        return
    end

    local pressure =
        self:getPressureBar(
            rootVehicle
        )

    if pressure == nil then

        return
    end

    rootVehicle.frcAirRealismFailure =
        pressure <=
        AirBrake.FAILURE_PRESSURE
end

function AirBrake:syncHandbrakeState(
    vehicle
)

    local rootVehicle =
        self:getRootVehicle(
            vehicle
        )

    if rootVehicle == nil
        or rootVehicle.isServer ~= true then

        return
    end

    local currentState =
        rootVehicle.frcHandbrakeActive
        == true

    local previousState =
        rootVehicle.frcAirRealismLastHandbrakeState

    if previousState == nil then

        rootVehicle.frcAirRealismLastHandbrakeState =
            currentState

        return
    end

    if currentState == previousState then

        return
    end

    if previousState == true
        and currentState == false then

        local pressure =
            self:getPressureBar(
                rootVehicle
            )
            or 0

        if pressure <
            AirBrake.HANDBRAKE_RELEASE_PRESSURE then

            if g_VehicleSystems ~= nil
                and g_VehicleSystems.setHandbrakeState
                    ~= nil then

                g_VehicleSystems:
                    setHandbrakeState(
                        rootVehicle,
                        true
                    )

            else

                rootVehicle.frcHandbrakeActive =
                    true
            end

            rootVehicle.frcAirRealismLastHandbrakeState =
                true

            return
        end

        self:
            consumePressureBar(
                rootVehicle,
                AirBrake.HANDBRAKE_RELEASE_AIR_USE
            )

        rootVehicle.frcAirRealismLastHandbrakeState =
            false

        return
    end

    if previousState == false
        and currentState == true then

        self:
            consumePressureBar(
                rootVehicle,
                AirBrake.HANDBRAKE_APPLY_AIR_USE
            )

        rootVehicle.frcAirRealismLastHandbrakeState =
            true

        return
    end

    rootVehicle.frcAirRealismLastHandbrakeState =
        currentState
end

function AirBrake.vehicleSystemsSetHandbrakeState(
    vehicleSystems,
    superFunc,
    vehicle,
    isActive
)

    local realism =
        g_AirBrake

    if realism == nil then

        return superFunc(
            vehicleSystems,
            vehicle,
            isActive
        )
    end

    local rootVehicle =
        realism:
            getRootVehicle(
                vehicle
            )

    if rootVehicle == nil
        or not realism:
            hasAirBrakeSystem(
                rootVehicle
            ) then

        return superFunc(
            vehicleSystems,
            vehicle,
            isActive
        )
    end

    local currentlyActive =
        rootVehicle.frcHandbrakeActive
        == true

    local wantsActive =
        isActive == true

    if currentlyActive
        and not wantsActive then

        local pressure =
            realism:
                getPressureBar(
                    rootVehicle
                )
            or 0

        if pressure <
            AirBrake.HANDBRAKE_RELEASE_PRESSURE then

            return false
        end
    end

    local result =
        superFunc(
            vehicleSystems,
            vehicle,
            isActive
        )

    realism:
        syncHandbrakeState(
            rootVehicle
        )

    return result
end

function AirBrake.vehicleSystemsToggleHandbrake(
    vehicleSystems,
    superFunc,
    vehicle
)

    local realism =
        g_AirBrake

    if realism == nil then

        return superFunc(
            vehicleSystems,
            vehicle
        )
    end

    local rootVehicle =
        realism:
            getRootVehicle(
                vehicle
            )

    if rootVehicle == nil
        or not realism:
            hasAirBrakeSystem(
                rootVehicle
            ) then

        return superFunc(
            vehicleSystems,
            vehicle
        )
    end

    if rootVehicle.frcHandbrakeActive
        == true then

        local pressure =
            realism:
                getPressureBar(
                    rootVehicle
                )
            or 0

        if pressure <
            AirBrake.HANDBRAKE_RELEASE_PRESSURE then

            return false
        end
    end

    local result =
        superFunc(
            vehicleSystems,
            vehicle
        )

    realism:
        syncHandbrakeState(
            rootVehicle
        )

    return result
end

function AirBrake:installHandbrakeBridge()

    if self.handbrakeBridgeInstalled then

        return
    end

    if VehicleSystems == nil then

        Logging.warning(
            "AirBrake: VehicleSystems nicht gefunden"
        )

        return
    end

    if VehicleSystems.setHandbrakeState ~= nil then

        VehicleSystems.setHandbrakeState =
            Utils.overwrittenFunction(
                VehicleSystems.setHandbrakeState,
                AirBrake.vehicleSystemsSetHandbrakeState
            )
    end

    if VehicleSystems.toggleHandbrake ~= nil then

        VehicleSystems.toggleHandbrake =
            Utils.overwrittenFunction(
                VehicleSystems.toggleHandbrake,
                AirBrake.vehicleSystemsToggleHandbrake
            )
    end

    self.handbrakeBridgeInstalled =
        true
end

function AirBrake:drawArc(
    centerX,
    centerY,
    radiusX,
    radiusY,
    thickness,
    startAngle,
    sweepAngle,
    factor,
    r,
    g,
    b,
    a
)

    factor =
        math.clamp(
            factor or 0,
            0,
            1
        )

    if factor <= 0 then

        return
    end

    local segmentCount =
        AirBrake.AIR_ARC_SEGMENTS

    for i = 0,
        segmentCount - 1 do

        local t1 =
            i
            / segmentCount

        if t1 >= factor then

            break
        end

        local t2 =
            math.min(
                (i + 1)
                / segmentCount,
                factor
            )

        local angle1 =
            math.rad(
                startAngle
                + sweepAngle
                * t1
            )

        local angle2 =
            math.rad(
                startAngle
                + sweepAngle
                * t2
            )

        local x1 =
            centerX
            + math.cos(
                angle1
            )
            * radiusX

        local y1 =
            centerY
            + math.sin(
                angle1
            )
            * radiusY

        local x2 =
            centerX
            + math.cos(
                angle2
            )
            * radiusX

        local y2 =
            centerY
            + math.sin(
                angle2
            )
            * radiusY

        drawLine2D(
            x1,
            y1,
            x2,
            y2,
            thickness,
            r,
            g,
            b,
            a
        )
    end
end

function AirBrake:drawAirPressureArc(
    speedMeter,
    pressure
)

    if pressure == nil then

        return
    end

    local pressureFactor =
        math.clamp(
            pressure
            / AirBrake.MAX_PRESSURE_BAR,
            0,
            1
        )

    local centerX =
        speedMeter.speedBg.x
        + speedMeter.speedGaugeCenterOffsetX

    local centerY =
        speedMeter.speedBg.y
        + speedMeter.speedGaugeCenterOffsetY

    local radiusX,
          radiusY =
        speedMeter:
            scalePixelValuesToScreenVector(
                AirBrake.AIR_ARC_RADIUS,
                AirBrake.AIR_ARC_RADIUS
            )

    local thickness =
        speedMeter:
            scalePixelToScreenHeight(
                AirBrake.AIR_ARC_THICKNESS
            )

    self:
        drawArc(
            centerX,
            centerY,
            radiusX,
            radiusY,
            thickness,
            AirBrake.AIR_ARC_START_ANGLE,
            AirBrake.AIR_ARC_SWEEP_ANGLE,
            1.0,
            AirBrake.AIR_ARC_BACKGROUND_R,
            AirBrake.AIR_ARC_BACKGROUND_G,
            AirBrake.AIR_ARC_BACKGROUND_B,
            AirBrake.AIR_ARC_BACKGROUND_A
        )

    local r,
          g,
          b,
          a


    if pressure <
        AirBrake.HANDBRAKE_RELEASE_PRESSURE then

        r = 1.00
        g = 0.03
        b = 0.02
        a = 1.00


    elseif pressure <
        AirBrake.NORMAL_PRESSURE then

        r = 1.00
        g = 0.72
        b = 0.02
        a = 1.00


    else

        r = 0.10
        g = 0.90
        b = 0.10
        a = 1.00
    end


    self:
        drawArc(
            centerX,
            centerY,
            radiusX,
            radiusY,
            thickness,
            AirBrake.AIR_ARC_START_ANGLE,
            AirBrake.AIR_ARC_SWEEP_ANGLE,
            pressureFactor,
            r,
            g,
            b,
            a
        )
end

function AirBrake:drawAirWarningIcon(
    speedMeter,
    pressure
)

    if pressure == nil then

        return
    end

    if pressure >=
        AirBrake.WARNING_PRESSURE then

        return
    end

    if pressure <
        AirBrake.HANDBRAKE_RELEASE_PRESSURE then

        local currentTime =
            g_time or 0

        local blinkPosition =
            currentTime
            % AirBrake.AIR_ICON_BLINK_INTERVAL

        if blinkPosition >
            AirBrake.AIR_ICON_BLINK_ON_TIME then

            return
        end
    end

    if speedMeter.vehicle == nil
        or speedMeter.gearIcon == nil then

        return
    end

    local vehicle =
        speedMeter.vehicle

    local posX,
          posY =
        speedMeter:
            getPosition()

    local _,
          fuelCapacity =
        SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(
            vehicle
        )

    local hasFuel =
        fuelCapacity ~= nil

    local hasRepair =
        vehicle.getDamageAmount ~= nil
        and vehicle:getDamageAmount() ~= nil

    local sectionPosX =
        posX
        + speedMeter.sectionOffsetX

    local sectionPosY =
        posY
        + speedMeter.sectionOffsetY

    if hasFuel then

        sectionPosX =
            sectionPosX
            + speedMeter.fuelOffsetX
    end

    if hasRepair then

        sectionPosX =
            sectionPosX
            + speedMeter.repairOffsetX
    end

    sectionPosX =
        sectionPosX
        + speedMeter.gearOffsetX

    local gearIconX =
        sectionPosX
        + speedMeter.gearIconOffsetX

    local gearIconY =
        sectionPosY
        + speedMeter.gearOffsetY
        + speedMeter.gearIconOffsetY

    local textSize =
        speedMeter:
            scalePixelToScreenHeight(
                AirBrake.AIR_WARNING_ICON_SIZE
                * 0.5
            )

    local gapY =
        speedMeter:
            scalePixelToScreenHeight(
                AirBrake.AIR_WARNING_ICON_GAP_Y
            )

    local offsetX =
        speedMeter:
            scalePixelToScreenWidth(
                AirBrake.AIR_WARNING_ICON_X_OFFSET
            )

    local offsetY =
        speedMeter:
            scalePixelToScreenHeight(
                AirBrake.AIR_WARNING_ICON_Y_OFFSET
            )

    local textX =
        gearIconX
        + speedMeter.gearIcon.width
        * 0.5
        + offsetX

    local textY =
        gearIconY
        - textSize
        - gapY
        + offsetY

    setTextBold(
        true
    )

    setTextAlignment(
        RenderText.ALIGN_CENTER
    )

    setTextColor(
        1.00,
        0.02,
        0.01,
        1.00
    )

    renderText(
        textX,
        textY,
        textSize,
        "AIR"
    )

    setTextColor(
        1,
        1,
        1,
        1
    )

    setTextBold(
        false
    )

    setTextAlignment(
        RenderText.ALIGN_LEFT
    )
end

function AirBrake.drawHud(
    speedMeter
)

    local realism =
        g_AirBrake

    if realism == nil then

        return
    end

    local vehicle =
        speedMeter.vehicle

    if vehicle == nil
        or not speedMeter.isVehicleDrawSafe
        or speedMeter.speedBg == nil then

        return
    end

    if not realism:
        hasAirBrakeSystem(
            vehicle
        ) then

        return
    end

    realism:
        initializeVehicle(
            vehicle
        )

    local pressure =
        realism:
            getPressureBar(
                vehicle
            )

    if pressure == nil then

        return
    end

    pressure =
        math.clamp(
            pressure,
            0,
            AirBrake.MAX_PRESSURE_BAR
        )

    realism:
        drawAirPressureArc(
            speedMeter,
            pressure
        )

    realism:
        drawAirWarningIcon(
            speedMeter,
            pressure
        )
end

function AirBrake:restoreVehicle(
    vehicle
)

    local rootVehicle,
          consumer =
        self:getAirConsumer(
            vehicle
        )

    if rootVehicle == nil
        or consumer == nil then

        return
    end

    if consumer.frcOriginalUsage ~= nil then

        consumer.usage =
            consumer.frcOriginalUsage
    end

    if consumer.frcOriginalRefillLitersPerSecond ~= nil then

        consumer.refillLitersPerSecond =
            consumer.frcOriginalRefillLitersPerSecond
    end

    if consumer.frcOriginalRefillCapacityPercentage ~= nil then

        consumer.refillCapacityPercentage =
            consumer.frcOriginalRefillCapacityPercentage
    end

    consumer.frcOriginalUsage =
        nil

    consumer.frcOriginalRefillLitersPerSecond =
        nil

    consumer.frcOriginalRefillCapacityPercentage =
        nil

    consumer.doRefill =
        false

    rootVehicle.frcAirRealismLastTrailerAirUsage =
        nil

    rootVehicle.frcAirRealismLastHandbrakeState =
        nil

    rootVehicle.frcAirRealismInitialized =
        false
end

function AirBrake:initializeLoadedVehicles()

    local vehicleSystem =
        g_currentMission ~= nil
        and g_currentMission.vehicleSystem
        or nil

    if vehicleSystem == nil
        or vehicleSystem.vehicles == nil then

        return
    end

    local processed =
        {}

    for _,
        vehicle
        in pairs(
            vehicleSystem.vehicles
        ) do

        local rootVehicle =
            self:getRootVehicle(
                vehicle
            )

        if rootVehicle ~= nil
            and not processed[
                rootVehicle
            ] then

            processed[
                rootVehicle
            ] =
                true

            if self:
                hasAirBrakeSystem(
                    rootVehicle
                ) then

                self:
                    initializeVehicle(
                        rootVehicle
                    )
            end
        end
    end
end

function AirBrake:update(
    dt
)

    local vehicleSystem =
        g_currentMission ~= nil
        and g_currentMission.vehicleSystem
        or nil

    if vehicleSystem == nil
        or vehicleSystem.vehicles == nil then

        return
    end

    local processed =
        {}

    for _,
        vehicle
        in pairs(
            vehicleSystem.vehicles
        ) do

        local rootVehicle =
            self:getRootVehicle(
                vehicle
            )

        if rootVehicle ~= nil
            and not processed[
                rootVehicle
            ] then

            processed[
                rootVehicle
            ] =
                true

            local initializedVehicle,
                  consumer =
                self:
                    initializeVehicle(
                        rootVehicle
                    )

            if initializedVehicle ~= nil
                and consumer ~= nil then

                local currentSpeed =
                    (
                        initializedVehicle.lastSpeedReal
                        or 0
                    )
                    *
                    (
                        initializedVehicle.movingDirection
                        or 1
                    )

                local acceleration =
                    0

                local drivableSpec =
                    initializedVehicle.spec_drivable

                if drivableSpec ~= nil then

                    acceleration =
                        drivableSpec.axisForward
                        or 0
                end

                self:
                    updateServiceBrakeConsumption(
                        initializedVehicle,
                        dt,
                        currentSpeed,
                        acceleration
                    )

                self:
                    syncHandbrakeState(
                        initializedVehicle
                    )

                self:
                    updateTrailerAirConnection(
                        initializedVehicle
                    )

                self:
                    updateCompressor(
                        initializedVehicle,
                        dt
                    )

                self:
                    updateFailureState(
                        initializedVehicle
                    )
            end
        end
    end
end

function AirBrake:deleteMap()

    local vehicleSystem =
        g_currentMission ~= nil
        and g_currentMission.vehicleSystem
        or nil

    if vehicleSystem == nil
        or vehicleSystem.vehicles == nil then

        return
    end

    local processed =
        {}

    for _,
        vehicle
        in pairs(
            vehicleSystem.vehicles
        ) do

        local rootVehicle =
            self:getRootVehicle(
                vehicle
            )

        if rootVehicle ~= nil
            and not processed[
                rootVehicle
            ] then

            processed[
                rootVehicle
            ] =
                true

            self:
                restoreVehicle(
                    rootVehicle
                )
        end
    end
end

function AirBrake:installHooks()

    if self.hooksInstalled then

        return
    end

    if SpeedMeterDisplay ~= nil
        and SpeedMeterDisplay.draw ~= nil then

        SpeedMeterDisplay.draw =
            Utils.appendedFunction(
                SpeedMeterDisplay.draw,
                AirBrake.drawHud
            )
    end

    self.hooksInstalled =
        true
end

function AirBrake:loadMap()

    self:
        installHandbrakeBridge()

    self:
        installHooks()

    self:
        initializeLoadedVehicles()

end

g_AirBrake =
    AirBrake.new()

addModEventListener(
    g_AirBrake
)
