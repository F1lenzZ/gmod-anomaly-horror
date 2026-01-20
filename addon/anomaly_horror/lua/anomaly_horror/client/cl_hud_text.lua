AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.HudText = AnomalyHorror.HudText or {}

local hudText = AnomalyHorror.HudText
hudText.Queue = hudText.Queue or {}

local function addMessage(text)
    table.insert(hudText.Queue, {
        text = text,
        start = CurTime(),
        duration = 5
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

net.Receive("anomaly_horror_message", function()
    local text = net.ReadString()
    addMessage(text)
end)

hook.Add("HUDPaint", "AnomalyHorrorMessagePaint", function()
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
