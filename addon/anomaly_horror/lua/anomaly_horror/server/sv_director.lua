AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Director = AnomalyHorror.Director or {}

local director = AnomalyHorror.Director

util.AddNetworkString("anomaly_horror_state")
util.AddNetworkString("anomaly_horror_message")

function director.Start()
    AnomalyHorror.State.SetSessionStart(CurTime())
    director.NextEntityTime = CurTime() + math.Rand(20, 40)
    director.NextAnomalyPulse = CurTime() + AnomalyHorror.Config.AnomalyBaseInterval
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

    if CurTime() >= director.NextAnomalyPulse then
        AnomalyHorror.Anomalies.RunPulse(getRandomPlayer())
        director.NextAnomalyPulse = CurTime() + AnomalyHorror.Anomalies.GetNextInterval()
    end

    if CurTime() >= director.NextEntityTime then
        AnomalyHorror.Entity.TrySpawn(getRandomPlayer())
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
