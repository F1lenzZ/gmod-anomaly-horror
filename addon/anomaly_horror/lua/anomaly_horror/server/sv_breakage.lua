AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Breakage = AnomalyHorror.Breakage or {}

local breakage = AnomalyHorror.Breakage

local function getPhaseConfig(phase)
    local config = AnomalyHorror.Config
    return config.BreakageByPhase[phase] or config.BreakageByPhase[1]
end

local function pickFromPool(pool)
    return pool[math.random(#pool)]
end

local function pickCommentary(phase)
    local commentary = AnomalyHorror.Config.BreakageCommentary
    if phase == 2 then
        if math.random() < 0.7 then
            return pickFromPool(commentary.technical)
        end
        return pickFromPool(commentary.aware)
    end

    if phase == 3 then
        return pickFromPool(commentary.harsh)
    end

    return pickFromPool(commentary.technical)
end

local function canSendMessage(phase)
    if phase < 2 then
        return false
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return false
    end

    if AnomalyHorror.State.InGracePeriod() then
        return false
    end

    return true
end

local function logFakeError()
    local errors = AnomalyHorror.Config.FakeLuaErrors
    ServerLog("[ERROR] " .. pickFromPool(errors) .. "\n")
end

local function tryHudCommentary(phase, silenceChance)
    if not canSendMessage(phase) then
        return
    end

    if math.random() < silenceChance then
        return
    end

    AnomalyHorror.SendMessage(string.upper(pickCommentary(phase)))
end

local function sendBreakageEvent(ply, eventName, duration, severity)
    if not IsValid(ply) then
        return
    end

    net.Start("anomaly_horror_breakage_event")
    net.WriteString(eventName)
    net.WriteFloat(duration or 0)
    net.WriteFloat(severity or 0)
    net.Send(ply)
end

local function npcStall(ply)
    if not IsValid(ply) then
        return
    end

    local target = nil
    local distance = math.huge
    for _, npc in ipairs(ents.FindByClass("npc_*")) do
        if IsValid(npc) then
            local dist = npc:GetPos():Distance(ply:GetPos())
            if dist < distance and dist < 800 then
                target = npc
                distance = dist
            end
        end
    end

    if not IsValid(target) then
        return
    end

    target:SetSchedule(SCHED_IDLE_STAND)
    timer.Simple(1, function()
        if IsValid(target) then
            target:SetSchedule(SCHED_IDLE_WANDER)
        end
    end)
end

local function propHover(ply)
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

    phys:EnableMotion(false)
    timer.Simple(math.Rand(0.6, 1.0), function()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end)
end

local function pickEvent(phase)
    local phaseConfig = getPhaseConfig(phase)
    local events = phaseConfig.events
    if not events or #events == 0 then
        return nil
    end

    return events[math.random(#events)]
end

function breakage.GetNextInterval()
    local config = AnomalyHorror.Config
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local phase = AnomalyHorror.State.GetPhase()
    local phaseConfig = getPhaseConfig(phase)
    local min = config.BreakageCooldownMin
    local max = config.BreakageCooldownMax
    local interval = max - (max - min) * intensity
    interval = interval * (phaseConfig.frequencyMultiplier or 1)

    return math.max(min, interval + math.Rand(-3, 6))
end

function breakage.RunPulse(ply)
    if not IsValid(ply) then
        return
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return
    end

    if breakage.SuppressUntil and CurTime() < breakage.SuppressUntil then
        return
    end

    local phase = AnomalyHorror.State.GetPhase()
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local phaseConfig = getPhaseConfig(phase)
    local eventName = pickEvent(phase)
    if not eventName then
        return
    end

    if eventName == "MicroFreeze" then
        local durations = AnomalyHorror.Config.MicroFreezeDurations
        local min = durations.p1_min
        local max = durations.p1_max
        if phase == 2 then
            min = durations.p2_min
            max = durations.p2_max
        elseif phase == 3 then
            min = durations.p3_min
            max = durations.p3_max
        end
        sendBreakageEvent(ply, "MicroFreeze", math.Rand(min, max), intensity)
    elseif eventName == "SubtleSoundDesync" then
        sendBreakageEvent(ply, "SubtleSoundDesync", math.Rand(0.2, 0.5), intensity)
    elseif eventName == "MinorHudDoubleDraw" then
        sendBreakageEvent(ply, "MinorHudDoubleDraw", math.Rand(0.6, 1.2), intensity)
    elseif eventName == "ShortFreeze" then
        local durations = AnomalyHorror.Config.MicroFreezeDurations
        sendBreakageEvent(ply, "ShortFreeze", math.Rand(durations.p2_min, durations.p2_max), intensity)
        tryHudCommentary(phase, phaseConfig.silenceChance)
    elseif eventName == "FakeLuaError" then
        logFakeError()
        sendBreakageEvent(ply, "FakeLuaError", math.Rand(0.3, 0.6), intensity)
        tryHudCommentary(phase, phaseConfig.silenceChance)
    elseif eventName == "AudioActionDesync" then
        sendBreakageEvent(ply, "AudioActionDesync", math.Rand(0.4, 0.9), intensity)
    elseif eventName == "NpcStall" then
        npcStall(ply)
        sendBreakageEvent(ply, "NpcStall", 1, intensity)
    elseif eventName == "PropHover" then
        propHover(ply)
        sendBreakageEvent(ply, "PropHover", math.Rand(0.6, 1.0), intensity)
    elseif eventName == "FakeCrash" then
        local crash = AnomalyHorror.Config.FakeCrashDurations
        sendBreakageEvent(ply, "FakeCrash", math.Rand(crash.p3_min, crash.p3_max), intensity)
        tryHudCommentary(phase, phaseConfig.silenceChance)
    elseif eventName == "BlackoutPulse" then
        sendBreakageEvent(ply, "BlackoutPulse", math.Rand(0.6, 1.2), intensity)
    elseif eventName == "CausalInversion" then
        sendBreakageEvent(ply, "CausalInversion", math.Rand(1.0, 2.5), intensity)
    elseif eventName == "ControlNudge" then
        sendBreakageEvent(ply, "ControlNudge", math.Rand(0.3, 0.5), intensity)
    elseif eventName == "DelayedReaction" then
        sendBreakageEvent(ply, "DelayedReaction", math.Rand(3, 6), intensity)
    elseif eventName == "LogicFlip" then
        sendBreakageEvent(ply, "LogicFlip", math.Rand(0.4, 0.8), intensity)
    elseif eventName == "PhantomObjectFlash" then
        sendBreakageEvent(ply, "PhantomObjectFlash", 0.12, intensity)
    elseif eventName == "ShadowOffset" then
        sendBreakageEvent(ply, "ShadowOffset", math.Rand(0.6, 1.2), intensity)
    elseif eventName == "ImpossibleSoundDirection" then
        sendBreakageEvent(ply, "ImpossibleSoundDirection", math.Rand(0.4, 0.9), intensity)
    elseif eventName == "FalseCalmSpike" then
        local calmDuration = math.Rand(20, 40)
        breakage.SuppressUntil = CurTime() + calmDuration
        AnomalyHorror.Anomalies.SuppressUntil = breakage.SuppressUntil
        timer.Simple(calmDuration, function()
            if IsValid(ply) then
                sendBreakageEvent(ply, "BlackoutPulse", 0.8, intensity)
            end
        end)
    elseif eventName == "OneTimeWorldReset" then
        if breakage.WorldResetUsed then
            return
        end
        breakage.WorldResetUsed = true
        sendBreakageEvent(ply, "OneTimeWorldReset", math.Rand(2, 3), intensity)
    end

end
