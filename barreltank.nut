const BARREL_HP = 50
const IGNITION_CHANCE = 5 //lower value = higher odds, 0 to disable

local SetPropInt = ::NetProps.SetPropInt.bindenv(::NetProps)
local FindByClassname = ::Entities.FindByClassname.bindenv(::Entities)

if (!IsModelPrecached("models/props_industrial/barrel_fuel.mdl"))
    PrecacheModel("models/props_industrial/barrel_fuel.mdl")

::RockEvent <- {}

::SpawnBarrel <- function(name, pos)
{
    local barrel = SpawnEntityFromTable("prop_fuel_barrel", {
        targetname = name
        model = "models/props_industrial/barrel_fuel.mdl",
        origin = pos,
        BasePiece = "models/props_industrial/barrel_fuel_parta.mdl",
        FlyingPiece01 = "models/props_industrial/barrel_fuel_partb.mdl",
        FlyingParticles = "barrel_fly",
        DetonateParticles = "weapon_pipebomb",
        DetonateSound = "BaseGrenade.Explode"
    })
    return barrel
}

::RockEvent.OnGameEvent_round_start_post_nav <- function(params)
{   
    // local world = EntIndexToHScript(0) //idk why this doesn't work
    local world = FindByClassname(null, "worldspawn")
    local rockpos = Vector(0, 0, 0)
    ::LookForRock <- function()
    {
        for (local rock; rock = FindByClassname(rock, "tank_rock");)
        {
            local rockpos = rock.GetOrigin()
            local tankid = -1
            local tank = rock.GetOwnerEntity()
            local donethrowing = false
            try
            {
                tankid = tank.GetEntityIndex()
            } catch(err) {
                
                SpawnBarrel("impactbarrel", rockpos)
                DoEntFire("impactbarrel", "Break", "", -1, null, null);
            }

            if (rock.FirstMoveChild().GetClassname() == "prop_fuel_barrel" || tankid == -1) continue
            local rockname = format("rock%d", tankid)
            local barrelname = format("barrel%d", tankid)

            rock.__KeyValueFromString("targetname", rockname)

            local barrel = SpawnBarrel(barrelname, rockpos)
            SetPropInt(barrel, "m_CollisionGroup", 1)
            barrel.SetHealth(99999999999)
            local offset = RandomInt(0, 120)
            // barrel.SetAngles(rock.GetAngles() + QAngle(offset, offset, offset))

            local rockanim = tank.GetSequence()
            local animtime = tank.GetSequenceDuration(rockanim)
            // ClientPrint(null, 3, ""+rockanim)

            //one-handed overhand
            if (rockanim == 49) { rock.SetAngles(QAngle(0, -90, 90)); barrel.SetOrigin(rock.GetOrigin() + Vector(16, 24, 0)) }
            //underhand
            else if (rockanim == 50) { rock.SetAngles(QAngle(38, -51, 38)); barrel.SetOrigin(rock.GetOrigin()) } 
            //two-handed overhand
            else if (rockanim = 51) { rock.SetAngles(QAngle(90, 0, 90)); barrel.SetOrigin(rock.GetOrigin()) }
                
            // ClientPrint(null, 3, ""+barrel.GetAngles())
            barrel.SetAngles(rock.GetAngles())

            // ClientPrint(null, 3, ""+barrel.GetMoveParent())
            DoEntFire(barrelname, "SetParent", rockname, -1, null, null)
            DoEntFire(rockname, "RunScriptCode", "DisableDraw(self)", 0.01, null, null)
            
            if (IGNITION_CHANCE > 0 && RandomInt(0, IGNITION_CHANCE) == IGNITION_CHANCE)
                DoEntFire(barrelname, "Ignite", "", animtime / 2, null, null)

            DoEntFire(barrelname, "RunScriptCode", "self.SetHealth("+BARREL_HP+")", animtime / 2, null, null)
        }
        return -1
    }
    
    world.ValidateScriptScope()
    world.GetScriptScope().LookForRock <- LookForRock
    AddThinkToEnt(world, "LookForRock")
}

::DisableDraw <- function(ent) { SetPropInt(ent, "m_nRenderMode", 10) }


Msg("Barrel Tank Loaded\n")

__CollectGameEventCallbacks(::RockEvent)