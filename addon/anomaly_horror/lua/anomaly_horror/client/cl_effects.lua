AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.ClientState = AnomalyHorror.ClientState or {}

local clientState = AnomalyHorror.ClientState
clientState.Intensity = 0
clientState.Phase = 1
clientState.LastGlitch = 0
clientState.HudOffset = Vector(0, 0, 0)
clientState.WeaponScrambleEnd = 0
clientState.BreakageFreezeEnd = 0
clientState.BreakageFreezeSeverity = 0
clientState.HudDoubleEnd = 0
clientState.HudMicroOffsetEnd = 0
clientState.HudMicroOffset = Vector(0, 0, 0)
clientState.CameraBreathEnd = 0
clientState.WorldResetEnd = 0
clientState.ShadowOffsetEnd = 0
clientState.ShadowOffset = Vector(0, 0, 0)
clientState.Phase2MarkerEnd = 0

local function safePick(pool)
    if not pool or #pool == 0 then
        return nil
    end

    return pool[math.random(#pool)]
end

net.Receive("anomaly_horror_state", function()
    local elapsed = net.ReadFloat()
    clientState.Intensity = net.ReadFloat()
    clientState.Phase = net.ReadUInt(2)
    AnomalyHorror.State.SetSessionStart(CurTime() - elapsed)
end)

local function startWeaponScramble(duration, interval)
    if duration <= 0 or interval <= 0 then
        return
    end

    clientState.WeaponScrambleEnd = CurTime() + duration

    timer.Remove("AnomalyHorrorWeaponScramble")
    timer.Create("AnomalyHorrorWeaponScramble", interval, 0, function()
        if CurTime() > clientState.WeaponScrambleEnd then
            timer.Remove("AnomalyHorrorWeaponScramble")
            return
        end

        local ply = LocalPlayer()
        if not IsValid(ply) then
            return
        end

        local weapons = ply:GetWeapons()
        if #weapons == 0 then
            return
        end

        local weapon = safePick(weapons)
        if not IsValid(weapon) then
            return
        end

        if IsValid(weapon) then
            input.SelectWeapon(weapon)
        end
    end)
end

net.Receive("anomaly_horror_weapon_scramble", function()
    local duration = net.ReadFloat()
    local interval = net.ReadFloat()
    startWeaponScramble(duration, interval)
end)

net.Receive("anomaly_horror_phase2_marker", function()
    local duration = net.ReadFloat()
    clientState.Phase2MarkerEnd = CurTime() + math.max(0.4, duration)

    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 220), 0.12, 0.05)
    ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 0), 0.18, 0)
    ply:EmitSound("ambient/levels/citadel/weapon_disintegrate1.wav", 60, 95)
    hook.Run("AnomalyHorrorPhase2Marker", duration)
end)

net.Receive("anomaly_horror_view_nudge", function()
    local pitch = net.ReadFloat()
    local yaw = net.ReadFloat()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    ply:ViewPunch(Angle(pitch, yaw, 0))
end)

net.Receive("anomaly_horror_beat", function()
    local beatName = net.ReadString()
    local hasVector = net.ReadBool()
    local phantomPos = hasVector and net.ReadVector() or nil
    local duration = net.ReadFloat()
    if beatName ~= "EmptyThreat" then
        if beatName ~= "SeenButNotThere" or not phantomPos then
            return
        end
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    if beatName == "EmptyThreat" then
        local strength = math.Clamp(duration or 0.5, 0.2, 0.8)
        ply:ViewPunch(Angle(math.Rand(-0.2, 0.2) * strength, math.Rand(-0.25, 0.25) * strength, 0))
        return
    end

    local endTime = CurTime() + math.Clamp(duration or 0.5, 0.35, 0.7)
    clientState.PhantomBeat = {
        pos = phantomPos,
        endTime = endTime,
        jitter = math.Rand(0.5, 1.4)
    }
end)

local function startBreakageFreeze(duration, severity)
    clientState.BreakageFreezeEnd = CurTime() + duration
    clientState.BreakageFreezeSeverity = math.Clamp(severity or 0.2, 0, 1)
    local ply = LocalPlayer()
    if IsValid(ply) then
        ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 180), 0.15, 0)
        ply:EmitSound("ambient/levels/canals/windchime2.wav", 60, math.random(70, 90))
    end
end

local function startHudDouble(duration)
    clientState.HudDoubleEnd = CurTime() + duration
end

local function startHudMicroOffset()
    clientState.HudMicroOffset = Vector(math.random(-2, 2), math.random(-2, 2), 0)
    clientState.HudMicroOffsetEnd = CurTime() + 0.08
end

local function startCameraBreath(duration)
    clientState.CameraBreathEnd = CurTime() + duration
    local ply = LocalPlayer()
    if IsValid(ply) then
        ply:ViewPunch(Angle(math.Rand(-0.4, 0.4), math.Rand(-0.6, 0.6), 0))
    end
end

local function startWorldReset(duration)
    local ply = LocalPlayer()
    if IsValid(ply) then
        ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 255), 0.1, duration)
        ply:EmitSound("ambient/machines/teleport1.wav", 70, 80)
    end
    clientState.WorldResetEnd = CurTime() + duration
end

local function spawnPhantomObject()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    local origin = ply:GetPos() + ply:GetForward() * math.random(180, 260) + VectorRand() * 40
    local phantom = ClientsideModel("models/props_junk/wood_crate001a.mdl")
    if not IsValid(phantom) then
        return
    end

    phantom:SetPos(origin)
    phantom:SetAngles(Angle(0, math.random(0, 360), 0))
    phantom:SetColor(Color(80, 80, 80, 200))
    phantom:SetRenderMode(RENDERMODE_TRANSALPHA)

    timer.Simple(math.Rand(0.2, 0.25), function()
        if IsValid(phantom) then
            phantom:Remove()
        end
    end)
end

local function startShadowOffset(duration)
    clientState.ShadowOffsetEnd = CurTime() + duration
    clientState.ShadowOffset = Vector(math.random(-20, 20), math.random(-20, 20), 0)
end

local function delayedSound(path, delay, pitch)
    timer.Simple(delay, function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:EmitSound(path, 65, pitch or 100)
        end
    end)
end

local function startBlackoutPulse(duration)
    local pulses = math.max(2, math.floor(duration * 3))
    for i = 1, pulses do
        timer.Simple((i - 1) * (duration / pulses), function()
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 230), 0.08, 0.05)
            end
        end)
    end
end

local function startControlNudge(duration)
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    ply:ViewPunch(Angle(math.Rand(-1.5, 1.5), math.Rand(-2, 2), 0))
    startWeaponScramble(duration, 0.15)
end

local breakageHandlers = {
    MicroFreeze = function(duration, severity)
        startBreakageFreeze(duration, severity)
        startHudDouble(duration * 1.5)
    end,
    SubtleSoundDesync = function(duration)
        delayedSound("ambient/levels/canals/windchime2.wav", duration, 90)
    end,
    MinorHudDoubleDraw = function(duration)
        startHudDouble(duration)
    end,
    ShortFreeze = function(duration, severity)
        startBreakageFreeze(duration, severity)
    end,
    FakeLuaError = function(duration, severity)
        startBreakageFreeze(duration, severity)
    end,
    AudioActionDesync = function(duration)
        delayedSound("buttons/button17.wav", duration, 90)
    end,
    NpcStall = function()
        delayedSound("ambient/levels/citadel/weapon_disintegrate1.wav", 0.2, 90)
    end,
    PropHover = function()
        delayedSound("ambient/levels/citadel/weapon_disintegrate2.wav", 0.15, 95)
    end,
    FakeCrash = function(duration)
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 255), 0.05, duration)
            ply:EmitSound("buttons/button19.wav", 75, 60)
        end
    end,
    BlackoutPulse = function(duration)
        startBlackoutPulse(duration)
    end,
    CausalInversion = function(duration)
        delayedSound("ambient/levels/labs/electric_explosion1.wav", duration, 85)
    end,
    ControlNudge = function(duration)
        startControlNudge(duration)
    end,
    DelayedReaction = function(duration)
        timer.Simple(duration, function()
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 180), 0.1, 0.05)
            end
        end)
    end,
    LogicFlip = function()
        local ply = LocalPlayer()
        if not IsValid(ply) then
            return
        end

        if ply:GetVelocity():Length2D() > 120 then
            startBreakageFreeze(0.25, 0.3)
        else
            startBlackoutPulse(0.6)
        end
    end,
    PhantomObjectFlash = function()
        spawnPhantomObject()
    end,
    ShadowOffset = function(duration)
        startShadowOffset(duration)
    end,
    ImpossibleSoundDirection = function(duration)
        local ply = LocalPlayer()
        if not IsValid(ply) then
            return
        end

        local direction = Vector(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)):GetNormalized()
        local pos = ply:GetPos() + direction * math.random(120, 240)
        sound.Play("ambient/creatures/town_scared_breathing1.wav", pos, 55, math.random(80, 95), 0.2)
        delayedSound("player/footsteps/concrete2.wav", duration, 90)
    end,
    OneTimeWorldReset = function(duration)
        startWorldReset(duration)
    end
}

net.Receive("anomaly_horror_breakage_event", function()
    local eventName = net.ReadString()
    local duration = net.ReadFloat()
    local severity = net.ReadFloat()
    local handler = breakageHandlers[eventName]
    if handler then
        handler(duration, severity)
    end
end)

local anomalyHandlers = {
    HUDMicroOffset = function()
        startHudMicroOffset()
    end,
    CameraBreathTiny = function(duration)
        startCameraBreath(duration)
    end
}

net.Receive("anomaly_horror_anomaly_event", function()
    local eventName = net.ReadString()
    local duration = net.ReadFloat()
    local severity = net.ReadFloat()
    local handler = anomalyHandlers[eventName]
    if handler then
        handler(duration, severity)
    end
end)

local function randomGlitchOffset(intensity)
    if intensity <= 0 then
        return Vector(0, 0, 0)
    end

    local magnitude = math.random(1, 4) * intensity * 6
    return Vector(math.Rand(-magnitude, magnitude), math.Rand(-magnitude, magnitude), 0)
end

hook.Add("HUDShouldDraw", "AnomalyHorrorHudGlitch", function()
    if not AnomalyHorror.State or not AnomalyHorror.Config then
        return
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return
    end

    local intensity = clientState.Intensity
    if intensity <= 0 then
        return
    end

    if math.random() < 0.02 * intensity then
        return false
    end
end)

hook.Add("Think", "AnomalyHorrorGlitchThink", function()
    if not AnomalyHorror.State or not AnomalyHorror.Config then
        return
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return
    end

    local intensity = clientState.Intensity
    if CurTime() - clientState.LastGlitch > math.max(0.4, 2 - intensity) then
        clientState.HudOffset = randomGlitchOffset(intensity)
        clientState.LastGlitch = CurTime()
    end
end)

hook.Add("HUDPaint", "AnomalyHorrorHudShift", function()
    if not AnomalyHorror.State or not AnomalyHorror.Config then
        return
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return
    end

    if clientState.Intensity <= 0 then
        return
    end

    if clientState.HudOffset:Length() > 0 then
        surface.SetDrawColor(0, 0, 0, 0)
        surface.DrawRect(clientState.HudOffset.x, clientState.HudOffset.y, 1, 1)
    end

    if CurTime() < clientState.HudMicroOffsetEnd then
        surface.SetDrawColor(0, 0, 0, 12)
        surface.DrawRect(clientState.HudMicroOffset.x, clientState.HudMicroOffset.y, ScrW(), ScrH())
    end
end)

hook.Add("RenderScreenspaceEffects", "AnomalyHorrorScreenEffects", function()
    if not AnomalyHorror.State or not AnomalyHorror.Config then
        return
    end

    if AnomalyHorror.State.GetSessionSeconds() < AnomalyHorror.Config.QuietStartSeconds then
        return
    end

    if CurTime() < clientState.WorldResetEnd then
        return
    end

    local intensity = clientState.Intensity
    if intensity <= 0 and CurTime() >= clientState.BreakageFreezeEnd then
        return
    end

    local phase = clientState.Phase
    local redBoost = 0
    local brightness = 0
    local contrast = 1
    local saturation = 1

    if phase == 2 then
        brightness = -0.05 - (intensity * 0.04)
        contrast = 1.05 + (intensity * 0.1)
        saturation = 1 - (intensity * 0.2)
    elseif phase >= 3 then
        local scaled = math.Clamp((intensity - 0.7) / 0.3, 0, 1)
        brightness = -0.08 - (scaled * 0.08)
        contrast = 1.1 + (scaled * 0.15)
        saturation = 0.8 - (scaled * 0.2)
        redBoost = 0.05 + scaled * 0.25
    end

    local mulr = 0
    if phase == 2 then
        mulr = 0.02 * intensity
    elseif phase >= 3 then
        mulr = 0.08 * intensity
    end

    local colorModify = {
        ["$pp_colour_addr"] = redBoost,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = brightness,
        ["$pp_colour_contrast"] = contrast,
        ["$pp_colour_colour"] = saturation,
        ["$pp_colour_mulr"] = mulr,
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

    if CurTime() < clientState.BreakageFreezeEnd then
        DrawMotionBlur(0.1, 0.9, 0.05 + clientState.BreakageFreezeSeverity * 0.05)
        DrawSharpen(1, 1 + clientState.BreakageFreezeSeverity)
    end

    if CurTime() < clientState.CameraBreathEnd then
        DrawMotionBlur(0.03, 0.2, 0.01)
    end

    if CurTime() < clientState.Phase2MarkerEnd then
        DrawMotionBlur(0.06, 0.25, 0.02)
    end
end)

hook.Add("PostDrawTranslucentRenderables", "AnomalyHorrorShadowOffset", function()
    local phantom = clientState.PhantomBeat
    if phantom and CurTime() < phantom.endTime then
        local screenPos = phantom.pos:ToScreen()
        if screenPos.visible then
            cam.Start2D()
            surface.SetDrawColor(0, 0, 0, 180)
            local size = 48
            local jitterX = math.sin(CurTime() * 18) * phantom.jitter * 2
            local jitterY = math.cos(CurTime() * 16) * phantom.jitter * 2
            surface.DrawRect(screenPos.x - size * 0.5 + jitterX, screenPos.y - size + jitterY, size, size * 2)
            cam.End2D()
        end
    elseif phantom then
        clientState.PhantomBeat = nil
    end

    if CurTime() >= clientState.ShadowOffsetEnd then
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    local trace = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 40),
        endpos = ply:GetPos() - Vector(0, 0, 120),
        mask = MASK_SOLID_BRUSHONLY
    })

    if not trace.Hit then
        return
    end

    render.SetColorMaterial()
    render.DrawQuadEasy(
        trace.HitPos + clientState.ShadowOffset,
        trace.HitNormal,
        40,
        40,
        Color(0, 0, 0, 120),
        ply:EyeAngles().y
    )
end)
