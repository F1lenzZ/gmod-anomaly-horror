AddCSLuaFile()

AnomalyHorror = AnomalyHorror or {}

local function includeShared(path)
    AddCSLuaFile(path)
    include(path)
end

local function includeClient(path)
    if SERVER then
        AddCSLuaFile(path)
        return
    end

    include(path)
end

includeShared("anomaly_horror/shared/config.lua")
includeShared("anomaly_horror/shared/state_machine.lua")

if SERVER then
    include("anomaly_horror/server/sv_director.lua")
    include("anomaly_horror/server/sv_anomalies.lua")
    include("anomaly_horror/server/sv_entity.lua")
else
    includeClient("anomaly_horror/client/cl_effects.lua")
    includeClient("anomaly_horror/client/cl_hud_text.lua")
end
