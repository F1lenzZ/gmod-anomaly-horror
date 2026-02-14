AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.HudText = AnomalyHorror.HudText or {}

local hudText = AnomalyHorror.HudText
hudText.Queue = hudText.Queue or {}
hudText.HintText = nil
hudText.HintEnd = 0
hudText.HintStart = 0
hudText.MaxQueue = hudText.MaxQueue or 5
hudText.LastEnqueueText = hudText.LastEnqueueText or ""
hudText.LastEnqueueTime = hudText.LastEnqueueTime or 0

local function computeDuration(text, requested)
    if requested and requested > 0 then
        return requested
    end

    local length = text and #text or 0
    return math.Clamp(1.8 + length * 0.03, 2.0, 4.2)
end

local function addMessage(text, duration)
    if not text or text == "" then
        return
    end

    local now = CurTime()
    if text == hudText.LastEnqueueText and (now - hudText.LastEnqueueTime) < 0.4 then
        return
    end

    local totalDuration = computeDuration(text, duration)

    table.insert(hudText.Queue, {
        text = text,
        start = nil,
        duration = totalDuration,
        jitterSeed = nil
    })

    while #hudText.Queue > hudText.MaxQueue and #hudText.Queue > 1 do
        table.remove(hudText.Queue, 2)
    end

    hudText.LastEnqueueText = text
    hudText.LastEnqueueTime = now
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
    local now = CurTime()

    if hudText.HintText and now < hudText.HintEnd then
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
    if not message.start then
        message.start = now
        message.jitterSeed = tonumber(util.CRC(message.text or "")) or 1
    end

    local elapsed = now - message.start
    local totalTime = math.max(0.4, message.duration or 3)
    local fadeInTime = math.min(0.2, totalTime * 0.2)
    local fadeOutTime = math.min(0.35, totalTime * 0.35)
    local holdTime = math.max(0, totalTime - fadeInTime - fadeOutTime)

    if elapsed >= totalTime then
        table.remove(hudText.Queue, 1)
        return
    end

    local alphaFactor = 1
    if elapsed < fadeInTime then
        alphaFactor = math.Clamp(elapsed / math.max(0.01, fadeInTime), 0, 1)
    elseif elapsed > fadeInTime + holdTime then
        local fadeElapsed = elapsed - fadeInTime - holdTime
        alphaFactor = math.Clamp(1 - (fadeElapsed / math.max(0.01, fadeOutTime)), 0, 1)
    end

    local boost = elapsed < 0.4 and 1.15 or 1
    local alpha = math.Clamp(255 * alphaFactor, 0, 255)
    local seed = message.jitterSeed or 1
    local jitterX = math.sin(now * 4 + seed * 0.0001) * 1.1
    local jitterY = math.cos(now * 3.6 + seed * 0.00013) * 1.1
    local font = getFont()

    if alpha < 1 then
        return
    end

    surface.SetFont(font)
    local textWidth, textHeight = surface.GetTextSize(message.text)
    local boxPaddingX = 18
    local boxPaddingY = 10
    local boxWidth = textWidth + boxPaddingX * 2
    local boxHeight = textHeight + boxPaddingY * 2
    local boxX = (ScrW() - boxWidth) * 0.5 + jitterX
    local boxY = ScrH() * 0.25 - boxHeight * 0.5 + jitterY

    surface.SetDrawColor(0, 0, 0, 170 * alphaFactor)
    surface.DrawRect(boxX, boxY, boxWidth, boxHeight)

    local doubleActive = AnomalyHorror.ClientState
        and now < (AnomalyHorror.ClientState.HudDoubleEnd or 0)
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
