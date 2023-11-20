
local SetPropInt = ::NetProps.SetPropInt.bindenv(::NetProps)
local SetPropVector = ::NetProps.SetPropVector.bindenv(::NetProps)
local GetPropVector = ::NetProps.GetPropVector.bindenv(::NetProps)
local SetPropEntity = ::NetProps.SetPropEntity.bindenv(::NetProps)
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

::RockEvent.OnGameEvent_round_start_post_nav <- function(params)
{
	// local world = EntIndexToHScript(0) //idk why this doesn't work
	local worldspawn = Entities.First() // FindByClassname(null, "worldspawn")
	// Doing it this way ensures these get destroyed when the round starts
	local lastthink_rock_handle = array(2048)
	local lastthink_rock_origin = array(2048)
	local lastthink_rock_angles = array(2048)

	// Scan for any rocks in play
	::LookForRock <- function()
	{
		// Iterate over all edicts in the map
		for ( local entid = 0; entid < 2048; entid++ )
		{
			// Get a script handle from this edict.
			local rock = EntIndexToHScript( entid )
			local tank = null
			local barrel = null
			// Null it manually if it's valid but not the right entity (this edict was destroyed and a new one created before we could think again)
			if ( rock != null && rock.GetEntityHandle() != lastthink_rock_handle[entid] )
			{
				rock = null
			}

			// Was this edict in the table on the last tick, but gone now?
			if ( lastthink_rock_handle[entid] != null && rock == null )
			{
				// No, it just vanished, break a barrel here and ignore the rest of the code.

				SpawnEntityFromTable("prop_fuel_barrel", {
					origin = lastthink_rock_origin[entid],
					angles = lastthink_rock_angles[entid],
					targetname = "impactbarrel"
					model = MODEL_BARREL,
					BasePiece = MODEL_BARREL_GIB2, // Bottom of the barrel
					FlyingPiece01 = MODEL_BARREL_GIB1, // Top of the barrel
					FlyingParticles = "barrel_fly",
					DetonateParticles = "weapon_pipebomb",
					DetonateSound = "BaseGrenade.Explode"
				})

				DoEntFire("impactbarrel", "Break", "", -1, null, null) // (can we use null instead of "" ?)

				// Clear the entry so we know we already dealt with it on the next loop
				lastthink_rock_handle[entid] = null
				lastthink_rock_origin[entid] = null
				lastthink_rock_angles[entid] = null

				// Don't run the rest of this code
				continue
			}
			else if ( rock != null && rock.GetClassname() == "tank_rock" )
			{
				tank = rock.GetOwnerEntity()
				if ( lastthink_rock_handle[entid] == null )
				{
					// This rock just started existing.

					lastthink_rock_handle[entid] = rock.GetEntityHandle()

					local tankid = -1
					// If the owner entity is valid, grab its index, it's the tank.
					if ( tank != null ) tankid = tank.GetEntityIndex()

					lastthink_rock_origin[entid] = GetPropVector( rock, "m_vecOrigin" )
					lastthink_rock_angles[entid] = GetPropVector( rock, "m_angRotation" )

					local rockname = format("rock%d", tankid)
					local barrelname = format("barrel%d", tankid)

					// Fill the barrel variable with a new prop_dynamic_override
					barrel = SpawnEntityFromTable("prop_dynamic_override", {
						origin = lastthink_rock_origin[entid],
						angles = lastthink_rock_angles[entid],
						targetname = barrelname,
						parentname = rockname,
						model = MODEL_BARREL
					})

					rock.__KeyValueFromString("targetname", rockname)

					// Fire SetParent so we modify the parent->child relationship
					DoEntFire(barrelname, "SetParent", rockname, -1, null, null)
					DoEntFire(barrelname, "Enable", "", -1, null, null)
					DoEntFire(barrelname, "DisableCollision", "", -1, null, null)
					SetPropEntity( childprop, "m_hOwnerEntity", rock )

					// Do we HAVE to do it this way?
					DoEntFire(rockname, "RunScriptCode", "DisableDraw(self)", 0.01, null, null)
				}
				else
				{
					// The rock is continuing to exist.
					barrel = rock.FirstMoveChild()
				}
				// Do NOT interupt here, we'll see if the rest of the code
			}

			// No barrel? :(
			if ( barrel == null ) continue

			// We hit a valid rock entity, let's update our vectors.
			lastthink_rock_origin[entid] = GetPropVector( rock, "m_vecOrigin" )
			lastthink_rock_angles[entid] = GetPropVector( rock, "m_angRotation" )

			local tankanim = tank.GetSequence()
			local animtime = tank.GetSequenceDuration(tankanim)
			// ClientPrint(null, 3, ""+rockanim)


			/// Update the angle of the barrel
			local offset_qangle
			local offset_vector

			// When the rock has no moveparent OR the tank is playing Throw_03, we use the first vectors, otherwise use the second vectors to cover Throw_02 and Throw_04
			if ( tankanim == tank.LookupSequence("Throw_03") || rock.GetMoveParent() == null )
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
		}
		return -1
	}
	
	worldspawn.ValidateScriptScope()
	worldspawn.GetScriptScope().LookForRock <- LookForRock
	AddThinkToEnt(worldspawn, "LookForRock")
}

::DisableDraw <- function(ent) { SetPropInt(ent, "m_nRenderMode", 10) }


Msg("Barrel Tank Loaded\n")

__CollectGameEventCallbacks(::RockEvent)