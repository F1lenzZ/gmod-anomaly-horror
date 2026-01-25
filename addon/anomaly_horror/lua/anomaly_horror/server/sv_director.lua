AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Director = AnomalyHorror.Director or {}

local director = AnomalyHorror.Director
local devCvar = CreateConVar("ah_dev", "0", FCVAR_NONE, "Enable Anomaly Horror dev utilities.")

util.AddNetworkString("anomaly_horror_state")
util.AddNetworkString("anomaly_horror_message")
util.AddNetworkString("anomaly_horror_weapon_scramble")
util.AddNetworkString("anomaly_horror_breakage_event")
util.AddNetworkString("anomaly_horror_anomaly_event")
util.AddNetworkString("anomaly_horror_phase2_marker")
util.AddNetworkString("anomaly_horror_view_nudge")
util.AddNetworkString("anomaly_horror_beat")
util.AddNetworkString("anomaly_horror_hint")

local function safePick(pool)
    if not pool or #pool == 0 then
        return nil
    end

    return pool[math.random(#pool)]
end

local function devEnabled()
    return devCvar and devCvar:GetBool()
end

local function logDevInfo()
    if not devEnabled() then
        return
    end

    local netStrings = {
        "anomaly_horror_state",
        "anomaly_horror_message",
        "anomaly_horror_weapon_scramble",
        "anomaly_horror_breakage_event",
        "anomaly_horror_anomaly_event"
    }
    ServerLog("[AnomalyHorror][DEV] net strings: " .. table.concat(netStrings, ", ") .. "\n")
    ServerLog(string.format(
        "[AnomalyHorror][DEV] sessionSeconds=%.2f intensity=%.2f phase=%d\n",
        AnomalyHorror.State.GetSessionSeconds(),
        AnomalyHorror.State.GetIntensityScalar(),
        AnomalyHorror.State.GetPhase()
    ))
end

function director.Start()
    AnomalyHorror.State.SetSessionStart(CurTime())
    director.NextEntityTime = CurTime() + math.Rand(20, 40)
    director.NextAnomalyPulse = CurTime() + AnomalyHorror.Config.QuietStartSeconds
    director.NextBreakageTime = CurTime() + AnomalyHorror.Config.QuietStartSeconds
    director.SkyPaint = director.FindOrCreateSky()
    director.LastPhase = AnomalyHorror.State.GetPhase()
    director.Phase2MarkerTriggered = director.LastPhase >= 2
    director.BeatCalmUntil = 0
    local beatState = updateBeatState()
    beatState.nextAllowedBeatTime = CurTime() + math.Rand(240, 420)
    beatState.nextAllowedByBeat.EmptyThreat = beatState.nextAllowedBeatTime
    beatState.nextAllowedByBeat.SeenButNotThere = CurTime() + math.Rand(300, 540)
    updateHintState()
    logDevInfo()
end

function director.RunBeatEmptyThreat(ply)
    if not IsValid(ply) then
        return
    end

    AnomalyHorror.Anomalies.RunBeat("EmptyThreat", ply)

    net.Start("anomaly_horror_beat")
    net.WriteString("EmptyThreat")
    net.WriteBool(false)
    net.WriteFloat(0.5)
    net.Send(ply)

    director.BeatCalmUntil = CurTime() + math.Rand(30, 60)

    if devEnabled() then
        ServerLog(string.format("[AnomalyHorror][DEV] beat EmptyThreat intensity=%.2f\n", AnomalyHorror.State.GetIntensityScalar()))
    end
end

function director.RunBeatSeenButNotThere(ply)
    if not IsValid(ply) then
        return
    end

    AnomalyHorror.Anomalies.RunBeat("SeenButNotThere", ply)
    director.BeatCalmUntil = CurTime() + math.Rand(20, 40)

    if devEnabled() then
        ServerLog(string.format("[AnomalyHorror][DEV] beat SeenButNotThere intensity=%.2f\n", AnomalyHorror.State.GetIntensityScalar()))
    end
end

function director.FindOrCreateSky()
    local sky = ents.FindByClass("env_skypaint")[1]
    if IsValid(sky) then
        return sky
    end

    local created = ents.Create("env_skypaint")
    if not IsValid(created) then
        return nil
    end

    created:Spawn()
    created:Activate()
    return created
end

function director.UpdateSky()
    local sky = director.SkyPaint
    if not IsValid(sky) then
        return
    end

    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local phase = AnomalyHorror.State.GetPhase()
    local red = 0.2
    local green = 0.3
    local blue = 0.45

    if phase >= 3 then
        local scaled = math.Clamp((intensity - 0.7) / 0.3, 0, 1)
        red = 0.18 + scaled * 0.35
        green = 0.18 - scaled * 0.12
        blue = 0.22 - scaled * 0.15
    end

    sky:SetTopColor(Vector(red, green, blue))
    sky:SetBottomColor(Vector(red * 0.6, green * 0.4, blue * 0.4))
    sky:SetSunColor(Vector(red, green, blue))
    if phase >= 3 then
        sky:SetSunSize(0.3 + intensity * 0.7)
        sky:SetDuskScale(0.2 + intensity * 0.8)
    else
        sky:SetSunSize(0.3)
        sky:SetDuskScale(0.2)
    end
end

function director.BroadcastState()
    net.Start("anomaly_horror_state")
    net.WriteFloat(AnomalyHorror.State.GetSessionSeconds())
    net.WriteFloat(AnomalyHorror.State.GetIntensityScalar())
    net.WriteUInt(AnomalyHorror.State.GetPhase(), 2)
    net.Broadcast()
end

function AnomalyHorror.SendMessage(text)
    net.Start("anomaly_horror_message")
    net.WriteString(text)
    net.Broadcast()
end

local function getRandomPlayer()
    local players = player.GetHumans()
    return safePick(players)
end

local hintPoolByPhase = {
    [1] = {
        "…did you move?",
        "hold still.",
        "wrong sound.",
        "don’t rush.",
        "something is off."
    },
    [2] = {
        "if you run, it hears you.",
        "don’t look back.",
        "stay quiet.",
        "stop moving.",
        "it’s closer than you think."
    },
    [3] = {
        "it learns.",
        "you can’t trust the quiet.",
        "it’s watching.",
        "you missed it.",
        "not a bug."
    }
}

local hintRunBias = {
    "if you run, it hears you.",
    "don’t rush."
}

local hintStillBias = {
    "hold still.",
    "stay quiet.",
    "stop moving."
}

local function updateHintState()
    director.HintState = director.HintState or {
        nextHintTime = CurTime() + math.Rand(120, 240),
        lastHintText = ""
    }

    return director.HintState
end

local function pickHintText(phase, context)
    local pool = hintPoolByPhase[phase] or hintPoolByPhase[1]
    local candidate = nil

    if context == "RUN" then
        candidate = safePick(hintRunBias) or safePick(pool)
    elseif context == "STILL" then
        candidate = safePick(hintStillBias) or safePick(pool)
    else
        candidate = safePick(pool)
    end

    if candidate then
        return candidate
    end

    return safePick(pool)
end

local function updateBeatState()
    director.BeatState = director.BeatState or {
        lastBeatTime = 0,
        nextAllowedBeatTime = CurTime(),
        nextAllowedByBeat = {},
        usedCount = {
            EmptyThreat = 0,
            SeenButNotThere = 0
        }
    }

    return director.BeatState
end

function director.Tick()
    local elapsed = AnomalyHorror.State.GetSessionSeconds()
    local phase = AnomalyHorror.State.GetPhase()
    local intensity = AnomalyHorror.State.GetIntensityScalar()

    director.BroadcastState()
    director.UpdateSky()

    if phase ~= director.LastPhase then
        if director.LastPhase == 1 and phase == 2 and not director.Phase2MarkerTriggered then
            director.Phase2MarkerTriggered = true
            local markerTarget = getRandomPlayer()
            AnomalyHorror.Breakage.TriggerPhase2Marker(markerTarget)
        end

        if phase == 2 then
            director.NextEntityTime = CurTime() + AnomalyHorror.Entity.GetCooldown()
        elseif phase == 3 then
            director.NextAnomalyPulse = CurTime() + AnomalyHorror.Anomalies.GetNextInterval()
            director.NextBreakageTime = CurTime() + AnomalyHorror.Breakage.GetNextInterval()
        end
        director.LastPhase = phase
    end

    local ply = getRandomPlayer()
    if not IsValid(ply) then
        return
    end

    local beatState = updateBeatState()
    local beatCalmActive = CurTime() < (director.BeatCalmUntil or 0)
    local hintState = updateHintState()
    local speed = ply:GetVelocity():Length()
    director.ContinuousStill = director.ContinuousStill or 0
    director.ContinuousRun = director.ContinuousRun or 0
    if speed < 20 then
        director.ContinuousStill = director.ContinuousStill + AnomalyHorror.Config.UpdateInterval
        director.ContinuousRun = 0
    elseif speed > 200 then
        director.ContinuousRun = director.ContinuousRun + AnomalyHorror.Config.UpdateInterval
        director.ContinuousStill = 0
    else
        director.ContinuousStill = 0
        director.ContinuousRun = 0
    end

    if CurTime() >= director.NextAnomalyPulse then
        if elapsed >= AnomalyHorror.Config.QuietStartSeconds and not beatCalmActive then
            AnomalyHorror.Anomalies.RunPulse(ply)
            director.NextAnomalyPulse = CurTime() + AnomalyHorror.Anomalies.GetNextInterval()
        end
    end

    if CurTime() >= director.NextBreakageTime then
        if elapsed >= AnomalyHorror.Config.QuietStartSeconds and not beatCalmActive then
            AnomalyHorror.Breakage.RunPulse(ply)
            director.NextBreakageTime = CurTime() + AnomalyHorror.Breakage.GetNextInterval()
        end
    end

    if CurTime() >= director.NextEntityTime then
        if phase >= 2 then
            AnomalyHorror.Entity.TrySpawn(ply)
        end
        director.NextEntityTime = CurTime() + AnomalyHorror.Entity.GetCooldown()
    end

    if elapsed >= AnomalyHorror.Config.QuietStartSeconds
        and (phase == 1 or phase == 2)
        and intensity > 0.05
        and CurTime() >= (beatState.nextAllowedByBeat.EmptyThreat or 0)
        and (beatState.usedCount.EmptyThreat or 0) < 2 then
        if math.random() < 0.06 then
            beatState.usedCount.EmptyThreat = (beatState.usedCount.EmptyThreat or 0) + 1
            beatState.lastBeatTime = CurTime()
            beatState.nextAllowedByBeat.EmptyThreat = CurTime() + math.Rand(240, 420)
            beatState.nextAllowedBeatTime = beatState.nextAllowedByBeat.EmptyThreat
            director.RunBeatEmptyThreat(ply)
        end
    end

    if not beatCalmActive
        and elapsed >= AnomalyHorror.Config.QuietStartSeconds
        and (phase == 2 or phase == 3)
        and intensity > 0.2
        and CurTime() >= (beatState.nextAllowedByBeat.SeenButNotThere or 0)
        and (beatState.usedCount.SeenButNotThere or 0) < 1 then
        if math.random() < 0.04 then
            beatState.usedCount.SeenButNotThere = (beatState.usedCount.SeenButNotThere or 0) + 1
            beatState.lastBeatTime = CurTime()
            beatState.nextAllowedByBeat.SeenButNotThere = CurTime() + math.Rand(300, 540)
            director.RunBeatSeenButNotThere(ply)
        end
    end

    if elapsed > AnomalyHorror.Config.QuietStartSeconds
        and not beatCalmActive
        and CurTime() >= hintState.nextHintTime then
        local context = "DEFAULT"
        if director.ContinuousStill >= 8 then
            context = "STILL"
        elseif director.ContinuousRun >= 10 then
            context = "RUN"
        end

        local hintText = pickHintText(phase, context)
        if hintText and hintText ~= hintState.lastHintText then
            local ttl = math.Rand(1.8, 2.5)
            net.Start("anomaly_horror_hint")
            net.WriteString(hintText)
            net.WriteFloat(ttl)
            net.Send(ply)
            hintState.lastHintText = hintText
            local delay = phase == 3 and math.Rand(120, 220) or math.Rand(140, 260)
            hintState.nextHintTime = CurTime() + math.max(90, delay)
        else
            hintState.nextHintTime = CurTime() + math.Rand(140, 260)
        end
    end
end

hook.Add("Initialize", "AnomalyHorrorStart", function()
    director.Start()
    timer.Create("AnomalyHorrorDirector", AnomalyHorror.Config.UpdateInterval, 0, director.Tick)
end)

hook.Add("PlayerInitialSpawn", "AnomalyHorrorSendState", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then
            return
        end

        net.Start("anomaly_horror_state")
        net.WriteFloat(AnomalyHorror.State.GetSessionSeconds())
        net.WriteFloat(AnomalyHorror.State.GetIntensityScalar())
        net.WriteUInt(AnomalyHorror.State.GetPhase(), 2)
        net.Send(ply)
    end)
end)

concommand.Add("ah_dev_force_phase", function(ply, _, args)
    if IsValid(ply) or not devEnabled() then
        return
    end

    local target = tonumber(args[1] or "")
    if not target or target < 1 or target > 3 then
        return
    end

    local config = AnomalyHorror.Config
    local elapsed = 0
    if target == 2 then
        elapsed = config.PhaseTimes.Mid + 1
    elseif target == 3 then
        elapsed = config.PhaseTimes.Late + 1
    end

    AnomalyHorror.State.SetSessionStart(CurTime() - elapsed)
end)

concommand.Add("ah_dev_force_anomaly", function(ply)
    if IsValid(ply) or not devEnabled() then
        return
    end

    local target = getRandomPlayer()
    if IsValid(target) then
        AnomalyHorror.Anomalies.RunPulse(target)
    end
end)

concommand.Add("ah_dev_force_breakage", function(ply)
    if IsValid(ply) or not devEnabled() then
        return
    end

    local target = getRandomPlayer()
    if IsValid(target) then
        AnomalyHorror.Breakage.RunPulse(target)
    end
end)

concommand.Add("ah_dev_force_entity", function(ply)
    if IsValid(ply) or not devEnabled() then
        return
    end

    local target = getRandomPlayer()
    if IsValid(target) then
        AnomalyHorror.Entity.TrySpawn(target)
    end
end)
