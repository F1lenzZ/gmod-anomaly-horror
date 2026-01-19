AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.ClientState = AnomalyHorror.ClientState or {}

local clientState = AnomalyHorror.ClientState
clientState.Intensity = 0
clientState.Phase = 1
clientState.LastGlitch = 0
clientState.HudOffset = Vector(0, 0, 0)

net.Receive("anomaly_horror_state", function()
    local elapsed = net.ReadFloat()
    clientState.Intensity = net.ReadFloat()
    clientState.Phase = net.ReadUInt(2)
    AnomalyHorror.State.SetSessionStart(RealTime() - elapsed)
end)

local function randomGlitchOffset(intensity)
    if intensity <= 0 then
        return Vector(0, 0, 0)
    end

    local magnitude = math.random(1, 4) * intensity * 6
    return Vector(math.Rand(-magnitude, magnitude), math.Rand(-magnitude, magnitude), 0)
end

hook.Add("HUDShouldDraw", "AnomalyHorrorHudGlitch", function()
    local intensity = clientState.Intensity
    if intensity <= 0 then
        return
    end

    if math.random() < 0.02 * intensity then
        return false
    end
end)

hook.Add("Think", "AnomalyHorrorGlitchThink", function()
    local intensity = clientState.Intensity
    if CurTime() - clientState.LastGlitch > math.max(0.4, 2 - intensity) then
        clientState.HudOffset = randomGlitchOffset(intensity)
        clientState.LastGlitch = CurTime()
    end
end)

hook.Add("HUDPaint", "AnomalyHorrorHudShift", function()
    if clientState.Intensity <= 0 then
        return
    end

    if clientState.HudOffset:Length() > 0 then
        surface.SetDrawColor(0, 0, 0, 0)
        surface.DrawRect(clientState.HudOffset.x, clientState.HudOffset.y, 1, 1)
    end
end)

hook.Add("RenderScreenspaceEffects", "AnomalyHorrorScreenEffects", function()
    local intensity = clientState.Intensity
    if intensity <= 0 then
        return
    end

    local phase = clientState.Phase
    local redBoost = intensity * 0.4 + (phase == 3 and 0.25 or 0)

    local colorModify = {
        ["$pp_colour_addr"] = redBoost,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.05 * intensity,
        ["$pp_colour_contrast"] = 1 + 0.2 * intensity,
        ["$pp_colour_colour"] = 1 - 0.4 * intensity,
        ["$pp_colour_mulr"] = 0.1 * intensity,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }

    DrawColorModify(colorModify)

    if math.random() < 0.15 * intensity then
        DrawSharpen(1, 0.4)
    end

    if phase >= 2 then
        DrawBloom(0.6, 1.2, 9, 9, 1, 1, 0.8, 0.1, 0.1)
    end

    if phase == 3 and math.random() < 0.05 + intensity * 0.1 then
        DrawMotionBlur(0.1, 0.8, 0.02)
    end
end)
