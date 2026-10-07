-- ============================================================
-- FS25_ReverseCamera.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.1 (Kamera dreht sich nicht bei Neutral-Schaltung)
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

ReverseCamera = {}
local RC = ReverseCamera
RC.enabled = true
RC.turnSpeed = math.rad(300) 
RC.cameras = setmetatable({}, {__mode = "k"})

function RC.angleDelta(target, current)
    return (target - current + math.pi) % (2 * math.pi) - math.pi
end

function RC.restore(camera)
    local state = RC.cameras[camera]
    if state ~= nil then
        camera.rotY = state.savedY
        RC.cameras[camera] = nil
    end
end

function RC.setEnabled(enabled)
    RC.enabled = enabled == true
    if not RC.enabled then
        for camera in pairs(RC.cameras) do
            RC.restore(camera)
        end
    end
end

function RC.loadSettings()
    RC.setEnabled(true)
    RC.settingsPath = getUserProfileAppPath() .. "modSettings/FS25_AdvancedVehicleFunctions/ReverseCamera.xml"
    if fileExists(RC.settingsPath) then
        local xml = XMLFile.load("rcReverseCamera", RC.settingsPath)
        if xml ~= nil then
            RC.setEnabled(xml:getBool("reverseCamera#enabled", true))
            xml:delete()
        end
    end
end

function RC.saveSettings()
    if RC.settingsPath == nil then return end
    createFolder(getUserProfileAppPath() .. "modSettings/")
    createFolder(getUserProfileAppPath() .. "modSettings/FS25_AdvancedVehicleFunctions/")
    local xml = XMLFile.create("rcReverseCamera", RC.settingsPath, "reverseCamera")
    if xml ~= nil then
        xml:setBool("reverseCamera#enabled", RC.enabled)
        xml:save()
        xml:delete()
    else
        Logging.warning("[AdvancedVehicleFunctions] Could not save reverse camera setting")
    end
end

function RC.updateCamera(camera, dt)
    local vehicle = camera.vehicle
    local motor = vehicle ~= nil and vehicle.spec_motorized ~= nil
        and vehicle.spec_motorized.motor or nil
    local tracking = camera.allowHeadTracking and camera.headTrackingNode ~= nil
        and g_gameSettings:getValue(GameSettings.SETTING.IS_HEAD_TRACKING_ENABLED)
        and isHeadTrackingAvailable()

    if not RC.enabled or not camera.isInside or not camera.isRotatable
        or not camera.isActivated or vehicle == nil or not vehicle.isClient
        or motor == nil or camera.rotY == nil or camera.origRotY == nil
        or (vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive()) then
        RC.restore(camera)
        return
    end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then return end

    local neutral = motor:getIsInNeutral()
    local reverse = motor:getDrivingDirection() < 0 and not neutral
    local state = RC.cameras[camera]
    if state ~= nil and (state.tracking == true) ~= (tracking == true) then
        RC.restore(camera)
        state = nil
    end
    if tracking then
        if neutral then return end

        if state == nil and reverse then
            state = {savedY = camera.rotY, tracking = true, offset = 0}
            RC.cameras[camera] = state
        end
        if state ~= nil then
            local target = reverse and math.pi or 0
            local step = RC.turnSpeed * math.max(0, math.min(dt, 100)) / 1000
            local delta = target - state.offset
            state.offset = state.offset + math.max(-step, math.min(step, delta))
            if not reverse and state.offset == 0 then RC.restore(camera) end
        end
        return
    end
    if neutral then
        if state ~= nil then
            state.targetY = nil
            state.neutralHold = true
        end
        return
    end

    if reverse then
        if state == nil then
            state = {savedY = camera.rotY, reverse = true}
            RC.cameras[camera] = state
            state.targetY = camera.rotY + RC.angleDelta(camera.origRotY + math.pi, camera.rotY)
        elseif not state.reverse or state.neutralHold then
            state.reverse = true
            state.targetY = camera.rotY + RC.angleDelta(camera.origRotY + math.pi, camera.rotY)
        end
        state.neutralHold = nil
    elseif state ~= nil and state.reverse then
        state.reverse = false
        state.neutralHold = nil
        state.targetY = camera.rotY + RC.angleDelta(state.savedY, camera.rotY)
    elseif state ~= nil and state.neutralHold then
        state.neutralHold = nil
        state.targetY = camera.rotY + RC.angleDelta(state.savedY, camera.rotY)
    end

    if state == nil then return end
    local input = camera.lastInputValues
    if input ~= nil and (math.abs(input.leftRight or 0) > 0.00001
        or math.abs(input.upDown or 0) > 0.00001) then
        state.targetY = nil
        if not state.reverse then RC.cameras[camera] = nil end
        return
    end
    if state.targetY ~= nil then
        local delta = RC.angleDelta(state.targetY, camera.rotY)
        local step = RC.turnSpeed * math.max(0, math.min(dt, 100)) / 1000
        if math.abs(delta) <= step then
            camera.rotY = state.targetY
            state.targetY = nil
            if not state.reverse then
                camera.rotY = state.savedY
                RC.cameras[camera] = nil
            end
        else
            camera.rotY = camera.rotY + (delta < 0 and -step or step)
        end
    end
end

function RC.cameraUpdate(camera, superFunc, dt, ...)
    RC.updateCamera(camera, dt)
    local state = RC.cameras[camera]
    if state ~= nil and state.tracking then
        local node = camera.headTrackingNode
        local rx, ry, rz = getRotation(node)
        setRotation(node, rx, ry + state.offset, rz)
        superFunc(camera, dt, ...)
        setRotation(node, rx, ry, rz)
        return
    end
    return superFunc(camera, dt, ...)
end

function RC.cameraDeactivate(camera, superFunc, ...)
    RC.restore(camera)
    return superFunc(camera, ...)
end

function RC.cameraSave(camera, superFunc, ...)
    local state = RC.cameras[camera]
    local currentY = camera.rotY
    if state ~= nil then camera.rotY = state.savedY end
    superFunc(camera, ...)
    camera.rotY = currentY
end

function RC.onSettingsOpen(frame)
    if g_dedicatedServer ~= nil then return end
    if frame.rcReverseCameraOption == nil then
        local layout = frame.generalSettingsLayout or frame.gameSettingsLayout
        local template = frame.checkActiveSuspensionCamera
        if layout == nil or template == nil or frame.controlsList == nil then
            if not RC.warnedMenu then
                Logging.warning("[AdvancedVehicleFunctions] Reverse camera: settings layout unavailable")
                RC.warnedMenu = true
            end
            return
        end
        local headerTemplate
        for _, element in ipairs(layout.elements) do
            if element.name == "sectionHeader" then
                headerTemplate = element
                break
            end
        end
        if headerTemplate ~= nil then
            local header = headerTemplate:clone()
            header.id = "rcReverseCameraSection"
            header:setText(g_i18n:getText("rc_reverseCameraSection"))
            layout:addElement(header)
        end
        local row = template.parent:clone(layout)
        row.id = "rcReverseCameraBox"
        local option, label = row.elements[1], row.elements[2]
        frame.rcOnReverseCameraChanged = function(_, state, element)
            RC.setEnabled(element:getIsChecked())
            RC.saveSettings()
        end
        option.id = "rcReverseCameraEnabled"
        option.target = frame
        option:setCallback("onClickCallback", "rcOnReverseCameraChanged")
        option:setTexts({g_i18n:getText("ui_off"), g_i18n:getText("ui_on")})
        label:setText(g_i18n:getText("rc_reverseCameraLabel"))
        if option.elements[1] ~= nil then
            option.elements[1]:setText(g_i18n:getText("rc_reverseCameraTooltip"))
        end
        row:setVisible(true)
        row:reloadFocusHandling(true)
        frame.rcReverseCameraOption = option
        layout:invalidateLayout()
    end
    local option = frame.rcReverseCameraOption
    option.parent:updateAbsolutePosition()
    option:setElementsByName()
    option:setDisabled(false)
    option:setIsChecked(RC.enabled, true)
    option:updateSelection()
    option:update(0)
end

function RC:loadMap()
    if g_dedicatedServer ~= nil then return end
    RC.loadSettings()
end

function RC:deleteMap()
    for camera in pairs(RC.cameras) do RC.restore(camera) end
end

VehicleCamera.update = Utils.overwrittenFunction(VehicleCamera.update, RC.cameraUpdate)
VehicleCamera.onDeactivate = Utils.overwrittenFunction(VehicleCamera.onDeactivate, RC.cameraDeactivate)
VehicleCamera.saveToXMLFile = Utils.overwrittenFunction(VehicleCamera.saveToXMLFile, RC.cameraSave)
if InGameMenuSettingsFrame ~= nil then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen, RC.onSettingsOpen)
end
addModEventListener(RC)
Logging.info("[AdvancedVehicleFunctions] Optional reverse cabin camera loaded")
