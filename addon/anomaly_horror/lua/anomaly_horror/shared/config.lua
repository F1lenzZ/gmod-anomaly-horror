AnomalyHorror = AnomalyHorror or {}

AnomalyHorror.Config = {
    PhaseTimes = {
        Early = 0,
        Mid = 600,
        Late = 1800
    },
    UpdateInterval = 2,
    AnomalyBaseInterval = 25,
    AnomalyMinInterval = 6,
    EntityCooldownMin = 45,
    EntityCooldownMax = 110,
    EntityLifetime = 28,
    EntitySpawnDistance = { min = 450, max = 900 },
    EntityChaseSpeed = 260,
    EntityFleeSpeed = 340,
    EntityKillRange = 140,
    EntityVanishRange = 200,
    EntityStareDuration = 4,
    EntityChaseRepath = 0.4,
    EntityAggressionBoost = 0.2,
    EntityModels = {
        "models/Humans/Group01/Male_07.mdl",
        "models/Humans/Group01/Male_04.mdl",
        "models/Humans/Group01/Male_02.mdl"
    },
    EntitySounds = {
        "ambient/creatures/town_scared_breathing1.wav",
        "ambient/creatures/town_zombie_call1.wav",
        "ambient/creatures/town_child_scream1.wav",
        "ambient/atmosphere/ambience2.wav"
    },
    MessagePool = {
        "I SEE YOUR INPUT.",
        "THE MAP IS NOT YOURS ANYMORE.",
        "YOU CAN CLOSE THE GAME. IT WILL STILL BE HERE.",
        "I AM NOT AN NPC.",
        "STOP LOOKING FOR BUGS.",
        "I AM INSIDE THE MAP FILES.",
        "YOUR SAFE PLACE IS A LIE.",
        "I REMEMBER EVERY SAVE.",
        "THE LIGHTS ARE LYING.",
        "I AM LEARNING YOUR ROUTES.",
        "THIS IS NOT A SCRIPTED EVENT.",
        "DO NOT TURN AROUND.",
        "YOU ARE WALKING ON BROKEN CODE.",
        "YOUR MENU WILL NOT SAVE YOU.",
        "I AM NOW IN CONTROL OF THE TICKS.",
        "EVERY STEP IS LOGGED.",
        "THE SKY DOES NOT BELONG TO YOU."
    },
    ConsoleSpam = {
        "[ERROR] material missing: anomaly/void",
        "[WARNING] physics overflow: waking 1024 objects",
        "[ERROR] map entity index corrupted",
        "[WARNING] navmesh desync detected",
        "[ERROR] audio device reported null buffer",
        "[WARNING] memory leak suspected: render queue"
    },
    WeaponScrambleDuration = 4,
    WeaponScrambleInterval = 0.12,
    CameraShakeDuration = 2.5,
    CameraShakeAmplitude = 6,
    CameraShakeFrequency = 18,
    PropModels = {
        "models/props_c17/oildrum001.mdl",
        "models/props_junk/wood_crate001a.mdl",
        "models/props_c17/furnitureStove001a.mdl",
        "models/props_c17/furnitureTable001a.mdl",
        "models/props_c17/concrete_barrier001a.mdl",
        "models/props_junk/TrashDumpster02.mdl"
    },
    NpcClasses = {
        "npc_citizen",
        "npc_zombie",
        "npc_fastzombie",
        "npc_headcrab",
        "npc_combine_s"
    }
}
