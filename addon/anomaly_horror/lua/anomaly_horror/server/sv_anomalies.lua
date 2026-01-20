AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Anomalies = AnomalyHorror.Anomalies or {}

local anomalies = AnomalyHorror.Anomalies

local function safeFindPlayerPosition(ply)
    if not IsValid(ply) then
        return Vector(0, 0, 0)
    end

    return ply:GetPos()
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

local function weaponScramble(ply)
    if not IsValid(ply) then
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
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local runs = 1 + math.floor(intensity * 3)

    for _ = 1, runs do
        local anomaly = anomalyPool[math.random(#anomalyPool)]
        anomaly(ply)
    end
end
