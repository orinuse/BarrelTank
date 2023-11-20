const BARREL_HP = 50
const IGNITION_CHANCE = 5 //lower value = higher odds, 0 to disable

local SetPropInt = ::NetProps.SetPropInt.bindenv(::NetProps)
local SetPropVector = ::NetProps.SetPropVector.bindenv(::NetProps)
local FindByClassname = ::Entities.FindByClassname.bindenv(::Entities)

local MODEL_BARREL = "models/props_industrial/barrel_fuel.mdl"
local MODEL_BARREL_GIB1 = "models/props_industrial/barrel_fuel_parta.mdl"
local MODEL_BARREL_GIB2 = "models/props_industrial/barrel_fuel_partb.mdl"

if (!IsModelPrecached(MODEL_BARREL))
	PrecacheModel(MODEL_BARREL)

if (!IsModelPrecached(MODEL_BARREL_GIB1))
	PrecacheModel(MODEL_BARREL_GIB1)

if (!IsModelPrecached(MODEL_BARREL_GIB2))
	PrecacheModel(MODEL_BARREL_GIB2)

::RockEvent <- {}

::SpawnBarrel <- function(name, pos, ang)
{
	local barrel = SpawnEntityFromTable("prop_fuel_barrel", {
		origin = pos,
		angles = Vector(ang.x, ang.y, ang.z),
		targetname = name
		model = MODEL_BARREL,
		BasePiece = MODEL_BARREL_GIB2, // Bottom of the barrel
		FlyingPiece01 = MODEL_BARREL_GIB1, // Top of the barrel
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
	::LookForRock <- function()
	{
		for (local rock; rock = FindByClassname(rock, "tank_rock");)
		{
			local rockpos = rock.GetOrigin()
			local rockang = rock.GetAngles()
			local tankid = -1
			local tank = rock.GetOwnerEntity()
			local donethrowing = false
			try
			{
				tankid = tank.GetEntityIndex()
			} catch(err) {
				
				SpawnBarrel("impactbarrel", rockpos, rockang)
				DoEntFire("impactbarrel", "Break", "", -1, null, null);
			}

			local moveparent = rock.GetMoveParent()

			// If our moveparent is gone, then we revert to Throw_03's offset to fix it as it floats.
			if ( moveparent == null || !moveparent.IsValid() )
				donethrowing = true


			local movechild = rock.FirstMoveChild()

			// Ignore when the first movechild of the rock is a prop_fuel_barrel or if the tank is no longer valid
			// We do this to prevent the below code from running until the barrel has left the tank.
			if ( ( movechild != null && movechild.IsValid() && movechild.GetClassname() == "prop_fuel_barrel" ) || tankid == -1 ) continue

			local rockname = format("rock%d", tankid)
			local barrelname = format("barrel%d", tankid)

			rock.__KeyValueFromString("targetname", rockname)

			local barrel = SpawnBarrel(barrelname, rockpos, rockang)
			SetPropInt(barrel, "m_CollisionGroup", 1)
			barrel.SetHealth(2147483647)

			DoEntFire(barrelname, "SetParent", rockname, -1, null, null)
			// DoEntFire(barrelname, "Enable", rockname, -1, null, null)

			local rockanim = tank.GetSequence()
			local animtime = tank.GetSequenceDuration(rockanim)
			// ClientPrint(null, 3, ""+rockanim)


			/// Update the angle of the barrel
			local offset_qangle
			local offset_vector

			if ( rockanim == tank.LookupSequence("Throw_03") || donethrowing )
			{
				offset_qangle = Vector(0, 0, 90)
				offset_vector = Vector(16, 24, 0)
			}
			else
			{
				offset_qangle = Vector(0, -90, 90)
				offset_vector = Vector(24, 0, 0)
			}

			// Final setting
			SetPropVector( barrel, "m_vecOrigin", offset_vector )
			SetPropVector( barrel, "m_angRotation", offset_qangle )
			// SetPropVector( barrel, "m_angRotation", Vector( offset_qangle.x, offset_qangle.y, offset_qangle.z ) )
			// barrel.SetAngles(offset_qangle)
			// barrel.SetOrigin(offset_vector)

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