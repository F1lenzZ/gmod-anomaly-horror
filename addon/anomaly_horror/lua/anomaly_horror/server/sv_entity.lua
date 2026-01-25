AnomalyHorror = AnomalyHorror or {}
AnomalyHorror.Entity = AnomalyHorror.Entity or {}

local entityController = AnomalyHorror.Entity

entityController.Current = nil
entityController.NextAllowed = 0

local function safePick(pool)
    if not pool or #pool == 0 then
        return nil
    end

    return pool[math.random(#pool)]
end

local behaviors = {
    RUN_AWAY = 1,
    HUNT = 2,
    KILL_ON_SIGHT = 3,
    STAND_AND_VANISH = 4,
    STALK = 5
}

local function pickMessage()
    local pool = AnomalyHorror.Config.MessagePool
    return safePick(pool)
end

local function pickSound()
    local pool = AnomalyHorror.Config.EntitySounds
    return safePick(pool)
end

local function pickModel()
    local pool = AnomalyHorror.Config.EntityModels
    return safePick(pool)
end

local function traceToGround(origin)
    local trace = util.TraceLine({
        start = origin + Vector(0, 0, 64),
        endpos = origin - Vector(0, 0, 256),
        mask = MASK_SOLID_BRUSHONLY
    })

    if trace.Hit then
        return trace.HitPos + Vector(0, 0, 6)
    end

    return nil
end

local function pickStalkPosition(ply)
    if not IsValid(ply) then
        return nil
    end

    local forward = ply:EyeAngles():Forward()
    local right = ply:EyeAngles():Right()
    local target = ply:GetPos()
        - forward * math.random(480, 800)
        + right * math.random(-240, 240)
    local grounded = traceToGround(target)
    if grounded then
        return grounded
    end

    local fallback = ply:GetPos() - forward * math.random(560, 720)
    return traceToGround(fallback) or fallback
end

local function getSpawnPosition(ply)
    if not IsValid(ply) then
        return nil
    end

    local config = AnomalyHorror.Config
    local forward = ply:GetForward() * -1
    local distance = math.random(config.EntitySpawnDistance.min, config.EntitySpawnDistance.max)
    local origin = ply:GetPos() + forward * distance + VectorRand() * 120
    local trace = util.TraceLine({
        start = origin + Vector(0, 0, 200),
        endpos = origin - Vector(0, 0, 800),
        mask = MASK_SOLID_BRUSHONLY
    })

    if not trace.Hit then
        return origin
    end

    return trace.HitPos + Vector(0, 0, 10)
end

local function configureEntity(ent)
    local model = pickModel()
    if not model then
        return false
    end

    ent:SetModel(model)
    ent:SetMaterial("models/debug/debugwhite")
    ent:SetColor(Color(0, 0, 0))
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:DrawShadow(false)
    ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
    ent:SetMoveType(MOVETYPE_NONE)

    return true
end

local function shouldKillOnSight(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return false
    end

    local toPlayer = ply:EyePos() - ent:GetPos()
    if toPlayer:Length() > 1200 then
        return false
    end

    local trace = util.TraceLine({
        start = ent:WorldSpaceCenter(),
        endpos = ply:EyePos(),
        filter = { ent }
    })

    return trace.Entity == ply
end

local function jitterEntity(ent)
    local jitter = Angle(math.Rand(-4, 4), math.Rand(-4, 4), 0)
    ent:SetAngles(ent:GetAngles() + jitter)
end

local function moveEntity(ent, direction, speed)
    local pos = ent:GetPos() + direction * speed
    ent:SetPos(pos)
end

local function canUseStalk()
    local phase = AnomalyHorror.State.GetPhase()
    if phase < 2 then
        return false
    end

    local intensity = AnomalyHorror.State.GetIntensityScalar()
    if (phase == 2 and intensity < 0.15) or (phase >= 3 and intensity < 0.3) then
        return false
    end

    if entityController.StalkNextAllowed and CurTime() < entityController.StalkNextAllowed then
        return false
    end

    entityController.StalkUsedByPhase = entityController.StalkUsedByPhase or {}
    local used = entityController.StalkUsedByPhase[phase] or 0
    if used >= 2 then
        return false
    end

    return true
end

local function pickBehavior()
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local roll = math.Rand(0, 1)
    local phase = AnomalyHorror.State.GetPhase()
    local phaseBonus = 0
    if phase == 2 then
        phaseBonus = 0.1
    elseif phase >= 3 then
        phaseBonus = 0.25
    end

    local aggression = math.Clamp(intensity + AnomalyHorror.Config.EntityAggressionBoost + phaseBonus, 0, 1)

    if canUseStalk() then
        local stalkChance = phase == 2 and 0.3 or 0.18
        if math.Rand(0, 1) < stalkChance then
            return behaviors.STALK
        end
    end

    if roll < 0.2 * (1 - aggression) then
        return behaviors.RUN_AWAY
    end

    if phase == 2 then
        if roll < 0.58 then
            return behaviors.STAND_AND_VANISH
        end
        if roll < 0.9 - (0.15 * (1 - aggression)) then
            return behaviors.HUNT
        end
        return behaviors.KILL_ON_SIGHT
    end

    if phase >= 3 then
        if roll < 0.5 then
            return behaviors.HUNT
        end
        if roll < 0.9 then
            return behaviors.KILL_ON_SIGHT
        end
        return behaviors.STAND_AND_VANISH
    end

    if roll < 0.7 then
        return behaviors.STAND_AND_VANISH
    end
    return behaviors.RUN_AWAY
end

function entityController.GetCooldown()
    local config = AnomalyHorror.Config
    local intensity = AnomalyHorror.State.GetIntensityScalar()
    local min = config.EntityCooldownMin
    local max = config.EntityCooldownMax

    return math.max(min, max - (max - min) * intensity + math.Rand(-10, 10))
end

function entityController.Cleanup()
    if IsValid(entityController.Current) then
        entityController.Current:Remove()
    end

    entityController.Current = nil
end

function entityController.TrySpawn(ply)
    if CurTime() < entityController.NextAllowed then
        return
    end

    if AnomalyHorror.State.GetPhase() < 2 then
        return
    end

    if not IsValid(ply) then
        return
    end

    if IsValid(entityController.Current) then
        return
    end

    local spawnPos = getSpawnPosition(ply)
    if not spawnPos then
        return
    end

    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then
        return
    end

    if not configureEntity(ent) then
        ent:Remove()
        return
    end
    ent:SetPos(spawnPos)
    ent:Spawn()
    ent:Activate()

    entityController.Current = ent
    entityController.Mode = pickBehavior()
    entityController.Target = ply
    entityController.SpawnTime = CurTime()
    entityController.LastRepath = 0
    entityController.StalkTargetPos = nil
    entityController.StalkNextUpdate = 0
    entityController.StalkFrozenUntil = nil
    entityController.StalkShiftPos = nil
    entityController.StalkReacted = nil
    entityController.StalkEndTime = nil

    if entityController.Mode == behaviors.STALK then
        entityController.StalkEndTime = CurTime() + math.Rand(12, 22)
        entityController.StalkNextAllowed = CurTime() + math.Rand(90, 150)
        entityController.StalkUsedByPhase = entityController.StalkUsedByPhase or {}
        local phase = AnomalyHorror.State.GetPhase()
        entityController.StalkUsedByPhase[phase] = (entityController.StalkUsedByPhase[phase] or 0) + 1
    end

    local soundPath = pickSound()
    if soundPath then
        ent:EmitSound(soundPath, 80, math.random(70, 100))
    end
    if AnomalyHorror.State.GetPhase() >= 2
        and not AnomalyHorror.State.InGracePeriod()
        and AnomalyHorror.State.GetSessionSeconds() >= AnomalyHorror.Config.QuietStartSeconds then
        local message = pickMessage()
        if message then
            AnomalyHorror.SendMessage(message)
        end
    end

    timer.Remove("AnomalyHorrorEntityThink")
    timer.Create("AnomalyHorrorEntityThink", 0.1, 0, function()
        entityController.Think()
    end)
end

function entityController.Vanish()
    if IsValid(entityController.Current) then
        entityController.Current:EmitSound("ambient/energy/zap1.wav", 70, 80)
        entityController.Current:Remove()
    end

    entityController.Current = nil
    entityController.Target = nil
    entityController.Mode = nil
    entityController.StalkTargetPos = nil
    entityController.StalkNextUpdate = 0
    entityController.StalkFrozenUntil = nil
    entityController.StalkShiftPos = nil
    entityController.StalkReacted = nil
    entityController.StalkEndTime = nil
    entityController.NextAllowed = CurTime() + entityController.GetCooldown()

    timer.Remove("AnomalyHorrorEntityThink")
end

function entityController.Think()
    local ent = entityController.Current
    local ply = entityController.Target
    if not IsValid(ent) or not IsValid(ply) then
        entityController.Vanish()
        return
    end

    if CurTime() - entityController.SpawnTime > AnomalyHorror.Config.EntityLifetime then
        entityController.Vanish()
        return
    end

    jitterEntity(ent)

    local direction = (ply:GetPos() - ent:GetPos()):GetNormalized()
    local distance = ent:GetPos():Distance(ply:GetPos())
    local intensity = AnomalyHorror.State.GetIntensityScalar()

    if entityController.Mode == behaviors.RUN_AWAY then
        local fleeSpeed = AnomalyHorror.Config.EntityFleeSpeed * (0.1 + intensity * 0.08)
        moveEntity(ent, direction * -1, fleeSpeed)
        if distance > 1400 then
            entityController.Vanish()
        end
    elseif entityController.Mode == behaviors.STALK then
        local phase = AnomalyHorror.State.GetPhase()
        if phase < 2 then
            entityController.Vanish()
            return
        end

        if entityController.StalkEndTime and CurTime() >= entityController.StalkEndTime then
            entityController.Vanish()
            return
        end

        if distance <= 320 then
            entityController.Vanish()
            return
        end

        local toEntity = (ent:WorldSpaceCenter() - ply:EyePos()):GetNormalized()
        local dot = ply:EyeAngles():Forward():Dot(toEntity)
        if dot > 0.88 then
            local trace = util.TraceLine({
                start = ply:EyePos(),
                endpos = ent:WorldSpaceCenter(),
                filter = { ply, ent },
                mask = MASK_SOLID_BRUSHONLY
            })
            if not trace.Hit and not entityController.StalkReacted then
                entityController.StalkReacted = true
                if math.random() < 0.7 then
                    entityController.Vanish()
                    return
                end

                entityController.StalkFrozenUntil = CurTime() + math.Rand(0.8, 1.6)
                entityController.StalkShiftPos = ent:GetPos()
                    + ply:EyeAngles():Right() * math.random(-160, 160)
            end
        end

        if entityController.StalkFrozenUntil then
            if CurTime() < entityController.StalkFrozenUntil then
                return
            end

            if entityController.StalkShiftPos then
                local grounded = traceToGround(entityController.StalkShiftPos)
                ent:SetPos(grounded or entityController.StalkShiftPos)
            end
            entityController.StalkFrozenUntil = nil
            entityController.StalkShiftPos = nil
        end

        if CurTime() >= (entityController.StalkNextUpdate or 0) then
            entityController.StalkTargetPos = pickStalkPosition(ply)
            entityController.StalkNextUpdate = CurTime() + math.Rand(0.3, 0.5)
        end

        local stalkTarget = entityController.StalkTargetPos
        if stalkTarget then
            local toTarget = stalkTarget - ent:GetPos()
            local targetDistance = toTarget:Length()
            if targetDistance > 90 then
                local stalkSpeed = math.Rand(120, 180) * 0.1
                moveEntity(ent, toTarget:GetNormalized(), stalkSpeed)
            end
        end
    elseif entityController.Mode == behaviors.HUNT then
        local chaseSpeed = AnomalyHorror.Config.EntityChaseSpeed * (0.1 + intensity * 0.1)
        if CurTime() - entityController.LastRepath >= AnomalyHorror.Config.EntityChaseRepath then
            entityController.LastRepath = CurTime()
        end

        moveEntity(ent, direction, chaseSpeed)
        if distance <= AnomalyHorror.Config.EntityKillRange then
            ply:TakeDamage(9999, ent, ent)
            entityController.Vanish()
        end
    elseif entityController.Mode == behaviors.KILL_ON_SIGHT then
        if shouldKillOnSight(ply, ent) and distance <= 900 then
            ply:TakeDamage(9999, ent, ent)
            entityController.Vanish()
        end
    elseif entityController.Mode == behaviors.STAND_AND_VANISH then
        if distance <= AnomalyHorror.Config.EntityVanishRange then
            entityController.Vanish()
        end
    end
end
