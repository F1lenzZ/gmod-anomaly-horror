AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Anomalies = AnomalyHorror.Anomalies or {}

local anomalies = AnomalyHorror.Anomalies

local function safeFindPlayerPosition(ply)
    if not IsValid(ply) then
        return Vector(0, 0, 0)
    end

    return ply:GetPos()
end

local function sendAnomalyEvent(ply, eventName, duration, severity)
    if not IsValid(ply) then
        return
    end

    net.Start("anomaly_horror_anomaly_event")
    net.WriteString(eventName)
    net.WriteFloat(duration or 0)
    net.WriteFloat(severity or 0)
    net.Send(ply)
end

local function spawnPropNear(ply)
    local config = AnomalyHorror.Config
    local center = safeFindPlayerPosition(ply)
    local offset = VectorRand() * math.random(200, 600)
    local trace = util.TraceLine({
        start = center + offset + Vector(0, 0, 300),
        endpos = center + offset - Vector(0, 0, 500),
        mask = MASK_SOLID_BRUSHONLY
    })

    local model = config.PropModels[math.random(#config.PropModels)]
    local prop = ents.Create("prop_physics")
    if not IsValid(prop) then
        return
    end

    prop:SetModel(model)
    prop:SetPos(trace.HitPos + Vector(0, 0, 10))
    prop:Spawn()
    prop:Activate()
    prop:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
end

local function spawnNpcNear(ply)
    local config = AnomalyHorror.Config
    local npcClass = config.NpcClasses[math.random(#config.NpcClasses)]
    local center = safeFindPlayerPosition(ply)
    local offset = VectorRand() * math.random(400, 700)

    local trace = util.TraceLine({
        start = center + offset + Vector(0, 0, 200),
        endpos = center + offset - Vector(0, 0, 600),
        mask = MASK_SOLID_BRUSHONLY
    })

    local npc = ents.Create(npcClass)
    if not IsValid(npc) then
        return
    end

    npc:SetPos(trace.HitPos + Vector(0, 0, 10))
    npc:Spawn()
    npc:SetSchedule(SCHED_IDLE_WANDER)
end

local function flickerLights()
    local styles = { "a", "b", "c", "d", "e", "f", "m" }
    local style = styles[math.random(#styles)]
    engine.LightStyle(0, style)

    timer.Simple(math.Rand(0.4, 1.2), function()
        engine.LightStyle(0, "m")
    end)
end

local function physicsPulse(ply)
    local center = safeFindPlayerPosition(ply)
    local entities = ents.FindInSphere(center, 900)

    for _, ent in ipairs(entities) do
        if IsValid(ent) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(VectorRand() * math.random(30000, 80000))
            end
        end
    end
end

local function consoleSpam()
    local config = AnomalyHorror.Config
    local line = config.ConsoleSpam[math.random(#config.ConsoleSpam)]
    ServerLog(line .. "\n")
end

local function soundWarp(ply)
    if not IsValid(ply) then
        return
    end

    ply:EmitSound("ambient/levels/canals/windchime2.wav", 70, math.random(60, 90))
end

local function distantSingleStep(ply)
    if not IsValid(ply) then
        return
    end

    local origin = safeFindPlayerPosition(ply)
    local offset = VectorRand():GetNormalized() * math.random(900, 1400)
    local pos = origin + offset
    sound.Play("player/footsteps/concrete1.wav", pos, 60, math.random(85, 95), 0.25)
end

local function subtlePropRotation(ply)
    if not IsValid(ply) then
        return
    end

    local props = ents.FindInSphere(ply:GetPos(), 650)
    local candidates = {}
    for _, ent in ipairs(props) do
        if IsValid(ent) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                table.insert(candidates, ent)
            end
        end
    end

    if #candidates == 0 then
        return
    end

    local prop = candidates[math.random(#candidates)]
    local current = prop:GetAngles()
    prop:SetAngles(current + Angle(math.Rand(-2, 2), math.Rand(-4, 4), 0))
end

local function npcMicroGlance(ply)
    if not IsValid(ply) then
        return
    end

    local target = nil
    local distance = math.huge
    for _, npc in ipairs(ents.FindByClass("npc_*")) do
        if IsValid(npc) then
            local dist = npc:GetPos():Distance(ply:GetPos())
            if dist < distance and dist < 700 then
                target = npc
                distance = dist
            end
        end
    end

    if not IsValid(target) then
        return
    end

    local original = target:GetAngles()
    local lookDir = (ply:EyePos() - target:EyePos()):Angle()
    target:SetAngles(Angle(original.p, lookDir.y, original.r))
    timer.Simple(0.4, function()
        if IsValid(target) then
            target:SetAngles(original)
        end
    end)
end

local function hudMicroOffset(ply)
    sendAnomalyEvent(ply, "HUDMicroOffset", 0.08, AnomalyHorror.State.GetIntensityScalar())
end

local function npcSoftFreeze(ply)
    if not IsValid(ply) then
        return
    end

    local target = nil
    local distance = math.huge
    for _, npc in ipairs(ents.FindByClass("npc_*")) do
        if IsValid(npc) then
            local dist = npc:GetPos():Distance(ply:GetPos())
            if dist < distance and dist < 850 then
                target = npc
                distance = dist
            end
        end
    end

    if not IsValid(target) then
        return
    end

    target:SetSchedule(SCHED_IDLE_STAND)
    timer.Simple(math.Rand(1, 2), function()
        if IsValid(target) then
            target:SetSchedule(SCHED_IDLE_WANDER)
        end
    end)
end

local function lightLieSmall()
    engine.LightStyle(0, "e")
    timer.Simple(0.4, function()
        engine.LightStyle(0, "m")
    end)
end

local function soundSpaceMismatch(ply)
    if not IsValid(ply) then
        return
    end

    local origin = safeFindPlayerPosition(ply)
    local offset = VectorRand():GetNormalized() * math.random(500, 900)
    local pos = origin + offset
    sound.Play("player/footsteps/wood1.wav", pos, 55, math.random(90, 110), 0.3)
end

local function propHesitation(ply)
    if not IsValid(ply) then
        return
    end

    local props = ents.FindInSphere(ply:GetPos(), 700)
    local candidates = {}
    for _, ent in ipairs(props) do
        if IsValid(ent) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                table.insert(candidates, ent)
            end
        end
    end

    if #candidates == 0 then
        return
    end

    local prop = candidates[math.random(#candidates)]
    local phys = prop:GetPhysicsObject()
    if not IsValid(phys) then
        return
    end

    for i = 1, 3 do
        timer.Simple(0.2 * i, function()
            if IsValid(phys) then
                phys:ApplyForceCenter(VectorRand() * math.random(200, 600))
            end
        end)
    end
end

local function cameraBreathTiny(ply)
    sendAnomalyEvent(ply, "CameraBreathTiny", math.Rand(1, 2), AnomalyHorror.State.GetIntensityScalar())
end

local function weaponScramble(ply)
    if not IsValid(ply) then
        return
    end

    if AnomalyHorror.State.GetPhase() < 2 then
        return
    end

    net.Start("anomaly_horror_weapon_scramble")
    net.WriteFloat(AnomalyHorror.Config.WeaponScrambleDuration)
    net.WriteFloat(AnomalyHorror.Config.WeaponScrambleInterval)
    net.Send(ply)
end

local function cameraShake(ply)
    if not IsValid(ply) then
        return
    end

    local config = AnomalyHorror.Config
    util.ScreenShake(ply:GetPos(), config.CameraShakeAmplitude, config.CameraShakeFrequency, config.CameraShakeDuration, 600)
    ply:ViewPunch(Angle(math.Rand(-4, 4), math.Rand(-6, 6), math.Rand(-2, 2)))
end

local function screenFlicker(ply)
    if not IsValid(ply) then
        return
    end

    ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 230), 0.2, 0.15)
end

local function propBurst(ply)
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local count = 1 + math.floor(intensity * 3)
    for _ = 1, count do
        spawnPropNear(ply)
    end
end

local anomalyPool = {
    function(ply)
        if math.random() < 0.5 then
            spawnPropNear(ply)
        end
    end,
    function(ply)
        if math.random() < 0.35 then
            spawnNpcNear(ply)
        end
    end,
    function()
        flickerLights()
    end,
    function(ply)
        physicsPulse(ply)
    end,
    function()
        consoleSpam()
    end,
    function(ply)
        soundWarp(ply)
    end,
    function(ply)
        if math.random() < 0.5 then
            weaponScramble(ply)
        end
    end,
    function(ply)
        if math.random() < 0.7 then
            cameraShake(ply)
        end
    end,
    function(ply)
        if math.random() < 0.6 then
            screenFlicker(ply)
        end
    end,
    function(ply)
        if math.random() < 0.4 then
            propBurst(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 1 and math.random() < 0.05 then
            distantSingleStep(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 1 and math.random() < 0.04 then
            subtlePropRotation(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 1 and math.random() < 0.05 then
            npcMicroGlance(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 1 and math.random() < 0.06 then
            hudMicroOffset(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 2 and math.random() < 0.08 then
            npcSoftFreeze(ply)
        end
    end,
    function()
        if AnomalyHorror.State.GetPhase() == 2 and math.random() < 0.06 then
            lightLieSmall()
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 2 and math.random() < 0.07 then
            soundSpaceMismatch(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 2 and math.random() < 0.07 then
            propHesitation(ply)
        end
    end,
    function(ply)
        if AnomalyHorror.State.GetPhase() == 2 and math.random() < 0.04 then
            cameraBreathTiny(ply)
        end
    end
}

function anomalies.GetNextInterval()
    local config = AnomalyHorror.Config
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local base = config.AnomalyBaseInterval
    local min = config.AnomalyMinInterval
    local interval = base - (base - min) * intensity

    return math.max(min, interval + math.Rand(-2, 4))
end

function anomalies.RunPulse(ply)
    if anomalies.SuppressUntil and CurTime() < anomalies.SuppressUntil then
        return
    end

    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local runs = 1 + math.floor(intensity * 3)

    for _ = 1, runs do
        local anomaly = anomalyPool[math.random(#anomalyPool)]
        anomaly(ply)
    end
end
