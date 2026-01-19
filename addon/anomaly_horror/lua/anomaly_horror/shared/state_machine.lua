AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.State = AnomalyHorror.State or {}

function AnomalyHorror.State.SetSessionStart(startTime)
    AnomalyHorror.State.SessionStart = startTime
end

function AnomalyHorror.State.GetSessionSeconds()
    local start = AnomalyHorror.State.SessionStart or CurTime()
    return math.max(0, CurTime() - start)
end

function AnomalyHorror.State.GetPhase()
    local config = AnomalyHorror.Config
    local elapsed = AnomalyHorror.State.GetSessionSeconds()

    if elapsed >= config.PhaseTimes.Late then
        return 3
    end

    if elapsed >= config.PhaseTimes.Mid then
        return 2
    end

    return 1
end

function AnomalyHorror.State.GetIntensityScalar()
    local config = AnomalyHorror.Config
    local elapsed = AnomalyHorror.State.GetSessionSeconds()
    local late = config.PhaseTimes.Late
    local scalar = math.Clamp(elapsed / late, 0, 1)

    return scalar
end
