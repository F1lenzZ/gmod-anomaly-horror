AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.HudText = AnomalyHorror.HudText or {}

local hudText = AnomalyHorror.HudText
hudText.Queue = hudText.Queue or {}
hudText.HintText = nil
hudText.HintEnd = 0
hudText.HintStart = 0

local function addMessage(text, duration)
    table.insert(hudText.Queue, {
        text = text,
        start = CurTime(),
        duration = duration or 5
    })
end

local function getFont()
    if not hudText.FontReady then
        surface.CreateFont("AnomalyHorrorMessage", {
            font = "Trebuchet MS",
            size = 32,
            weight = 800,
            antialias = true
        })
        hudText.FontReady = true
    end

    return "AnomalyHorrorMessage"
end

local function getHintFont()
    if not hudText.HintFontReady then
        surface.CreateFont("AnomalyHorrorHint", {
            font = "Trebuchet MS",
            size = 20,
            weight = 600,
            antialias = true
        })
        hudText.HintFontReady = true
    end

    return "AnomalyHorrorHint"
end

net.Receive("anomaly_horror_message", function()
    local text = net.ReadString()
    addMessage(text)
end)

hook.Add("AnomalyHorrorPhase2Marker", "AnomalyHorrorPhase2MarkerHudText", function()
    addMessage("PHASE SHIFT DETECTED.", 2.2)
end)

net.Receive("anomaly_horror_hint", function()
    local text = net.ReadString()
    local ttl = net.ReadFloat()
    hudText.HintText = text
    hudText.HintStart = CurTime()
    hudText.HintEnd = hudText.HintStart + (ttl > 0 and ttl or 2)
end)

hook.Add("HUDPaint", "AnomalyHorrorMessagePaint", function()
    if hudText.HintText and CurTime() < hudText.HintEnd then
        local now = CurTime()
        local total = math.max(0.1, hudText.HintEnd - hudText.HintStart)
        local elapsed = now - hudText.HintStart
        local fadeIn = math.Clamp(elapsed / 0.2, 0, 1)
        local fadeOut = math.Clamp((hudText.HintEnd - now) / 0.3, 0, 1)
        local alpha = math.min(fadeIn, fadeOut)
        local font = getHintFont()
        local x = ScrW() * 0.5
        local y = ScrH() * 0.72
        draw.SimpleTextOutlined(
            hudText.HintText,
            font,
            x,
            y,
            Color(200, 200, 200, 180 * alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            Color(0, 0, 0, 160 * alpha)
        )
    elseif hudText.HintText then
        hudText.HintText = nil
    end

    if #hudText.Queue == 0 then
        return
    end

    local message = hudText.Queue[1]
    local elapsed = CurTime() - message.start

    if elapsed > message.duration then
        table.remove(hudText.Queue, 1)
        return
    end

    local fade = elapsed / message.duration
    local boost = elapsed < 0.4 and 1.15 or 1
    local alpha = math.Clamp(255 - fade * 170, 80, 255)
    local jitterX = math.random(-1, 1)
    local jitterY = math.random(-1, 1)
    local font = getFont()

    surface.SetFont(font)
    local textWidth, textHeight = surface.GetTextSize(message.text)
    local boxPaddingX = 18
    local boxPaddingY = 10
    local boxWidth = textWidth + boxPaddingX * 2
    local boxHeight = textHeight + boxPaddingY * 2
    local boxX = (ScrW() - boxWidth) * 0.5 + jitterX
    local boxY = ScrH() * 0.25 - boxHeight * 0.5 + jitterY

    surface.SetDrawColor(0, 0, 0, 170)
    surface.DrawRect(boxX, boxY, boxWidth, boxHeight)

    local doubleActive = AnomalyHorror.ClientState
        and CurTime() < (AnomalyHorror.ClientState.HudDoubleEnd or 0)
    if doubleActive then
        draw.SimpleTextOutlined(
            message.text,
            font,
            ScrW() * 0.5 + jitterX + 2,
            ScrH() * 0.25 + jitterY + 2,
            Color(180, 60, 60, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            4,
            Color(0, 0, 0, alpha)
        )
    end

    draw.SimpleTextOutlined(
        message.text,
        font,
        ScrW() * 0.5 + jitterX,
        ScrH() * 0.25 + jitterY,
        Color(220 * boost, 60 * boost, 60 * boost, alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        4,
        Color(0, 0, 0, alpha)
    )
end)
