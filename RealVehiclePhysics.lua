-- ============================================================
-- FS25_RealVehiclePhysics.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

RealVehiclePhysics = {}
RealVehiclePhysics.settings = {
    updateIntervalMs = 50,
    gravity = 9.81,
    tractorCoMRaise = 0.24,
    trailerCoMRaise = 0.22,
    loadedTrailerCoMRaise = 0.95,
    implementCoMRaise = 0.30,
    heavyImplementExtraRaise = 0.25,
    heavyImplementFullMass = 12.0,
    liftedImplementExtraRaise = 0.40,
    liftedImplementClearanceStart = 0.9,
    liftedImplementClearanceFull = 3.2,
    maxCargoSideShift = 0.42,
    maxSlopeCargoSideShift = 0.75,
    slopeForMaxCargoShift = 0.35,
    maxCargoLongShift = 0.28,
    cargoShiftResponse = 4.0,
    minimumSlope = 0.025,
    minimumTrailerMass = 2.0,
    downhillOverrunMaxKmh = 18,
    downhillOverrunFullSlope = 0.12,
    downhillOverrunMinFillRatio = 0.05,
    rolloverTriggerUpY = 0.50,
    rolloverTriggerTime = 2.0,
    rolloverResetUpY = 0.90,
    rolloverResetTime = 4.0,
    accidentSpillRatePerSecond = 0.04,
    accidentSpillMaxUpY = 0.65,
    windLossMinimumSpeedKmh = 12,
    windLossFractionPerSecond = 0.000018,
    accidentSpillPickupRadius = 12,
    towBaseCost = 1000,
    towCostPerMeter = 0.75
}

RealVehiclePhysics.states = setmetatable({}, {__mode = "k"})
RealVehiclePhysics.timer = 0
RealVehiclePhysics.activeAccident = nil
RealVehiclePhysics.accidents = {}
RealVehiclePhysics.pendingTowAccident = nil
RealVehiclePhysics.towSelectionIndex = 1
RealVehiclePhysics.towActionEventId = nil
RealVehiclePhysics.spillJobs = {}
RealVehiclePhysics.accidentSpillAreas = {}
RealVehiclePhysics.pendingResetCargo = setmetatable({}, {__mode = "k"})

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function isBigBag(vehicle)
    return vehicle ~= nil and vehicle.spec_bigBag ~= nil
end

local function isMotorVehicle(vehicle)
    return not isBigBag(vehicle) and vehicle.spec_motorized ~= nil and vehicle.spec_wheels ~= nil
        and vehicle.spec_locomotive == nil and vehicle.spec_splineVehicle == nil
        and vehicle.trainSystem == nil
end

local function isTwoWheeler(vehicle)
    return vehicle.spec_motorbike ~= nil
end

local function isCargoVehicle(vehicle)
    return not isBigBag(vehicle) and vehicle.spec_fillUnit ~= nil and vehicle.spec_attachable ~= nil
end

local function isPhysicalImplement(vehicle)
    return not isBigBag(vehicle) and vehicle.spec_attachable ~= nil and vehicle.components ~= nil
        and vehicle.spec_splineVehicle == nil and vehicle.trainSystem == nil
end

local function preservesOriginalCenterOfMass(vehicle)
    local filename = vehicle.configFileName
    if type(filename) ~= "string" then
        return false
    end
    filename = filename:gsub("\\", "/"):lower()
    return filename:match("^fs25_lsfmuniversaltrailer/universaltrailer%.xml$") ~= nil
        or filename:match("/fs25_lsfmuniversaltrailer/universaltrailer%.xml$") ~= nil
end

local function isFillUnitCovered(vehicle, fillUnitIndex)
    local spec = vehicle.spec_cover
    if spec == nil or not spec.hasCovers then
        return false
    end

    local covers = spec.fillUnitIndexToCovers ~= nil
        and spec.fillUnitIndexToCovers[fillUnitIndex] or nil
    if covers == nil or #covers == 0 then
        return false
    end

    for _, cover in ipairs(covers) do
        if spec.state == cover.index then
            return false
        end
    end
    return true
end

local function getFillRatio(vehicle)
    local spec = vehicle.spec_fillUnit
    if spec == nil or spec.fillUnits == nil then
        return 0
    end

    local level, capacity = 0, 0
    for _, fillUnit in ipairs(spec.fillUnits) do
        if fillUnit.capacity ~= nil and fillUnit.capacity > 0 then
            level = level + (fillUnit.fillLevel or 0)
            capacity = capacity + fillUnit.capacity
        end
    end
    return capacity > 0 and clamp(level / capacity, 0, 1) or 0
end

function RealVehiclePhysics:getState(vehicle)
    local state = self.states[vehicle]
    if state ~= nil then
        return state
    end

    state = {
        components = {},
        sideShift = 0,
        longShift = 0,
        previousForwardX = nil,
        previousForwardZ = nil,
        originalMaxForwardSpeed = nil,
        originalMaxBackwardSpeed = nil,
        rolloverTimer = 0,
        rolloverResetTimer = 0,
        rolloverDamaged = false,
        accidentLocked = false,
        windLossTimer = 0
    }

    if preservesOriginalCenterOfMass(vehicle) then
        self.states[vehicle] = state
        return state
    end

    local raise = self.settings.tractorCoMRaise
    if isCargoVehicle(vehicle) then
        raise = self.settings.trailerCoMRaise
    elseif isPhysicalImplement(vehicle) then
        raise = self.settings.implementCoMRaise
    end

    for _, component in ipairs(vehicle.components or {}) do
        if component.isDynamic then
            local x, y, z = getCenterOfMass(component.node)
            table.insert(state.components, {
                node = component.node,
                x = x,
                y = y,
                z = z,
                raisedY = y + raise
            })
            setCenterOfMass(component.node, x, y + raise, z)
        end
    end

    self.states[vehicle] = state
    return state
end

function RealVehiclePhysics:applyRolloverDamage(rootVehicle)
    for _, vehicle in pairs(rootVehicle.childVehicles or {}) do
        local fillSpec = vehicle.spec_fillUnit
        if vehicle ~= rootVehicle
            and isCargoVehicle(vehicle)
            and fillSpec ~= nil
            and fillSpec.fillUnits ~= nil
            and vehicle.addFillUnitFillLevel ~= nil then
            for fillUnitIndex, fillUnit in ipairs(fillSpec.fillUnits) do
                local amount = fillUnit.fillLevel or 0
                if amount > 0.001 and fillUnit.fillType ~= nil
                    and not isFillUnitCovered(vehicle, fillUnitIndex) then
                    local dischargeNode = vehicle.spec_dischargeable ~= nil
                        and vehicle.spec_dischargeable.fillUnitDischargeNodeMapping[fillUnitIndex] or nil
                    local job = {
                        rootVehicle = rootVehicle,
                        vehicle = vehicle,
                        fillUnitIndex = fillUnitIndex,
                        fillType = fillUnit.fillType,
                        total = amount,
                        remaining = amount,
                        rate = amount * self.settings.accidentSpillRatePerSecond,
                        dischargeNode = dischargeNode,
                        stalledTime = 0
                    }
                    table.insert(self.spillJobs, job)
                end
            end
        end
    end

    local state = self.states[rootVehicle]
    if state ~= nil then
        state.accidentLocked = true
    end
    if self:getIsLocallyControlled(rootVehicle) then
        self:createAccident(rootVehicle)
    end
end

function RealVehiclePhysics:hasActiveSpill(rootVehicle)
    for _, job in ipairs(self.spillJobs) do
        if job.rootVehicle == rootVehicle then
            return true
        end
    end
    return false
end

function RealVehiclePhysics:stopSpillJobs(rootVehicle)
    for index = #self.spillJobs, 1, -1 do
        local job = self.spillJobs[index]
        if job.rootVehicle == rootVehicle then
            self:stopSpillEffect(job)
            table.remove(self.spillJobs, index)
        end
    end
end

function RealVehiclePhysics:stopSpillEffect(job)
    if job.dischargeNode ~= nil and job.vehicle.setDischargeEffectActive ~= nil then
        job.vehicle:setDischargeEffectActive(job.dischargeNode, false, true)
    end
end

function RealVehiclePhysics:spillToTerrain(job, liters)
    if job.dischargeNode ~= nil and job.vehicle.dischargeToGround ~= nil then
        if job.vehicle.setDischargeEffectActive ~= nil then
            job.vehicle:setDischargeEffectActive(job.dischargeNode, false, true)
        end
        local dropped = job.vehicle:dischargeToGround(job.dischargeNode, liters)
        if math.abs(dropped or 0) > 0 and not job.accessAreaRegistered then
            local info = job.dischargeNode.info
            local node = info ~= nil and info.node or job.vehicle.rootNode
            if node ~= nil and entityExists(node) then
                local x, _, z = getWorldTranslation(node)
                table.insert(self.accidentSpillAreas, {x=x, z=z})
                job.accessAreaRegistered = true
            end
        end
        return math.abs(dropped or 0)
    end

    if not DensityMapHeightUtil.getCanTipToGround(job.fillType) then
        local removed = job.vehicle:addFillUnitFillLevel(job.vehicle:getOwnerFarmId(),
            job.fillUnitIndex, -liters, job.fillType, ToolType.UNDEFINED, nil)
        return math.abs(removed or 0)
    end

    return 0
end

function RealVehiclePhysics.shovelAccessAllowed(vehicle, superFunc, shovelNode)
    if superFunc(vehicle, shovelNode) then
        return true
    end
    if shovelNode == nil or shovelNode.node == nil then
        return false
    end

    local x, _, z = getWorldTranslation(shovelNode.node)
    local radius = RealVehiclePhysics.settings.accidentSpillPickupRadius
        + (shovelNode.width or 0) * 0.5
    for _, area in ipairs(RealVehiclePhysics.accidentSpillAreas) do
        if MathUtil.vector2Length(x - area.x, z - area.z) <= radius then
            return true
        end
    end
    return false
end

function RealVehiclePhysics:captureResetCargo(vehicle)
    if not isCargoVehicle(vehicle) or vehicle.spec_fillUnit == nil then
        return
    end
    local cargo = {}
    for index, fillUnit in ipairs(vehicle.spec_fillUnit.fillUnits or {}) do
        local amount = fillUnit.fillLevel or 0
        if amount > 0.001 and fillUnit.fillType ~= nil then
            table.insert(cargo, {index=index, amount=amount, fillType=fillUnit.fillType})
        end
    end
    if #cargo > 0 then
        self.pendingResetCargo[vehicle] = cargo
    end
end

function RealVehiclePhysics:onVehicleReset(oldVehicle, newVehicle)
    local cargo = self.pendingResetCargo[oldVehicle]
    self.pendingResetCargo[oldVehicle] = nil
    if cargo == nil or newVehicle == nil or isBigBag(newVehicle) or not newVehicle.isServer then
        return
    end
    for _, entry in ipairs(cargo) do
        local current = newVehicle:getFillUnitFillLevel(entry.index) or 0
        local missing = math.max(entry.amount - current, 0)
        if missing > 0 then
            newVehicle:addFillUnitFillLevel(newVehicle:getOwnerFarmId(), entry.index,
                missing, entry.fillType, ToolType.UNDEFINED, nil)
        end
    end
end

function RealVehiclePhysics:updateSpillJobs(dt)
    for index = #self.spillJobs, 1, -1 do
        local job = self.spillJobs[index]
        local component = job.vehicle.components ~= nil and job.vehicle.components[1] or nil
        local upY = 1
        if component ~= nil then
            local _, value, _ = localDirectionToWorld(component.node, 0, 1, 0)
            upY = value
        end

        if component == nil or upY > self.settings.accidentSpillMaxUpY then
            self:stopSpillEffect(job)
            table.remove(self.spillJobs, index)
        else
            local requested = math.min(job.remaining, job.rate * dt)
            local spilled = self:spillToTerrain(job, requested)
            job.remaining = math.max(job.remaining - spilled, 0)
            if spilled > 0 then
                job.stalledTime = 0
            else
                job.stalledTime = job.stalledTime + dt
            end

            if job.remaining <= 0.01 then
                self:stopSpillEffect(job)
                table.remove(self.spillJobs, index)
            elseif job.stalledTime >= 8.0 then
                self:stopSpillEffect(job)
                table.remove(self.spillJobs, index)
                Logging.warning("[RealVehiclePhysics] Cargo spill stopped for '%s': terrain rejected fill type %d",
                    job.vehicle:getName() or "vehicle", job.fillType)
            end
        end
    end
end

function RealVehiclePhysics:isVehicleAccidentLocked(vehicle)
    if isBigBag(vehicle) then
        return false
    end
    local rootVehicle = vehicle ~= nil and vehicle.rootVehicle or nil
    local state = rootVehicle ~= nil and self.states[rootVehicle] or nil
    return state ~= nil and state.accidentLocked == true
end

function RealVehiclePhysics:enforceAccidentLock(vehicle, state)
    if not state.accidentLocked then
        local motor = vehicle.getMotor ~= nil and vehicle:getMotor() or nil
        if motor ~= nil and state.originalMaxBackwardSpeed ~= nil then
            motor.maxBackwardSpeed = state.originalMaxBackwardSpeed
        end
        return
    end
    if vehicle.getIsMotorStarted ~= nil and vehicle:getIsMotorStarted() then
        vehicle:stopMotor()
    end
    local motor = vehicle.getMotor ~= nil and vehicle:getMotor() or nil
    if motor ~= nil then
        motor.maxForwardSpeed = 0.01
        motor.maxBackwardSpeed = 0.01
    end
    if vehicle.spec_drivable ~= nil then
        vehicle.spec_drivable.axisForward = 0
        vehicle.spec_drivable.doHandbrake = true
    end
end

function RealVehiclePhysics.accidentDetachAllowed(vehicle, superFunc, ...)
    if RealVehiclePhysics:isVehicleAccidentLocked(vehicle) then
        return false, "Unfallfahrzeug kann vor dem Abschleppen nicht abgekuppelt werden.", true
    end
    return superFunc(vehicle, ...)
end

function RealVehiclePhysics:getIsLocallyControlled(vehicle)
    if g_localPlayer == nil or g_localPlayer.getCurrentVehicle == nil then
        return false
    end
    local currentVehicle = g_localPlayer:getCurrentVehicle()
    return currentVehicle ~= nil and currentVehicle.rootVehicle == vehicle
end

function RealVehiclePhysics:findNearestWorkshop(vehicle)
    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local bestWorkshopNode, bestDistance = nil, math.huge
    local placeables = g_currentMission.placeableSystem ~= nil
        and g_currentMission.placeableSystem.placeables or {}

    for _, placeable in pairs(placeables) do
        local workshop = placeable.spec_workshop
        local node = workshop ~= nil and placeable.rootNode or nil
        if node ~= nil and entityExists(node) then
            local x, _, z = getWorldTranslation(node)
            local distance = MathUtil.vector2Length(x - vx, z - vz)
            if distance < bestDistance then
                bestWorkshopNode, bestDistance = node, distance
            end
        end
    end

    return bestWorkshopNode, bestDistance
end

function RealVehiclePhysics:createAccident(vehicle)
    local workshopNode, distance = self:findNearestWorkshop(vehicle)
    if workshopNode == nil then
        Logging.warning("[RealVehiclePhysics] No workshop or store spawn point found")
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "Fahrzeug hatte einen Unfall. Keine Werkstatt gefunden.")
        return
    end

    for _, accident in ipairs(self.accidents) do
        if accident.vehicle == vehicle then
            return
        end
    end

    local accident = {
        vehicle = vehicle,
        distance = distance,
        cost = math.floor(self.settings.towBaseCost
            + distance * self.settings.towCostPerMeter + 0.5)
    }
    table.insert(self.accidents, accident)
    self.activeAccident = self.accidents[1]
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        "Fahrzeug hatte einen Unfall und muss zur nächsten Werkstatt abgeschleppt werden.")
    self:registerTowActionInCurrentContext(true)
end

function RealVehiclePhysics:showTowConfirmation(accident)
    self.pendingTowAccident = accident
    local text = string.format("Abschleppdienst für %s rufen?\n\nEntfernung: %.0f m\nKosten: %s",
        accident.vehicle:getName() or "Fahrzeug", accident.distance,
        g_i18n:formatMoney(accident.cost, 0, true))
    YesNoDialog.show(RealVehiclePhysics.onTowDialog, RealVehiclePhysics, text)
end

function RealVehiclePhysics:showTowSelection()
    local accidentCount = #self.accidents
    if accidentCount == 0 then
        return
    end
    local optionCount = accidentCount + 1
    self.towSelectionIndex = clamp(self.towSelectionIndex, 1, optionCount)
    if self.towSelectionIndex == optionCount then
        local text = string.format(
            "Auswahl %d von %d:\n\nZURÜCK\nKeinen Abschleppdienst rufen.\n\nJa = Auswahl schließen   Nein = weiter",
            self.towSelectionIndex, optionCount)
        YesNoDialog.show(RealVehiclePhysics.onTowSelectionDialog, RealVehiclePhysics, text)
        return
    end
    local accident = self.accidents[self.towSelectionIndex]
    local text = string.format(
        "Unfallfahrzeug %d von %d auswählen:\n\n%s\nEntfernung: %.0f m | Kosten: %s\n\nJa = auswählen   Nein = weiter",
        self.towSelectionIndex, optionCount, accident.vehicle:getName() or "Fahrzeug",
        accident.distance, g_i18n:formatMoney(accident.cost, 0, true))
    YesNoDialog.show(RealVehiclePhysics.onTowSelectionDialog, RealVehiclePhysics, text)
end

function RealVehiclePhysics:onTowSelectionDialog(yes)
    if #self.accidents == 0 then
        return
    end
    local optionCount = #self.accidents + 1
    if yes then
        if self.towSelectionIndex == optionCount then
            self.towSelectionIndex = 1
            return
        end
        self:showTowConfirmation(self.accidents[self.towSelectionIndex])
    else
        self.towSelectionIndex = self.towSelectionIndex % optionCount + 1
        self:showTowSelection()
    end
end

function RealVehiclePhysics:actionEventCallTow()
    if #self.accidents == 0 then
        return
    end
    if #self.accidents == 1 then
        self:showTowConfirmation(self.accidents[1])
    else
        self.towSelectionIndex = 1
        self:showTowSelection()
    end
end

function RealVehiclePhysics:onTowDialog(yes)
    if yes and self.pendingTowAccident ~= nil then
        local accident = self.pendingTowAccident
        self.pendingTowAccident = nil
        self:performTow(accident)
    else
        self.pendingTowAccident = nil
    end
end

function RealVehiclePhysics:performTow(accident)
    if g_client == nil or g_client:getServerConnection() == nil then
        InfoDialog.show("Der Abschleppdienst konnte keine Verbindung zum Spielserver herstellen.")
        return
    end

    local rootVehicle = accident.vehicle
    self:stopSpillJobs(rootVehicle)
    local farmId = rootVehicle:getOwnerFarmId()
    local vehicles = {rootVehicle}
    for _, vehicle in ipairs(rootVehicle:getChildVehicles()) do
        if vehicle ~= rootVehicle and not isBigBag(vehicle) then
            table.insert(vehicles, vehicle)
        end
    end
    local connection = g_client:getServerConnection()
    for _, vehicle in ipairs(vehicles) do
        self:captureResetCargo(vehicle)
        connection:sendEvent(ResetVehicleEvent.new(vehicle))
    end

    g_currentMission:addMoney(-accident.cost, farmId, MoneyType.VEHICLE_RUNNING_COSTS, true, true)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format("Abschleppdienst abgeschlossen: %s", g_i18n:formatMoney(accident.cost, 0, true)))
    local state = self.states[rootVehicle]
    if state ~= nil then
        state.accidentLocked = false
    end
    for index = #self.accidents, 1, -1 do
        if self.accidents[index] == accident then
            table.remove(self.accidents, index)
            break
        end
    end
    self.activeAccident = self.accidents[1]
    if self.towActionEventId ~= nil and #self.accidents == 0 then
        g_inputBinding:setActionEventTextVisibility(self.towActionEventId, false)
    end
end

function RealVehiclePhysics:draw()
    local accident = self.activeAccident
    if accident == nil then
        return
    end

    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextBold(true)
    setTextColor(0.95, 0.18, 0.12, 1)
    renderText(0.985, 0.895, 0.020, "FAHRZEUGUNFALL")
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    renderText(0.985, 0.871, 0.014,
        string.format("Offene Unfälle: %d   |   Werkstatt: %.0f m   |   ab %s",
            #self.accidents, accident.distance, g_i18n:formatMoney(accident.cost, 0, true)))
    renderText(0.985, 0.849, 0.014, "[NUM +] Abschleppdienst rufen")
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RealVehiclePhysics:updateRolloverDamage(vehicle, state, dt)
    if g_server == nil or vehicle.isServer == false then
        return
    end

    local component = vehicle.components ~= nil and vehicle.components[1] or nil
    if component == nil then
        return
    end

    local _, upY, _ = localDirectionToWorld(component.node, 0, 1, 0)
    if not state.rolloverDamaged then
        state.rolloverResetTimer = 0
        if upY <= self.settings.rolloverTriggerUpY then
            state.rolloverTimer = state.rolloverTimer + dt
            if state.rolloverTimer >= self.settings.rolloverTriggerTime then
                self:applyRolloverDamage(vehicle)
                state.rolloverDamaged = true
                state.rolloverTimer = 0
            end
        else
            state.rolloverTimer = 0
        end
    else
        state.rolloverTimer = 0
        if upY >= self.settings.rolloverResetUpY then
            state.rolloverResetTimer = state.rolloverResetTimer + dt
            if state.rolloverResetTimer >= self.settings.rolloverResetTime then
                state.rolloverDamaged = false
                state.rolloverResetTimer = 0
            end
        else
            state.rolloverResetTimer = 0
        end
    end
end

function RealVehiclePhysics:getPushingTrailerData(rootVehicle)
    local trailerMass, weightedLoad = 0, 0
    local rootComponent = rootVehicle.components ~= nil and rootVehicle.components[1] or nil
    if rootComponent == nil then
        return 0, 0
    end
    for _, childVehicle in ipairs(rootVehicle.childVehicles or {}) do
        if childVehicle ~= rootVehicle and isPhysicalImplement(childVehicle) then
            local component = childVehicle.components ~= nil and childVehicle.components[1] or nil
            local localZ = 0
            if component ~= nil then
                local worldX, worldY, worldZ = getWorldTranslation(component.node)
                _, _, localZ = worldToLocal(rootComponent.node, worldX, worldY, worldZ)
            end
            if localZ < -0.5 then
                local mass = childVehicle:getTotalMass(true)
                local loadFactor = isCargoVehicle(childVehicle)
                    and (0.35 + getFillRatio(childVehicle) * 0.65) or 0.55
                trailerMass = trailerMass + mass
                weightedLoad = weightedLoad + mass * loadFactor
            end
        end
    end

    local loadFactor = trailerMass > 0 and weightedLoad / trailerMass or 0
    return trailerMass, loadFactor
end

function RealVehiclePhysics:updateDownhillOverrun(vehicle, state)
    if g_server == nil or vehicle.isServer == false or vehicle.getMotor == nil then
        return
    end

    local motor = vehicle:getMotor()
    local component = vehicle.components ~= nil and vehicle.components[1] or nil
    if motor == nil or component == nil then
        return
    end

    if state.originalMaxForwardSpeed == nil then
        state.originalMaxForwardSpeed = motor.maxForwardSpeedOrigin or motor.maxForwardSpeed
        state.originalMaxBackwardSpeed = motor.maxBackwardSpeedOrigin or motor.maxBackwardSpeed
    end

    local originalSpeed = state.originalMaxForwardSpeed
    local _, slopeY, _ = localDirectionToWorld(component.node, 0, 0, 1)
    local trailerMass, fillRatio = self:getPushingTrailerData(vehicle)
    local movingForward = (vehicle.movingDirection or 0) > 0
    local isPushing = movingForward
        and slopeY < -self.settings.minimumSlope
        and trailerMass >= self.settings.minimumTrailerMass
        and fillRatio >= self.settings.downhillOverrunMinFillRatio

    if isPushing then
        local slopeFactor = clamp((-slopeY - self.settings.minimumSlope)
            / math.max(self.settings.downhillOverrunFullSlope - self.settings.minimumSlope, 0.001), 0, 1)
        local tractorMass = math.max(vehicle:getTotalMass(true), 0.1)
        local massFactor = clamp(trailerMass / tractorMass, 0, 1)
        local loadFactor = clamp(fillRatio, 0, 1)
        local extraKmh = self.settings.downhillOverrunMaxKmh
            * slopeFactor * massFactor * loadFactor
        motor.maxForwardSpeed = originalSpeed + extraKmh / 3.6
    else
        motor.maxForwardSpeed = originalSpeed
    end
end

function RealVehiclePhysics:updateWindLoss(vehicle, state, dt)
    if g_server == nil or vehicle.isServer == false or vehicle.rootVehicle == vehicle then
        return
    end

    local rootState = self.states[vehicle.rootVehicle]
    local speedKmh = vehicle.rootVehicle.getLastSpeed ~= nil
        and math.abs(vehicle.rootVehicle:getLastSpeed()) or 0
    if rootState ~= nil and rootState.accidentLocked
        or speedKmh < self.settings.windLossMinimumSpeedKmh then
        state.windLossTimer = 0
        return
    end

    local eligible = {}
    local fillSpec = vehicle.spec_fillUnit
    for fillUnitIndex, fillUnit in ipairs(fillSpec ~= nil and fillSpec.fillUnits or {}) do
        local amount = fillUnit.fillLevel or 0
        local fillType = fillUnit.fillType
        if amount > 0.001 and fillType ~= nil
            and DensityMapHeightUtil.getCanTipToGround(fillType)
            and not isFillUnitCovered(vehicle, fillUnitIndex) then
            table.insert(eligible, {
                index = fillUnitIndex,
                amount = amount,
                fillType = fillType
            })
        end
    end

    if #eligible == 0 then
        state.windLossTimer = 0
        return
    end

    state.windLossTimer = state.windLossTimer + dt
    if state.windLossTimer < 1.0 then
        return
    end
    local elapsed = state.windLossTimer
    state.windLossTimer = 0
    local speedFactor = clamp(
        (speedKmh - self.settings.windLossMinimumSpeedKmh)
            / (50 - self.settings.windLossMinimumSpeedKmh), 0.15, 1.5)
    local gustFactor = 0.35 + math.random() * 1.30

    for _, entry in ipairs(eligible) do
        local loss = entry.amount * self.settings.windLossFractionPerSecond
            * elapsed * speedFactor * gustFactor
        vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), entry.index,
            -loss, entry.fillType, ToolType.UNDEFINED, nil)
    end
end

function RealVehiclePhysics:updateCargoShift(vehicle, state, dt)
    if preservesOriginalCenterOfMass(vehicle) then
        return
    end

    local fillRatio = getFillRatio(vehicle)
    local node = vehicle.components ~= nil and vehicle.components[1] ~= nil
        and vehicle.components[1].node or nil
    if node == nil then
        return
    end

    local forwardX, _, forwardZ = localDirectionToWorld(node, 0, 0, 1)
    local _, rightY, _ = localDirectionToWorld(node, 1, 0, 0)
    local speed = (vehicle.lastSpeedReal or 0) * 1000
    local lateralAcceleration = 0

    if state.previousForwardX ~= nil and dt > 0 then
        local cross = state.previousForwardX * forwardZ - state.previousForwardZ * forwardX
        local dot = clamp(state.previousForwardX * forwardX + state.previousForwardZ * forwardZ, -1, 1)
        local yawDelta = math.atan2(cross, dot)
        lateralAcceleration = speed * yawDelta / dt
    end
    state.previousForwardX, state.previousForwardZ = forwardX, forwardZ

    local longitudinalAcceleration = vehicle.lastSpeedAcceleration or 0
    local cornerShift = clamp(-lateralAcceleration / self.settings.gravity,
        -1, 1) * self.settings.maxCargoSideShift
    local slopeMovementFactor = clamp(speed / 1.5, 0, 1)
    local slopeShift = clamp(-rightY / self.settings.slopeForMaxCargoShift,
        -1, 1) * self.settings.maxSlopeCargoSideShift * slopeMovementFactor
    local targetSide = clamp(cornerShift + slopeShift,
        -self.settings.maxSlopeCargoSideShift,
        self.settings.maxSlopeCargoSideShift) * fillRatio
    local targetLong = clamp(-longitudinalAcceleration / self.settings.gravity,
        -1, 1) * self.settings.maxCargoLongShift * fillRatio
    local response = clamp(dt * self.settings.cargoShiftResponse, 0, 1)
    state.sideShift = state.sideShift + (targetSide - state.sideShift) * response
    state.longShift = state.longShift + (targetLong - state.longShift) * response

    local cargoRaise = self.settings.trailerCoMRaise
        + self.settings.loadedTrailerCoMRaise * fillRatio

    for _, component in ipairs(state.components) do
        setCenterOfMass(component.node,
            component.x + state.sideShift,
            component.y + cargoRaise,
            component.z + state.longShift)
    end
end

function RealVehiclePhysics:updateImplementPhysics(vehicle, state)
    if preservesOriginalCenterOfMass(vehicle) then
        return
    end

    local firstComponent = vehicle.components ~= nil and vehicle.components[1] or nil
    if firstComponent == nil then
        return
    end

    local mass = math.max(vehicle:getTotalMass(true), 0)
    local massFactor = clamp(mass / self.settings.heavyImplementFullMass, 0, 1)
    local x, y, z = getWorldTranslation(firstComponent.node)
    local terrainY = getTerrainHeightAtWorldPos(g_terrainNode, x, y, z)
    local clearance = math.max(y - terrainY, 0)
    local clearanceRange = math.max(self.settings.liftedImplementClearanceFull
        - self.settings.liftedImplementClearanceStart, 0.1)
    local liftFactor = clamp((clearance - self.settings.liftedImplementClearanceStart)
        / clearanceRange, 0, 1)

    local raise = self.settings.implementCoMRaise
        + self.settings.heavyImplementExtraRaise * massFactor
        + self.settings.liftedImplementExtraRaise * liftFactor * (0.35 + 0.65 * massFactor)
    for _, component in ipairs(state.components) do
        if component.node ~= nil and entityExists(component.node) then
            setCenterOfMass(component.node, component.x, component.y + raise, component.z)
        end
    end
end

function RealVehiclePhysics:update(dt)
    if g_currentMission == nil
        or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return
    end

    self.timer = self.timer + dt
    if self.timer < self.settings.updateIntervalMs then
        return
    end

    local elapsed = self.timer / 1000
    self.timer = 0
    self:updateSpillJobs(elapsed)
    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle.components ~= nil
            and not isTwoWheeler(vehicle)
            and (isMotorVehicle(vehicle) or isCargoVehicle(vehicle) or isPhysicalImplement(vehicle)) then
            local state = self:getState(vehicle)
            if isMotorVehicle(vehicle) and vehicle.rootVehicle == vehicle then
                self:updateDownhillOverrun(vehicle, state)
                self:updateRolloverDamage(vehicle, state, elapsed)
                self:enforceAccidentLock(vehicle, state)
            elseif isCargoVehicle(vehicle) then
                self:updateWindLoss(vehicle, state, elapsed)
                self:updateCargoShift(vehicle, state, elapsed)
            elseif isPhysicalImplement(vehicle) then
                self:updateImplementPhysics(vehicle, state)
            end
        end
    end
end

function RealVehiclePhysics:loadMap()
    g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
end

function RealVehiclePhysics:registerTowActionInCurrentContext(showInHelp)
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.RVP_CALL_TOW_SERVICE,
        self, RealVehiclePhysics.actionEventCallTow, false, true, false, true)
    self.towActionEventId = eventId
    if eventId ~= nil then
        g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_RVP_CALL_TOW_SERVICE"))
        g_inputBinding:setActionEventActive(eventId, true)
        g_inputBinding:setActionEventTextVisibility(eventId, showInHelp == true)
    else
        Logging.warning("[RealVehiclePhysics] Failed to register tow action in context '%s'",
            tostring(g_inputBinding:getContextName()))
    end
end

function RealVehiclePhysics.registerGlobalPlayerActionEvents(playerInputComponent, contextName)
    if playerInputComponent.player == nil or not playerInputComponent.player.isOwner then
        return
    end

    local currentContext = g_inputBinding:getContextName()
    local targetContext = contextName or currentContext
    if currentContext ~= targetContext then
        g_inputBinding:beginActionEventsModification(targetContext)
    end

    RealVehiclePhysics:registerTowActionInCurrentContext(false)

    if currentContext ~= targetContext then
        g_inputBinding:beginActionEventsModification(currentContext)
    end
end

function RealVehiclePhysics:deleteMap()
    g_messageCenter:unsubscribeAll(self)
    for vehicle, state in pairs(self.states) do
        if state.originalMaxForwardSpeed ~= nil then
            state.originalMaxForwardSpeed = nil
        end
        for _, component in ipairs(state.components) do
            if component.node ~= nil and entityExists(component.node) then
                setCenterOfMass(component.node, component.x, component.y, component.z)
            end
        end
    end
    self.states = setmetatable({}, {__mode = "k"})
    self.activeAccident = nil
    self.accidents = {}
    self.pendingTowAccident = nil
    self.towSelectionIndex = 1
    for _, job in ipairs(self.spillJobs) do
        self:stopSpillEffect(job)
    end
    self.spillJobs = {}
    self.accidentSpillAreas = {}
    self.pendingResetCargo = setmetatable({}, {__mode = "k"})
end

addModEventListener(RealVehiclePhysics)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    RealVehiclePhysics.registerGlobalPlayerActionEvents)

Attachable.isDetachAllowed = Utils.overwrittenFunction(
    Attachable.isDetachAllowed,
    RealVehiclePhysics.accidentDetachAllowed)

Shovel.getCanShovelAtPosition = Utils.overwrittenFunction(
    Shovel.getCanShovelAtPosition,
    RealVehiclePhysics.shovelAccessAllowed)
