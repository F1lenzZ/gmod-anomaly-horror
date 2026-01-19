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

    local alpha = math.Clamp(255 - (elapsed / message.duration) * 180, 50, 255)
    local jitterX = math.random(-2, 2)
    local jitterY = math.random(-2, 2)

    draw.SimpleTextOutlined(
        message.text,
        "Trebuchet24",
        ScrW() * 0.5 + jitterX,
        ScrH() * 0.2 + jitterY,
        Color(220, 40, 40, alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        2,
        Color(0, 0, 0, alpha)
    )
end)
