AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Director = AnomalyHorror.Director or {}

local director = AnomalyHorror.Director

util.AddNetworkString("anomaly_horror_state")
util.AddNetworkString("anomaly_horror_message")
util.AddNetworkString("anomaly_horror_weapon_scramble")
util.AddNetworkString("anomaly_horror_breakage_event")
util.AddNetworkString("anomaly_horror_anomaly_event")

function director.Start()
    AnomalyHorror.State.SetSessionStart(CurTime())
    director.NextEntityTime = CurTime() + math.Rand(20, 40)
    director.NextAnomalyPulse = CurTime() + AnomalyHorror.Config.AnomalyBaseInterval
    director.NextBreakageTime = CurTime() + AnomalyHorror.Config.QuietStartSeconds
    director.SkyPaint = director.FindOrCreateSky()
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
    sky:SetSunSize(0.3 + intensity * 0.7)
    sky:SetDuskScale(0.2 + intensity * 0.8)
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
    if #players == 0 then
        return nil
    end

    return players[math.random(#players)]
end

function director.Tick()
    director.BroadcastState()
    director.UpdateSky()

    if CurTime() >= director.NextAnomalyPulse then
        AnomalyHorror.Anomalies.RunPulse(getRandomPlayer())
        director.NextAnomalyPulse = CurTime() + AnomalyHorror.Anomalies.GetNextInterval()
    end

    if CurTime() >= director.NextBreakageTime then
        if AnomalyHorror.State.GetSessionSeconds() >= AnomalyHorror.Config.QuietStartSeconds then
            AnomalyHorror.Breakage.RunPulse(getRandomPlayer())
            director.NextBreakageTime = CurTime() + AnomalyHorror.Breakage.GetNextInterval()
        end
    end

    if CurTime() >= director.NextEntityTime then
        if AnomalyHorror.State.GetPhase() >= 2 then
            AnomalyHorror.Entity.TrySpawn(getRandomPlayer())
        end
        director.NextEntityTime = CurTime() + AnomalyHorror.Entity.GetCooldown()
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
