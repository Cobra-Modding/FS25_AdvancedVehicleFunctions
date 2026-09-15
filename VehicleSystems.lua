-- ============================================================
-- FS25_VehicleSystems.lua
-- by Marcus (Cobra Modding)
--
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

VehicleSystemsHandbrakeEvent = {}

local VehicleSystemsHandbrakeEvent_mt =
    Class(
        VehicleSystemsHandbrakeEvent,
        Event
    )

InitEventClass(
    VehicleSystemsHandbrakeEvent,
    "VehicleSystemsHandbrakeEvent"
)


function VehicleSystemsHandbrakeEvent.emptyNew()

    return Event.new(
        VehicleSystemsHandbrakeEvent_mt
    )
end


function VehicleSystemsHandbrakeEvent.new(
    vehicle,
    isActive
)

    local self =
        VehicleSystemsHandbrakeEvent.emptyNew()

    self.vehicle =
        vehicle

    self.isActive =
        isActive == true

    return self
end


function VehicleSystemsHandbrakeEvent:readStream(
    streamId,
    connection
)

    self.vehicle =
        NetworkUtil.readNodeObject(
            streamId
        )

    self.isActive =
        streamReadBool(
            streamId
        )

    self:run(
        connection
    )
end


function VehicleSystemsHandbrakeEvent:writeStream(
    streamId,
    connection
)

    NetworkUtil.writeNodeObject(
        streamId,
        self.vehicle
    )

    streamWriteBool(
        streamId,
        self.isActive
    )
end


function VehicleSystemsHandbrakeEvent:run(
    connection
)

    if self.vehicle ~= nil
        and self.vehicle:getIsSynchronized() then

        g_VehicleSystems:
            setHandbrakeState(
                self.vehicle,
                self.isActive
            )
    end

    if not connection:getIsServer() then

        g_server:broadcastEvent(
            VehicleSystemsHandbrakeEvent.new(
                self.vehicle,
                self.isActive
            ),
            nil,
            connection,
            self.vehicle
        )
    end
end


function VehicleSystemsHandbrakeEvent.sendEvent(
    vehicle,
    isActive
)

    local event =
        VehicleSystemsHandbrakeEvent.new(
            vehicle,
            isActive
        )

    if g_server ~= nil then

        g_server:broadcastEvent(
            event,
            nil,
            nil,
            vehicle
        )

    else

        g_client:
            getServerConnection():
            sendEvent(
                event
            )
    end
end

VehicleSystemsDrivetrainEvent = {}

local VehicleSystemsDrivetrainEvent_mt =
    Class(
        VehicleSystemsDrivetrainEvent,
        Event
    )

InitEventClass(
    VehicleSystemsDrivetrainEvent,
    "VehicleSystemsDrivetrainEvent"
)


function VehicleSystemsDrivetrainEvent.emptyNew()

    return Event.new(
        VehicleSystemsDrivetrainEvent_mt
    )
end


function VehicleSystemsDrivetrainEvent.new(
    vehicle,
    fourWheelDriveActive,
    frontDifferentialLockActive,
    rearDifferentialLockActive
)

    local self =
        VehicleSystemsDrivetrainEvent.emptyNew()

    self.vehicle =
        vehicle

    self.fourWheelDriveActive =
        fourWheelDriveActive == true

    self.frontDifferentialLockActive =
        frontDifferentialLockActive == true

    self.rearDifferentialLockActive =
        rearDifferentialLockActive == true

    return self
end


function VehicleSystemsDrivetrainEvent:readStream(
    streamId,
    connection
)

    self.vehicle =
        NetworkUtil.readNodeObject(
            streamId
        )

    self.fourWheelDriveActive =
        streamReadBool(
            streamId
        )

    self.frontDifferentialLockActive =
        streamReadBool(
            streamId
        )

    self.rearDifferentialLockActive =
        streamReadBool(
            streamId
        )

    self:run(
        connection
    )
end


function VehicleSystemsDrivetrainEvent:writeStream(
    streamId,
    connection
)

    NetworkUtil.writeNodeObject(
        streamId,
        self.vehicle
    )

    streamWriteBool(
        streamId,
        self.fourWheelDriveActive
    )

    streamWriteBool(
        streamId,
        self.frontDifferentialLockActive
    )

    streamWriteBool(
        streamId,
        self.rearDifferentialLockActive
    )
end


function VehicleSystemsDrivetrainEvent:run(
    connection
)

    if self.vehicle ~= nil
        and self.vehicle:getIsSynchronized() then

        g_VehicleSystems:
            setDrivetrainState(
                self.vehicle,
                self.fourWheelDriveActive,
                self.frontDifferentialLockActive,
                self.rearDifferentialLockActive
            )
    end

    if not connection:getIsServer() then

        g_server:broadcastEvent(
            VehicleSystemsDrivetrainEvent.new(
                self.vehicle,
                self.fourWheelDriveActive,
                self.frontDifferentialLockActive,
                self.rearDifferentialLockActive
            ),
            nil,
            connection,
            self.vehicle
        )
    end
end


function VehicleSystemsDrivetrainEvent.sendEvent(
    vehicle,
    fourWheelDriveActive,
    frontDifferentialLockActive,
    rearDifferentialLockActive
)

    local event =
        VehicleSystemsDrivetrainEvent.new(
            vehicle,
            fourWheelDriveActive,
            frontDifferentialLockActive,
            rearDifferentialLockActive
        )

    if g_server ~= nil then

        g_server:broadcastEvent(
            event,
            nil,
            nil,
            vehicle
        )

    else

        g_client:
            getServerConnection():
            sendEvent(
                event
            )
    end
end

VehicleSystems = {}

local VehicleSystems_mt =
    Class(
        VehicleSystems
    )


function VehicleSystems.new()

    local self =
        setmetatable(
            {},
            VehicleSystems_mt
        )

    self.hookInstalled =
        false

    self.shopConfigurationsInstalled =
        false

    self.modDirectory =
        g_currentModDirectory

    self.handbrakeOverlay =
        nil

    self.preheatOverlay =
        nil

    self.drivetrainOverlays =
        {}

    self.handbrakeApplySample =
        nil

    self.handbrakeReleaseSample =
        nil

    self.preheatVehicle =
        nil

    self.preheatRootVehicle =
        nil

    self.preheatRemaining =
        0


    self.motorCoolingAccumulator =
        0

    self.lastCoolingEnvironmentTime =
        nil

    return self
end

VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE =
    "frcFourWheelDrive"

VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS =
    "frcDifferentialLocks"

VehicleSystems.HANDBRAKE_APPLY_SOUND_FILE =
    "sounds/brake_big.ogg"

VehicleSystems.HANDBRAKE_APPLY_SOUND_VOLUME =
    1.0

VehicleSystems.HANDBRAKE_RELEASE_SOUND_FILE =
    "sounds/vehBrakeSmallBrake_BgMN01.ogg"

VehicleSystems.HANDBRAKE_RELEASE_SOUND_VOLUME =
    0.8

function VehicleSystems.createYesNoConfiguration(
    configName,
    enabledName,
    price
)

    local items =
        {}

    local disabledItem =
        VehicleConfigurationItem.new(
            configName
        )

    disabledItem.name =
        g_i18n:getText(
            "configuration_valueNo"
        )

    disabledItem.index =
        1

    disabledItem.saveId =
        "1"

    disabledItem.price =
        0

    disabledItem.isDefault =
        true

    disabledItem.isYesNoOption =
        true

    table.insert(
        items,
        disabledItem
    )


    local enabledItem =
        VehicleConfigurationItem.new(
            configName
        )

    enabledItem.name =
        g_i18n:getText(
            enabledName
        )

    enabledItem.index =
        2

    enabledItem.saveId =
        "2"

    enabledItem.price =
        price

    enabledItem.isYesNoOption =
        true

    table.insert(
        items,
        enabledItem
    )

    return items
end

function VehicleSystems.hasSupportedDifferentialLayout(
    xmlFile
)

    if xmlFile == nil then
        return false
    end

    if xmlFile:hasProperty(
        "vehicle.motorized.differentials.differential(2)"
    ) then

        return true
    end


    for configurationIndex = 0, 31 do

        local path =
            string.format(
                "vehicle.motorized.differentialConfigurations.differentialConfiguration(%d).differentials.differential(2)",
                configurationIndex
            )

        if xmlFile:hasProperty(
            path
        ) then

            return true
        end
    end


    return false
end

function VehicleSystems.getStoreCategoryName(
    xmlFile,
    storeItem
)

    local categoryName =
        nil


    if storeItem ~= nil then

        categoryName =
            storeItem.categoryName

        if categoryName == nil then

            categoryName =
                storeItem.category
        end
    end


    if categoryName == nil
        and xmlFile ~= nil
        and xmlFile.getValue ~= nil then

        categoryName =
            xmlFile:getValue(
                "vehicle.storeData.category"
            )
    end


    if categoryName == nil then
        return nil
    end


    return string.lower(
        tostring(
            categoryName
        )
    )
end

function VehicleSystems.isSupportedDrivetrainCategory(
    categoryName
)

    if categoryName == nil then
        return false
    end


    categoryName =
        string.lower(
            categoryName
        )

    if string.find(
        categoryName,
        "tractor",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "harvester",
        1,
        true
    ) ~= nil then

        return true
    end


    if string.find(
        categoryName,
        "forageharvester",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "sprayer",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "teleloader",
        1,
        true
    ) ~= nil then

        return true
    end


    if string.find(
        categoryName,
        "telehandler",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "wheelloader",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "skidsteer",
        1,
        true
    ) ~= nil then

        return true
    end

    if string.find(
        categoryName,
        "forestry",
        1,
        true
    ) ~= nil then

        return true
    end


    return false
end

function VehicleSystems.isCrawlerVehicle(
    xmlFile
)

    if xmlFile == nil then
        return false
    end


    if xmlFile:hasProperty(
        "vehicle.crawlers"
    ) then

        return true
    end


    if xmlFile:hasProperty(
        "vehicle.crawler"
    ) then

        return true
    end


    if xmlFile:hasProperty(
        "vehicle.wheels.crawlers"
    ) then

        return true
    end


    if xmlFile:hasProperty(
        "vehicle.wheels.crawler"
    ) then

        return true
    end


    if xmlFile:hasProperty(
        "vehicle.wheels.crawlerTracks"
    ) then

        return true
    end


    if xmlFile:hasProperty(
        "vehicle.crawlerTracks"
    ) then

        return true
    end


    return false
end

function VehicleSystems.isSupportedDrivetrainVehicle(
    xmlFile,
    storeItem
)

    if xmlFile == nil then
        return false
    end

    if not xmlFile:hasProperty(
        "vehicle.motorized"
    ) then

        return false
    end

    if not xmlFile:hasProperty(
        "vehicle.wheels"
    ) then

        return false
    end

    if VehicleSystems.isCrawlerVehicle(
        xmlFile
    ) then

        return false
    end

    if not VehicleSystems.hasSupportedDifferentialLayout(
        xmlFile
    ) then

        return false
    end

    local categoryName =
        VehicleSystems.getStoreCategoryName(
            xmlFile,
            storeItem
        )


    if not VehicleSystems.isSupportedDrivetrainCategory(
        categoryName
    ) then

        return false
    end


    return true
end

function VehicleSystems.getConfigurationsFromXML(
    manager,
    superFunc,
    xmlFile,
    key,
    baseDir,
    customEnvironment,
    isMod,
    storeItem
)

    local configurations,
          defaultConfigurationIds =
        superFunc(
            manager,
            xmlFile,
            key,
            baseDir,
            customEnvironment,
            isMod,
            storeItem
        )


    if not VehicleSystems.isSupportedDrivetrainVehicle(
        xmlFile,
        storeItem
    ) then

        return configurations,
               defaultConfigurationIds
    end


    configurations =
        configurations
        or {}

    defaultConfigurationIds =
        defaultConfigurationIds
        or {}


    local awdName =
        VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE

    local lockName =
        VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS

    local awdItems =
        VehicleSystems.createYesNoConfiguration(
            awdName,
            "frc_configurationInstalled",
            5000
        )

    local lockItems =
        VehicleSystems.createYesNoConfiguration(
            lockName,
            "frc_configurationInstalled",
            5000
        )


    configurations[
        awdName
    ] =
        awdItems


    configurations[
        lockName
    ] =
        lockItems


    defaultConfigurationIds[
        awdName
    ] =
        ConfigurationUtil.getDefaultConfigIdFromItems(
            awdItems
        )


    defaultConfigurationIds[
        lockName
    ] =
        ConfigurationUtil.getDefaultConfigIdFromItems(
            lockItems
        )


    return configurations,
           defaultConfigurationIds
end

function VehicleSystems:installShopConfigurations()

    if self.shopConfigurationsInstalled
        or g_vehicleConfigurationManager == nil
        or ConfigurationUtil == nil then

        return
    end


    if g_vehicleConfigurationManager:
        getConfigurationDescByName(
            VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE
        ) == nil then

        g_vehicleConfigurationManager:
            addConfigurationType(
                VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
                g_i18n:getText(
                    "frc_configurationFourWheelDrive"
                ),
                VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
                VehicleConfigurationItem
            )
    end


    if g_vehicleConfigurationManager:
        getConfigurationDescByName(
            VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS
        ) == nil then

        g_vehicleConfigurationManager:
            addConfigurationType(
                VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
                g_i18n:getText(
                    "frc_configurationDifferentialLocks"
                ),
                VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
                VehicleConfigurationItem
            )
    end


    ConfigurationUtil.getConfigurationsFromXML =
        Utils.overwrittenFunction(
            ConfigurationUtil.getConfigurationsFromXML,
            VehicleSystems.getConfigurationsFromXML
        )


    self.shopConfigurationsInstalled =
        true
end

function VehicleSystems:loadHandbrakeSample(
    sampleName,
    relativeFilename
)

    if g_currentMission == nil
        or not g_currentMission:getIsClient() then

        return nil
    end


    local filename =
        self.modDirectory
        .. relativeFilename


    if not fileExists(
        filename
    ) then

        Logging.warning(
            "VehicleSystems: sound file not found: %s",
            filename
        )

        return nil
    end


    local sample =
        createSample(
            sampleName
        )


    if sample == nil
        or sample == 0 then

        Logging.warning(
            "VehicleSystems: createSample failed for %s",
            filename
        )

        return nil
    end


    local loaded =
        loadSample(
            sample,
            filename,
            false
        )


    if not loaded then

        Logging.warning(
            "VehicleSystems: loadSample failed for %s",
            filename
        )

        delete(
            sample
        )

        return nil
    end


    setSampleGroup(
        sample,
        AudioGroup.VEHICLE
    )



    return sample
end


function VehicleSystems:playHandbrakeSample(
    sample,
    volume
)

    if sample == nil
        or sample == 0 then

        return
    end


    if isSamplePlaying(
        sample
    ) then

        stopSample(
            sample,
            0,
            0
        )
    end


    playSample(
        sample,
        1,
        volume,
        0,
        0,
        0
    )
end


function VehicleSystems:deleteHandbrakeSample(
    sample
)

    if sample == nil
        or sample == 0 then

        return
    end


    if isSamplePlaying(
        sample
    ) then

        stopSample(
            sample,
            0,
            0
        )
    end


    delete(
        sample
    )
end

function VehicleSystems.initializeHandbrakeState(
    vehicle
)

    if vehicle == nil then
        return
    end


    local isActive =
        true


    if vehicle.savegame ~= nil
        and vehicle.savegame.xmlFile ~= nil
        and vehicle.savegame.key ~= nil then

        isActive =
            vehicle.savegame.xmlFile:
                getValue(
                    vehicle.savegame.key
                    .. "#frcHandbrakeActive",
                    true
                )
    end


    vehicle.frcHandbrakeActive =
        isActive == true
end


function VehicleSystems.saveHandbrakeState(
    vehicle,
    xmlFile,
    key,
    usedModNames
)

    if vehicle == nil
        or xmlFile == nil
        or key == nil then

        return
    end


    xmlFile:
        setValue(
            key
            .. "#frcHandbrakeActive",
            vehicle.frcHandbrakeActive == true
        )

    xmlFile:setValue(key .. "#frcFourWheelDriveActive", vehicle.frcFourWheelDriveActive == true)

    xmlFile:setValue(key .. "#frcFrontDifferentialLockActive", vehicle.frcFrontDifferentialLockActive == true)

    xmlFile:setValue(key .. "#frcRearDifferentialLockActive", vehicle.frcRearDifferentialLockActive == true)
end


function VehicleSystems.readHandbrakeStream(
    vehicle,
    streamId,
    connection,
    objectId
)

    vehicle.frcHandbrakeActive =
        streamReadBool(
            streamId
        )

    vehicle.frcFourWheelDriveActive = streamReadBool(streamId)

    vehicle.frcFrontDifferentialLockActive = streamReadBool(streamId)

    vehicle.frcRearDifferentialLockActive = streamReadBool(streamId)
    vehicle.frcDrivetrainInitialized = true
end


function VehicleSystems.writeHandbrakeStream(
    vehicle,
    streamId,
    connection
)

    streamWriteBool(
        streamId,
        vehicle.frcHandbrakeActive == true
    )

    streamWriteBool(streamId, vehicle.frcFourWheelDriveActive == true)

    streamWriteBool(streamId, vehicle.frcFrontDifferentialLockActive == true)

    streamWriteBool(streamId, vehicle.frcRearDifferentialLockActive == true)
end


function VehicleSystems:loadMap()

    self:installShopConfigurations()


    if not self.hookInstalled then

        Vehicle.xmlSchemaSavegame:
            register(
                XMLValueType.BOOL,
                "vehicles.vehicle(?)#frcHandbrakeActive",
                "Advanced Vehicle Functions handbrake state",
                true
            )

        Vehicle.xmlSchemaSavegame:register(XMLValueType.BOOL,
            "vehicles.vehicle(?)#frcFourWheelDriveActive",
            "Advanced Vehicle Functions drivetrain state", false)

        Vehicle.xmlSchemaSavegame:register(XMLValueType.BOOL,
            "vehicles.vehicle(?)#frcFrontDifferentialLockActive",
            "Advanced Vehicle Functions drivetrain state", false)

        Vehicle.xmlSchemaSavegame:register(XMLValueType.BOOL,
            "vehicles.vehicle(?)#frcRearDifferentialLockActive",
            "Advanced Vehicle Functions drivetrain state", false)

        Vehicle.loadFinished =
            Utils.appendedFunction(
                Vehicle.loadFinished,
                VehicleSystems.initializeHandbrakeState
            )


        Vehicle.onFinishedLoading = Utils.overwrittenFunction(
            Vehicle.onFinishedLoading,
            VehicleSystems.onFinishedLoading
        )


        Vehicle.saveToXMLFile =
            Utils.appendedFunction(
                Vehicle.saveToXMLFile,
                VehicleSystems.saveHandbrakeState
            )


        Vehicle.readStream =
            Utils.appendedFunction(
                Vehicle.readStream,
                VehicleSystems.readHandbrakeStream
            )


        Vehicle.writeStream =
            Utils.appendedFunction(
                Vehicle.writeStream,
                VehicleSystems.writeHandbrakeStream
            )


        Enterable.onRegisterActionEvents =
            Utils.appendedFunction(
                Enterable.onRegisterActionEvents,
                VehicleSystems.onRegisterActionEvents
            )


        WheelsUtil.updateWheelsPhysics =
            Utils.overwrittenFunction(
                WheelsUtil.updateWheelsPhysics,
                VehicleSystems.updateWheelsPhysics
            )


        SpeedMeterDisplay.draw =
            Utils.appendedFunction(
                SpeedMeterDisplay.draw,
                VehicleSystems.drawHudAdditions
            )


        Lights.onVehiclePhysicsUpdate =
            Utils.appendedFunction(
                Lights.onVehiclePhysicsUpdate,
                VehicleSystems.suppressHandbrakeBrakeLights
            )


        Motorized.actionEventToggleMotorState =
            Utils.overwrittenFunction(
                Motorized.actionEventToggleMotorState,
                VehicleSystems.actionEventToggleMotorStateWithPreheat
            )


        Motorized.actionEventSetMotorStateOn =
            Utils.overwrittenFunction(
                Motorized.actionEventSetMotorStateOn,
                VehicleSystems.actionEventSetMotorStateOnWithPreheat
            )


        Motorized.actionEventSetMotorStateIgnition =
            Utils.overwrittenFunction(
                Motorized.actionEventSetMotorStateIgnition,
                VehicleSystems.actionEventSetMotorStateIgnitionWithPreheat
            )


        Motorized.actionEventSetMotorStateOff =
            Utils.overwrittenFunction(
                Motorized.actionEventSetMotorStateOff,
                VehicleSystems.actionEventSetMotorStateOffWithPreheat
            )


        Motorized.addToPhysics =
            Utils.overwrittenFunction(
                Motorized.addToPhysics,
                VehicleSystems.addToPhysics
            )


        self.hookInstalled =
            true
    end


    if self.handbrakeOverlay == nil then

        self.handbrakeOverlay =
            Overlay.new(
                self.modDirectory
                .. "icons/handbrake.dds",
                0,
                0,
                0,
                0
            )
    end


    if self.preheatOverlay == nil then

        self.preheatOverlay =
            Overlay.new(
                self.modDirectory
                .. "icons/preheat.dds",
                0,
                0,
                0,
                0
            )
    end


    if next(
        self.drivetrainOverlays
    ) == nil then

        local overlayFiles =
        {
            front =
                "icons/diff_front.dds",

            middle =
                "icons/diff_middle.dds",

            rear =
                "icons/diff_back.dds"
        }


        for name, filename
            in pairs(
                overlayFiles
            ) do

            self.drivetrainOverlays[
                name
            ] =
                Overlay.new(
                    self.modDirectory
                    .. filename,
                    0,
                    0,
                    0,
                    0
                )
        end
    end


    if self.handbrakeApplySample == nil then

        self.handbrakeApplySample =
            self:loadHandbrakeSample(
                "FRC_HandbrakeApply",
                VehicleSystems.HANDBRAKE_APPLY_SOUND_FILE
            )
    end


    if self.handbrakeReleaseSample == nil then

        self.handbrakeReleaseSample =
            self:loadHandbrakeSample(
                "FRC_HandbrakeRelease",
                VehicleSystems.HANDBRAKE_RELEASE_SOUND_FILE
            )
    end


end

function VehicleSystems:deleteMap()

    if self.handbrakeOverlay ~= nil then

        self.handbrakeOverlay:
            delete()

        self.handbrakeOverlay =
            nil
    end


    if self.preheatOverlay ~= nil then

        self.preheatOverlay:
            delete()

        self.preheatOverlay =
            nil
    end


    for name, overlay
        in pairs(
            self.drivetrainOverlays
        ) do

        overlay:
            delete()

        self.drivetrainOverlays[
            name
        ] =
            nil
    end


    self:deleteHandbrakeSample(
        self.handbrakeApplySample
    )

    self.handbrakeApplySample =
        nil


    self:deleteHandbrakeSample(
        self.handbrakeReleaseSample
    )

    self.handbrakeReleaseSample =
        nil


    self:cancelPreheat()
end

function VehicleSystems:showWarning(
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

function VehicleSystems:getVehicleRoot(
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

function VehicleSystems:setHandbrakeState(
    vehicle,
    isActive
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    if rootVehicle == nil then
        return
    end


    local wasActive =
        rootVehicle.frcHandbrakeActive
        == true


    local newActive =
        isActive
        == true


    rootVehicle.frcHandbrakeActive =
        newActive


    if wasActive == newActive then
        return
    end


    local currentVehicle =
        g_localPlayer ~= nil
        and g_localPlayer:getCurrentVehicle()
        or nil


    local currentRootVehicle =
        self:getVehicleRoot(
            currentVehicle
        )


    if currentRootVehicle ~= rootVehicle then
        return
    end


    if newActive then

        self:playHandbrakeSample(
            self.handbrakeApplySample,
            VehicleSystems.HANDBRAKE_APPLY_SOUND_VOLUME
        )

    else

        self:playHandbrakeSample(
            self.handbrakeReleaseSample,
            VehicleSystems.HANDBRAKE_RELEASE_SOUND_VOLUME
        )
    end
end


function VehicleSystems:toggleHandbrake(
    vehicle
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    if rootVehicle == nil
        or rootVehicle.spec_motorized == nil
        or rootVehicle.spec_wheels == nil then

        self:showWarning(
            "frc_noHandbrake"
        )

        return
    end


    local isActive =
        not (
            rootVehicle.frcHandbrakeActive
            == true
        )


    self:setHandbrakeState(
        rootVehicle,
        isActive
    )


    VehicleSystemsHandbrakeEvent.sendEvent(
        rootVehicle,
        isActive
    )
end

function VehicleSystems:hasDrivetrainConfiguration(
    vehicle,
    configName,
    mustBeInstalled
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    local configId =
        rootVehicle ~= nil
        and rootVehicle.configurations ~= nil
        and rootVehicle.configurations[
            configName
        ]
        or nil


    if mustBeInstalled then

        return configId == 2
    end


    return configId ~= nil
end

function VehicleSystems:getDifferentialBranchAverageZ(
    vehicle,
    differentialIndex,
    visiting
)

    local spec =
        vehicle.spec_motorized


    local differential =
        spec ~= nil
        and spec.differentials ~= nil
        and spec.differentials[
            differentialIndex + 1
        ]
        or nil


    if differential == nil then

        return nil, 0
    end


    visiting =
        visiting
        or {}


    if visiting[
        differentialIndex
    ] then

        return nil, 0
    end


    visiting[
        differentialIndex
    ] =
        true


    local zSum =
        0


    local wheelCount =
        0


    for childIndex = 1, 2 do

        local index =
            differential[
                "diffIndex"
                .. childIndex
            ]


        local isWheel =
            differential[
                "diffIndex"
                .. childIndex
                .. "IsWheel"
            ]


        if isWheel then

            local wheel =
                vehicle.getWheelFromWheelIndex ~= nil
                and vehicle:
                    getWheelFromWheelIndex(
                        index
                    )
                or nil


            if wheel ~= nil
                and wheel.repr ~= nil then

                local referenceNode =
                    vehicle.components ~= nil
                    and vehicle.components[1] ~= nil
                    and vehicle.components[1].node
                    or vehicle.rootNode


                local _, _, z =
                    localToLocal(
                        wheel.repr,
                        referenceNode,
                        0,
                        0,
                        0
                    )


                zSum =
                    zSum + z


                wheelCount =
                    wheelCount + 1
            end

        else

            local childZ,
                  childWheelCount =
                self:getDifferentialBranchAverageZ(
                    vehicle,
                    index,
                    visiting
                )


            if childZ ~= nil
                and childWheelCount > 0 then

                zSum =
                    zSum
                    + childZ
                    * childWheelCount


                wheelCount =
                    wheelCount
                    + childWheelCount
            end
        end
    end


    visiting[
        differentialIndex
    ] =
        nil


    if wheelCount == 0 then

        return nil, 0
    end


    return zSum / wheelCount,
           wheelCount
end

function VehicleSystems:getRootDifferentialIndices(
    vehicle
)

    local differentials =
        vehicle.spec_motorized ~= nil
        and vehicle.spec_motorized.differentials
        or nil


    if differentials == nil then
        return {}
    end


    local referenced =
        {}


    for _, differential
        in ipairs(
            differentials
        ) do

        if not differential.diffIndex1IsWheel then

            referenced[
                differential.diffIndex1 + 1
            ] =
                true
        end


        if not differential.diffIndex2IsWheel then

            referenced[
                differential.diffIndex2 + 1
            ] =
                true
        end
    end


    local roots =
        {}


    for index = 1, #differentials do

        if not referenced[
            index
        ] then

            table.insert(
                roots,
                index
            )
        end
    end


    return roots
end

function VehicleSystems:getAxleDifferentialSides(
    vehicle
)

    local differentials =
        vehicle.spec_motorized ~= nil
        and vehicle.spec_motorized.differentials
        or nil


    if differentials == nil then
        return {}
    end


    local axlePositions =
        {}


    local minimumZ =
        math.huge


    local maximumZ =
        -math.huge


    for index, differential
        in ipairs(
            differentials
        ) do

        if differential.diffIndex1IsWheel
            and differential.diffIndex2IsWheel then

            local averageZ,
                  wheelCount =
                self:getDifferentialBranchAverageZ(
                    vehicle,
                    index - 1
                )


            if averageZ ~= nil
                and wheelCount > 0 then

                axlePositions[
                    index
                ] =
                    averageZ


                minimumZ =
                    math.min(
                        minimumZ,
                        averageZ
                    )


                maximumZ =
                    math.max(
                        maximumZ,
                        averageZ
                    )
            end
        end
    end


    local sides =
        {}


    if minimumZ == math.huge then
        return sides
    end


    local middleZ =
        (
            minimumZ
            + maximumZ
        )
        * 0.5


    for index, averageZ
        in pairs(
            axlePositions
        ) do

        sides[
            index
        ] =
            averageZ >= middleZ
            and "front"
            or "rear"
    end


    return sides
end

function VehicleSystems:applyDrivetrainPhysics(
    vehicle
)

    local spec =
        vehicle ~= nil
        and vehicle.spec_motorized
        or nil


    if vehicle == nil
        or not vehicle.isServer
        or spec == nil
        or spec.motorizedNode == nil
        or spec.differentials == nil
        or #spec.differentials == 0 then

        return
    end


    local hasAwdChoice =
        self:hasDrivetrainConfiguration(
            vehicle,
            VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
            false
        )


    local hasLockChoice =
        self:hasDrivetrainConfiguration(
            vehicle,
            VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
            false
        )


    if not hasAwdChoice
        and not hasLockChoice then

        return
    end


    local rootDifferentials =
        {}


    for _, index
        in ipairs(
            self:getRootDifferentialIndices(
                vehicle
            )
        ) do

        rootDifferentials[
            index
        ] =
            true
    end


    local axleDifferentialSides =
        self:getAxleDifferentialSides(
            vehicle
        )


    removeAllDifferentials(
        spec.motorizedNode
    )


    for index, differential
        in ipairs(
            spec.differentials
        ) do

        local torqueRatio =
            differential.torqueRatio


        local maxSpeedRatio =
            differential.maxSpeedRatio


        local axleSide =
            axleDifferentialSides[
                index
            ]

        if hasLockChoice then

            if axleSide == "front"
                and vehicle.frcFrontDifferentialLockActive == true then

                maxSpeedRatio =
                    1

            elseif axleSide == "rear"
                and vehicle.frcRearDifferentialLockActive == true then

                maxSpeedRatio =
                    1
            end
        end

        if hasAwdChoice
            and vehicle.frcFourWheelDriveActive ~= true
            and rootDifferentials[index]
            and not differential.diffIndex1IsWheel
            and not differential.diffIndex2IsWheel then

            local firstZ =
                self:getDifferentialBranchAverageZ(
                    vehicle,
                    differential.diffIndex1
                )


            local secondZ =
                self:getDifferentialBranchAverageZ(
                    vehicle,
                    differential.diffIndex2
                )


            if firstZ ~= nil
                and secondZ ~= nil then

                torqueRatio =
                    firstZ > secondZ
                    and 0
                    or 1
            end
        end

        local diffIndex1 =
            differential.diffIndex1


        local diffIndex2 =
            differential.diffIndex2


        if differential.diffIndex1IsWheel then

            local wheel =
                vehicle:
                    getWheelFromWheelIndex(
                        diffIndex1
                    )


            diffIndex1 =
                wheel ~= nil
                and wheel.physics.wheelShape
                or diffIndex1
        end


        if differential.diffIndex2IsWheel then

            local wheel =
                vehicle:
                    getWheelFromWheelIndex(
                        diffIndex2
                    )


            diffIndex2 =
                wheel ~= nil
                and wheel.physics.wheelShape
                or diffIndex2
        end


        addDifferential(
            spec.motorizedNode,
            diffIndex1,
            differential.diffIndex1IsWheel,
            diffIndex2,
            differential.diffIndex2IsWheel,
            torqueRatio,
            maxSpeedRatio
        )
    end


    if vehicle.updateMotorProperties ~= nil then

        vehicle:
            updateMotorProperties()
    end
end

function VehicleSystems:setDrivetrainState(
    vehicle,
    fourWheelDriveActive,
    frontDifferentialLockActive,
    rearDifferentialLockActive
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    if rootVehicle == nil then
        return
    end


    rootVehicle.frcFourWheelDriveActive =
        fourWheelDriveActive == true
        and self:
            hasDrivetrainConfiguration(
                rootVehicle,
                VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
                true
            )


    local hasDifferentialLocks =
        self:
            hasDrivetrainConfiguration(
                rootVehicle,
                VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
                true
            )


    rootVehicle.frcFrontDifferentialLockActive =
        frontDifferentialLockActive == true
        and hasDifferentialLocks


    rootVehicle.frcRearDifferentialLockActive =
        rearDifferentialLockActive == true
        and hasDifferentialLocks


    self:
        applyDrivetrainPhysics(
            rootVehicle
        )
end

function VehicleSystems.loadDrivetrainState(vehicle)
    if vehicle.frcDrivetrainInitialized ~= true then

        -- Read before Vehicle:onFinishedLoading clears vehicle.savegame.
        -- Preserve states already received from the server.
        local savegame = vehicle.savegame
        local xmlFile = savegame ~= nil and savegame.xmlFile or nil
        local key = savegame ~= nil and savegame.key or nil

        vehicle.frcFourWheelDriveActive = xmlFile ~= nil and key ~= nil
            and xmlFile:getValue(key .. "#frcFourWheelDriveActive", false) == true
            or false

        vehicle.frcFrontDifferentialLockActive = xmlFile ~= nil and key ~= nil
            and xmlFile:getValue(key .. "#frcFrontDifferentialLockActive", false) == true
            or false

        vehicle.frcRearDifferentialLockActive = xmlFile ~= nil and key ~= nil
            and xmlFile:getValue(key .. "#frcRearDifferentialLockActive", false) == true
            or false

        vehicle.frcDrivetrainInitialized =
            true
    end

end


function VehicleSystems.onFinishedLoading(vehicle, superFunc, ...)
    -- Specialization functions were registered before loadMap; use the
    -- Vehicle lifecycle directly instead of replacing Motorized afterwards.
    VehicleSystems.loadDrivetrainState(vehicle)
    superFunc(vehicle, ...)

    if g_VehicleSystems ~= nil then
        g_VehicleSystems:initializeDrivetrain(vehicle)
    end
end


function VehicleSystems:initializeDrivetrain(
    vehicle
)

    local hasConfiguration =
        self:
            hasDrivetrainConfiguration(
                vehicle,
                VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
                false
            )
        or
        self:
            hasDrivetrainConfiguration(
                vehicle,
                VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
                false
            )


    VehicleSystems.loadDrivetrainState(vehicle)


    if hasConfiguration then

        self:
            applyDrivetrainPhysics(
                vehicle
            )
    end
end


function VehicleSystems:initializeLoadedDrivetrains()

    local vehicleSystem =
        g_currentMission ~= nil
        and g_currentMission.vehicleSystem
        or nil


    if vehicleSystem == nil
        or vehicleSystem.vehicles == nil then

        return
    end


    for _, vehicle
        in pairs(
            vehicleSystem.vehicles
        ) do

        if vehicle.frcDrivetrainInitialized ~= true then

            self:
                initializeDrivetrain(
                    vehicle
                )
        end
    end
end


function VehicleSystems.addToPhysics(
    vehicle,
    superFunc
)

    local success =
        superFunc(
            vehicle
        )


    if success
        and g_VehicleSystems ~= nil then

        g_VehicleSystems:
            initializeDrivetrain(
                vehicle
            )
    end


    return success
end

function VehicleSystems:toggleFourWheelDrive(
    vehicle
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    if not self:
        hasDrivetrainConfiguration(
            rootVehicle,
            VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
            true
        ) then

        self:
            showWarning(
                "frc_noFourWheelDrive"
            )

        return
    end


    self:
        setDrivetrainState(
            rootVehicle,
            rootVehicle.frcFourWheelDriveActive ~= true,
            rootVehicle.frcFrontDifferentialLockActive == true,
            rootVehicle.frcRearDifferentialLockActive == true
        )


    VehicleSystemsDrivetrainEvent.sendEvent(
        rootVehicle,
        rootVehicle.frcFourWheelDriveActive,
        rootVehicle.frcFrontDifferentialLockActive,
        rootVehicle.frcRearDifferentialLockActive
    )
end

function VehicleSystems:toggleDifferentialLock(
    vehicle,
    wantFront
)

    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    if not self:
        hasDrivetrainConfiguration(
            rootVehicle,
            VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
            true
        ) then

        self:
            showWarning(
                "frc_noDifferentialLocks"
            )

        return
    end


    local frontActive =
        rootVehicle.frcFrontDifferentialLockActive
        == true


    local rearActive =
        rootVehicle.frcRearDifferentialLockActive
        == true


    if wantFront then

        frontActive =
            not frontActive

    else

        rearActive =
            not rearActive
    end


    self:
        setDrivetrainState(
            rootVehicle,
            rootVehicle.frcFourWheelDriveActive == true,
            frontActive,
            rearActive
        )


    VehicleSystemsDrivetrainEvent.sendEvent(
        rootVehicle,
        rootVehicle.frcFourWheelDriveActive,
        rootVehicle.frcFrontDifferentialLockActive,
        rootVehicle.frcRearDifferentialLockActive
    )
end

function VehicleSystems:cancelPreheat()

    self.preheatVehicle =
        nil


    self.preheatRootVehicle =
        nil


    self.preheatRemaining =
        0


    self.preheatFromIgnitionLock =
        false
end


function VehicleSystems:canPreheat(
    vehicle
)

    if vehicle == nil
        or not vehicle.isClient
        or vehicle.spec_motorized == nil
        or vehicle.getConsumerFillUnitIndex == nil
        or vehicle:getConsumerFillUnitIndex(
            FillType.DIESEL
        ) == nil then

        return false
    end


    local temperature =
        vehicle.spec_motorized.motorTemperature


    return temperature ~= nil
        and temperature.value ~= nil
        and temperature.value < 45
end


function VehicleSystems:beginPreheat(
    vehicle,
    fromIgnitionLock
)

    if self.preheatVehicle == vehicle
        and self.preheatRemaining > 0 then

        if fromIgnitionLock == true then

            self.preheatFromIgnitionLock =
                true
        end

        return true
    end


    if not self:canPreheat(
        vehicle
    )
        or vehicle.getCanMotorRun == nil
        or not vehicle:getCanMotorRun() then

        return false
    end


    local temperature =
        vehicle.spec_motorized.motorTemperature.value


    local coldFactor =
        math.clamp(
            (
                45
                - temperature
            )
            / 25,
            0,
            1
        )


    local duration =
        1000
        + coldFactor
        * 3000


    vehicle.frcPreheated =
        false


    self.preheatVehicle =
        vehicle


    self.preheatRootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    self.preheatRemaining =
        duration


    self.preheatFromIgnitionLock =
        fromIgnitionLock == true


    if g_currentMission ~= nil then

        g_currentMission:
            showBlinkingWarning(
                g_i18n:getText(
                    "frc_preheating"
                ),
                duration
            )
    end


    return true
end

function VehicleSystems:updateStoppedMotorCooling(
    dt
)

    self.motorCoolingAccumulator =
        self.motorCoolingAccumulator
        + dt


    if self.motorCoolingAccumulator < 1000 then
        return
    end


    local elapsedSeconds =
        self.motorCoolingAccumulator
        / 1000


    self.motorCoolingAccumulator =
        0


    local mission =
        g_currentMission


    local vehicleSystem =
        mission ~= nil
        and mission.vehicleSystem
        or nil


    local environment =
        mission ~= nil
        and mission.environment
        or nil


    if vehicleSystem == nil
        or vehicleSystem.vehicles == nil
        or environment == nil then

        return
    end


    local dayTime =
        environment.dayTime


    if dayTime == nil then

        local hour =
            environment.currentHour
            or 0


        local minute =
            environment.currentMinute
            or 0


        dayTime =
            (
                hour * 60
                + minute
            )
            * 60000
    end


    local environmentTime =
        (
            environment.currentDay
            or 0
        )
        * 86400000
        + dayTime


    if self.lastCoolingEnvironmentTime ~= nil then

        local gameElapsedSeconds =
            (
                environmentTime
                - self.lastCoolingEnvironmentTime
            )
            / 1000


        if gameElapsedSeconds > 0 then

            elapsedSeconds =
                math.max(
                    elapsedSeconds,
                    gameElapsedSeconds
                )
        end
    end


    self.lastCoolingEnvironmentTime =
        environmentTime


    local coolingFactor =
        math.exp(
            -0.00015
            * elapsedSeconds
        )


    for _, vehicle
        in pairs(
            vehicleSystem.vehicles
        ) do

        local spec =
            vehicle.spec_motorized


        if spec ~= nil
            and vehicle.getMotorState ~= nil then

            local motorState =
                vehicle:getMotorState()


            local temperature =
                spec.motorTemperature


            if (
                motorState == MotorState.OFF
                or motorState == MotorState.IGNITION
            )
                and temperature ~= nil
                and temperature.value ~= nil then

                local minimum =
                    temperature.valueMin
                    or 20


                if temperature.value > minimum then

                    temperature.value =
                        minimum
                        +
                        (
                            temperature.value
                            - minimum
                        )
                        * coolingFactor


                    if temperature.value
                        - minimum < 0.05 then

                        temperature.value =
                            minimum
                    end


                    temperature.valueSend =
                        temperature.value
                end
            end
        end
    end
end

function VehicleSystems:updateIgnitionLockPreheat()

    if g_ignitionLockManager == nil
        or not g_ignitionLockManager:getIsAvailable()
        or g_localPlayer == nil then

        return
    end


    local vehicle =
        g_localPlayer:getCurrentVehicle()


    if vehicle == nil
        or vehicle.getMotorState == nil then

        return
    end


    local rootVehicle =
        self:getVehicleRoot(
            vehicle
        )


    local ignitionState =
        g_ignitionLockManager:getState()


    local motorState =
        vehicle:getMotorState()


    if motorState == MotorState.ON then

        vehicle.frcPreheated =
            false


        return
    end


    if ignitionState == IgnitionLockState.OFF then


        if self.preheatRootVehicle == rootVehicle
            and self.preheatFromIgnitionLock == true then

            self:
                cancelPreheat()
        end


        return
    end


    if ignitionState == IgnitionLockState.IGNITION then


        if vehicle.frcPreheated ~= true
            and self.preheatRootVehicle ~= rootVehicle then

            self:
                beginPreheat(
                    vehicle,
                    true
                )
        end


        return
    end


    if ignitionState ~= IgnitionLockState.START
        or vehicle.frcPreheated == true
        or not self:
            canPreheat(
                vehicle
            ) then

        return
    end


    if motorState == MotorState.STARTING then

        vehicle:
            setMotorState(
                MotorState.IGNITION
            )
    end


    if self.preheatRootVehicle == rootVehicle then

        self:
            cancelPreheat()
    end
end


function VehicleSystems:update(
    dt
)

    self:
        initializeLoadedDrivetrains()


    self:
        updateStoppedMotorCooling(
            dt
        )


    self:
        updateIgnitionLockPreheat()


    local vehicle =
        self.preheatVehicle


    if vehicle == nil then
        return
    end


    local currentVehicle =
        g_localPlayer ~= nil
        and g_localPlayer:getCurrentVehicle()
        or nil


    local currentRoot =
        self:getVehicleRoot(
            currentVehicle
        )


    local motorState =
        vehicle.getMotorState ~= nil
        and vehicle:getMotorState()
        or MotorState.OFF


    if currentRoot ~= self.preheatRootVehicle
        or motorState == MotorState.STARTING
        or motorState == MotorState.ON then

        self:
            cancelPreheat()

        return
    end


    self.preheatRemaining =
        self.preheatRemaining
        - dt


    if self.preheatRemaining > 0 then
        return
    end


    vehicle.frcPreheated =
        true


    self:
        cancelPreheat()


    self:
        showWarning(
            "frc_preheatComplete"
        )
end

function VehicleSystems:handleColdMotorStart(
    vehicle
)

    if not self:
        canPreheat(
            vehicle
        ) then

        return false
    end


    if vehicle.frcPreheated == true then

        vehicle.frcPreheated =
            false

        return false
    end


    if self.preheatVehicle == vehicle then

        self:
            cancelPreheat()
    end


    self:
        showWarning(
            "frc_preheatRequired"
        )


    return true
end


function VehicleSystems.actionEventToggleMotorStateWithPreheat(
    vehicle,
    superFunc,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    local motorState =
        vehicle:getMotorState()


    if (
        motorState == MotorState.OFF
        or motorState == MotorState.IGNITION
    )
        and g_VehicleSystems:
            handleColdMotorStart(
                vehicle
            ) then

        return
    end


    return superFunc(
        vehicle,
        actionName,
        inputValue,
        callbackState,
        isAnalog
    )
end


function VehicleSystems.actionEventSetMotorStateOnWithPreheat(
    vehicle,
    superFunc,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    local motorState =
        vehicle:getMotorState()


    if (
        motorState == MotorState.OFF
        or motorState == MotorState.IGNITION
    )
        and g_VehicleSystems:
            handleColdMotorStart(
                vehicle
            ) then

        return
    end


    return superFunc(
        vehicle,
        actionName,
        inputValue,
        callbackState,
        isAnalog
    )
end


function VehicleSystems.actionEventSetMotorStateIgnitionWithPreheat(
    vehicle,
    superFunc,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    local result =
        superFunc(
            vehicle,
            actionName,
            inputValue,
            callbackState,
            isAnalog
        )


    if vehicle:getMotorState() == MotorState.IGNITION
        and vehicle.frcPreheated ~= true then

        g_VehicleSystems:
            beginPreheat(
                vehicle,
                true
            )
    end


    return result
end


function VehicleSystems.actionEventSetMotorStateOffWithPreheat(
    vehicle,
    superFunc,
    actionName,
    inputValue,
    callbackState,
    isAnalog
)

    if g_VehicleSystems.preheatVehicle == vehicle then

        g_VehicleSystems:
            cancelPreheat()
    end


    return superFunc(
        vehicle,
        actionName,
        inputValue,
        callbackState,
        isAnalog
    )
end


function VehicleSystems.updateWheelsPhysics(
    vehicle,
    superFunc,
    dt,
    currentSpeed,
    acceleration,
    doHandbrake,
    stopAndGoBraking
)

    local rootVehicle =
        vehicle


    if g_VehicleSystems ~= nil then

        rootVehicle =
            g_VehicleSystems:
                getVehicleRoot(
                    vehicle
                )
            or vehicle
    end


    local handbrakeActive =
        rootVehicle ~= nil
        and rootVehicle.frcHandbrakeActive == true


    if handbrakeActive then

        doHandbrake =
            true


        acceleration =
            0
    end


    local result =
        superFunc(
            vehicle,
            dt,
            currentSpeed,
            acceleration,
            doHandbrake,
            stopAndGoBraking
        )


    if handbrakeActive
        and vehicle.brake ~= nil then

        vehicle:
            brake(
                1
            )
    end


    return result
end


function VehicleSystems.suppressHandbrakeBrakeLights(
    vehicle,
    acceleratorPedal,
    brakePedal,
    automaticBrake,
    currentSpeed
)

    local control =
        g_VehicleSystems


    if control == nil
        or vehicle == nil
        or vehicle.setBrakeLightsVisibility == nil then

        return
    end


    local rootVehicle =
        control:
            getVehicleRoot(
                vehicle
            )


    if rootVehicle ~= nil
        and rootVehicle.frcHandbrakeActive == true then

        vehicle:
            setBrakeLightsVisibility(
                false
            )
    end
end

function VehicleSystems.drawHandbrakeIcon(
    speedMeter
)

    local control =
        g_VehicleSystems


    local vehicle =
        speedMeter.vehicle


    if control == nil
        or vehicle == nil
        or not speedMeter.isVehicleDrawSafe
        or speedMeter.speedBg == nil
        or vehicle.spec_motorized == nil
        or vehicle.spec_wheels == nil then

        return
    end


    local rootVehicle =
        control:
            getVehicleRoot(
                vehicle
            )


    if rootVehicle == nil then
        return
    end


    local overlay =
        nil


    local isPreheating =
        control.preheatRootVehicle
        == rootVehicle
        and control.preheatRemaining > 0


    if isPreheating then

        overlay =
            control.preheatOverlay

    elseif rootVehicle.frcHandbrakeActive == true then

        overlay =
            control.handbrakeOverlay
    end


    if overlay == nil then
        return
    end


    if isPreheating
        and math.floor(
            g_time / 300
        ) % 2 == 1 then

        return
    end


    local posX,
          posY =
        speedMeter:getPosition()


    local width,
          height =
        speedMeter:
            scalePixelValuesToScreenVector(
                26,
                26
            )


    local gapX,
          centerOffsetY =
        speedMeter:
            scalePixelValuesToScreenVector(
                6,
                2
            )


    local iconX =
        posX
        + speedMeter.aiIconOffsetX
        - width
        - gapX


    local iconY =
        posY
        + speedMeter.aiIconOffsetY
        + centerOffsetY


    overlay:
        setDimension(
            width,
            height
        )


    overlay:
        setPosition(
            iconX,
            iconY
        )


    overlay:
        setColor(
            1,
            1,
            1,
            1
        )


    overlay:
        render()
end

function VehicleSystems.drawDrivetrainIcon(
    speedMeter
)

    local control =
        g_VehicleSystems


    local vehicle =
        speedMeter.vehicle


    if control == nil
        or vehicle == nil
        or not speedMeter.isVehicleDrawSafe
        or speedMeter.speedBg == nil then

        return
    end


    local rootVehicle =
        control:
            getVehicleRoot(
                vehicle
            )


    if rootVehicle == nil then
        return
    end


    local hasAwdInstalled =
        control:
            hasDrivetrainConfiguration(
                rootVehicle,
                VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
                true
            )


    local hasLocksInstalled =
        control:
            hasDrivetrainConfiguration(
                rootVehicle,
                VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
                true
            )


    if not hasAwdInstalled
        and not hasLocksInstalled then

        return
    end


    local posX,
          posY =
        speedMeter:getPosition()


    local width,
          height =
        speedMeter:
            scalePixelValuesToScreenVector(
                22,
                22
            )


    local gapX =
        speedMeter:
            scalePixelToScreenWidth(
                3
            )


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


    local iconX =
        gearIconX
        - width
        - gapX


    local iconY =
        gearIconY
        +
        (
            speedMeter.gearIcon.height
            - height
        )
        * 0.5


    local activeColor =
        HUD.COLOR.ACTIVE


    local inactiveColor =
        {
            1,
            1,
            1,
            1
        }


    local lockColor =
        {
            1,
            0.65,
            0,
            1
        }


    local awdActive =
        rootVehicle.frcFourWheelDriveActive
        == true


    local frontLockActive =
        rootVehicle.frcFrontDifferentialLockActive
        == true


    local rearLockActive =
        rootVehicle.frcRearDifferentialLockActive
        == true


    local function renderLayer(
        name,
        color
    )

        local overlay =
            control.drivetrainOverlays[
                name
            ]


        if overlay ~= nil then

            overlay:
                setDimension(
                    width,
                    height
                )


            overlay:
                setPosition(
                    iconX,
                    iconY
                )


            overlay:
                setColor(
                    color[1],
                    color[2],
                    color[3],
                    color[4]
                )


            overlay:
                render()
        end
    end


    renderLayer(
        "middle",
        awdActive
        and activeColor
        or inactiveColor
    )


    renderLayer(
        "front",
        frontLockActive
        and lockColor
        or inactiveColor
    )


    renderLayer(
        "rear",
        rearLockActive
        and lockColor
        or inactiveColor
    )
end

function VehicleSystems.drawEngineValues(
    speedMeter
)

    local vehicle =
        speedMeter.vehicle


    if vehicle == nil
        or not speedMeter.isVehicleDrawSafe
        or speedMeter.speedBg == nil
        or vehicle.spec_motorized == nil then

        return
    end


    local spec =
        vehicle.spec_motorized


    if spec.motorTemperature == nil
        or spec.motorTemperature.value == nil then

        return
    end


    local rpm =
        0


    if vehicle.getMotorRpmReal ~= nil then

        rpm =
            math.max(
                0,
                vehicle:
                    getMotorRpmReal()
            )
    end


    local temperature =
        spec.motorTemperature.value


    local centerX =
        speedMeter.speedBg.x
        + speedMeter.speedGaugeCenterOffsetX


    local centerY =
        speedMeter.speedBg.y
        + speedMeter.speedGaugeCenterOffsetY


    local leftX,
          valueY =
        speedMeter:
            scalePixelValuesToScreenVector(
                -56,
                -70
            )


    local rightX =
        speedMeter:
            scalePixelToScreenWidth(
                56
            )


    local unitY =
        speedMeter:
            scalePixelToScreenHeight(
                -81
            )


    local valueTextSize =
        speedMeter:
            scalePixelToScreenHeight(
                12
            )


    local unitTextSize =
        speedMeter:
            scalePixelToScreenHeight(
                8
            )


    local activeColor =
        HUD.COLOR.ACTIVE


    setTextBold(
        false
    )


    setTextAlignment(
        RenderText.ALIGN_CENTER
    )


    setTextColor(
        1,
        1,
        1,
        1
    )


    renderText(
        centerX + leftX,
        centerY + valueY,
        valueTextSize,
        string.format(
            "%d",
            math.floor(
                rpm + 0.5
            )
        )
    )


    renderText(
        centerX + rightX,
        centerY + valueY,
        valueTextSize,
        string.format(
            "%d",
            math.floor(
                temperature + 0.5
            )
        )
    )


    setTextColor(
        activeColor[1],
        activeColor[2],
        activeColor[3],
        activeColor[4]
    )


    renderText(
        centerX + leftX,
        centerY + unitY,
        unitTextSize,
        "rpm"
    )


    renderText(
        centerX + rightX,
        centerY + unitY,
        unitTextSize,
        "°C"
    )


    setTextColor(
        1,
        1,
        1,
        1
    )


    setTextAlignment(
        RenderText.ALIGN_LEFT
    )
end

function VehicleSystems.drawHudAdditions(
    speedMeter
)

    VehicleSystems.drawDrivetrainIcon(
        speedMeter
    )


    VehicleSystems.drawHandbrakeIcon(
        speedMeter
    )


    VehicleSystems.drawEngineValues(
        speedMeter
    )
end

function VehicleSystems.registerVehicleAction(
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
                vehicle.VehicleSystemsActionEvents,
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
            "VehicleSystems: action event %s could not be registered",
            tostring(
                inputAction
            )
        )
    end
end


function VehicleSystems.onRegisterActionEvents(
    vehicle,
    isActiveForInput,
    isActiveForInputIgnoreSelection
)

    if vehicle == nil
        or not vehicle.isClient then

        return
    end


    vehicle.VehicleSystemsActionEvents =
        vehicle.VehicleSystemsActionEvents
        or {}


    vehicle:
        clearActionEventsTable(
            vehicle.VehicleSystemsActionEvents
        )


    if not isActiveForInputIgnoreSelection then
        return
    end

    VehicleSystems.registerVehicleAction(
        vehicle,
        InputAction.FRC_TOGGLE_HANDBRAKE,
        VehicleSystems.actionEventHandbrake
    )

    if g_VehicleSystems:
        hasDrivetrainConfiguration(
            vehicle,
            VehicleSystems.CONFIG_FOUR_WHEEL_DRIVE,
            true
        ) then

        VehicleSystems.registerVehicleAction(
            vehicle,
            InputAction.FRC_TOGGLE_FOUR_WHEEL_DRIVE,
            VehicleSystems.actionEventFourWheelDrive
        )
    end

    if g_VehicleSystems:
        hasDrivetrainConfiguration(
            vehicle,
            VehicleSystems.CONFIG_DIFFERENTIAL_LOCKS,
            true
        ) then

        VehicleSystems.registerVehicleAction(
            vehicle,
            InputAction.FRC_TOGGLE_FRONT_DIFFERENTIAL_LOCK,
            VehicleSystems.actionEventFrontDifferentialLock,
            false,
            false,
            true
        )


        VehicleSystems.registerVehicleAction(
            vehicle,
            InputAction.FRC_TOGGLE_REAR_DIFFERENTIAL_LOCK,
            VehicleSystems.actionEventRearDifferentialLock,
            false,
            false,
            true
        )
    end

    VehicleSystems.registerVehicleAction(
        vehicle,
        InputAction.FRC_PREHEAT,
        VehicleSystems.actionEventPreheat,
        false,
        false,
        true
    )
end

function VehicleSystems.actionEventHandbrake(
    vehicle
)

    g_VehicleSystems:
        toggleHandbrake(
            vehicle
        )
end

function VehicleSystems.actionEventFourWheelDrive(
    vehicle
)

    g_VehicleSystems:
        toggleFourWheelDrive(
            vehicle
        )
end

function VehicleSystems.handleDifferentialLockInput(
    vehicle,
    inputValue,
    wantFront
)

    local heldKey =
        wantFront
        and "frcFrontDifferentialLockInputHeld"
        or "frcRearDifferentialLockInputHeld"


    local isPressed =
        math.abs(
            inputValue
        ) > 0.5


    local wasPressed =
        vehicle[
            heldKey
        ] == true


    if isPressed
        and not wasPressed then

        g_VehicleSystems:
            toggleDifferentialLock(
                vehicle,
                wantFront
            )
    end


    vehicle[
        heldKey
    ] =
        isPressed
end

function VehicleSystems.actionEventFrontDifferentialLock(
    vehicle,
    actionName,
    inputValue
)

    VehicleSystems.handleDifferentialLockInput(
        vehicle,
        inputValue,
        true
    )
end

function VehicleSystems.actionEventRearDifferentialLock(
    vehicle,
    actionName,
    inputValue
)

    VehicleSystems.handleDifferentialLockInput(
        vehicle,
        inputValue,
        false
    )
end

function VehicleSystems.actionEventPreheat(
    vehicle,
    actionName,
    inputValue
)

    local isPressed =
        math.abs(
            inputValue
        ) > 0.5


    local wasPressed =
        vehicle.frcPreheatInputHeld
        == true


    if isPressed
        and not wasPressed then

        if vehicle.frcPreheated ~= true then

            g_VehicleSystems:
                beginPreheat(
                    vehicle
                )
        end

    elseif not isPressed
        and wasPressed
        and g_VehicleSystems.preheatVehicle == vehicle
        and g_VehicleSystems.preheatFromIgnitionLock ~= true then

        g_VehicleSystems:
            cancelPreheat()
    end


    vehicle.frcPreheatInputHeld =
        isPressed
end

g_VehicleSystems =
    VehicleSystems.new()


g_VehicleSystems:
    installShopConfigurations()


addModEventListener(
    g_VehicleSystems
)
