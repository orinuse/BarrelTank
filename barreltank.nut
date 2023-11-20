
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
	local lastthink_rock_onnext = array(2048)
	local lastthink_rock_flying = array(2048)

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

			// Whether or not this entity is a valid tank rock
			local is_rock = false
			if ( rock != null & rock.GetClassname() == "tank_rock" )
				is_rock = true

			// If the last think was not invalid, the current entity is not invalid, but the handles don't match, then we consider it a fail case.
			// This specifically means that between thinks, a new edict occupied this slot that doesn't match the previous one, so the rock must have been destroyed.
			// If the new entity is in fact a rock, we'll need to handle both an explosion at the old coords AND queue a new rock.
			if ( rock != null && rock.GetEntityHandle() != lastthink_rock_handle[entid] && lastthink_rock_handle[entid] != null )
			{
				// If it's not a rock, null it, whatever entity this is, it's not the correct type.
				if ( !is_rock )
					rock = null
			}

			// Was this edict in the table on the last tick, but now gone or not a rock?
			if ( lastthink_rock_handle[entid] != null && ( rock == null || !is_rock ) )
			{
				// No, it just vanished, break a barrel here and ignore the rest of the code.
				ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " breaking because it stopped existing")

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
				lastthink_rock_onnext[entid] = null
				lastthink_rock_flying[entid] = null

				// Don't run the rest of this code unless the current entity is in fact a new rock that managed to occupy this slot between thinks.
				if ( !is_rock )
				{
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " broke successfully, and the current edict is not a valid rock, halting here")
					continue
				}
				else
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " broke successfully, but the current edict is also a (different) valid rock, allowing future code")
			}

			// Is this rock valid, and in fact a rock?
			if ( is_rock )
			{
				// Yep.
				// Don't fill the tank variable yet, the OwnerEntity var may not yet be filled on the first frame.
				tank = null

				local do_update = false

				/// Fill with the relative offset of the barrel (context-specific)
				local offset_qangle
				local offset_vector
				// Instead, we'll check to see that the handle is not yet extant. If it's not, then we just started existing.
				if ( lastthink_rock_handle[entid] == null )
				{
					// This rock just started existing. We'll need to wait a frame to get data from it. have we already waited that frame?
					if ( lastthink_rock_onnext[entid] != true )
					{
						// No, set this to true so we fail this check on the next frame, and instead run the code as intended.
						lastthink_rock_onnext[entid] = true
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " delaying first spawn code & staying invalid until the next frame")
						// Don't fill the handle yet
						continue
					}
					else
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " running first spawn code")

					// We've passed the one-frame-delay check, fill stuff.
					tank = rock.GetOwnerEntity()

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
					SetPropEntity( barrel, "m_hOwnerEntity", rock )

					// Don't render the rock
					SetPropInt( rock, "m_nRenderMode", 10 )

					do_update = true
					if ( tank.GetSequence() == tank.LookupSequence("Throw_03") )
					{
						offset_qangle = Vector(0, 0, 90)
						offset_vector = Vector(16, 24, 0)
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " using Throw_03 offset")
					}
					else
					{
						offset_qangle = Vector(0, -90, 90)
						offset_vector = Vector(24, 0, 0)
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " using Throw_02/Throw_04 offset")
					}
				}
				else if ( lastthink_rock_handle[entid] == rock.GetEntityHandle() )
				{
					// The rock is continuing to exist, so we'll just grab its info.
					barrel = rock.FirstMoveChild()
					tank = rock.GetOwnerEntity()
				}
				else
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "WARNING: Logical error in BarrelRock " + rock.GetEntityIndex() + ": Last think handle ID does not match current handle ID, skill issue tbh")

				// Wait for the rock to have no moveparent.
				// Once it loses its moveparent, we'll update lastthink_rock_flying[entid] to true so we don't keep running this code over and over while it's flying (since there'd be no real reason to do that)
				// This effectively acts like a 
				if ( rock.GetMoveParent() == null )
				{
					// We hit a valid flying rock entity, let's update its vectors.
					lastthink_rock_origin[entid] = GetPropVector( rock, "m_vecOrigin" )
					lastthink_rock_angles[entid] = GetPropVector( rock, "m_angRotation" )
					
					if ( lastthink_rock_flying[entid] != true )
					{
						lastthink_rock_flying[entid] = true

						if ( barrel == null )
						{
							ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "WARNING: BarrelRock " + rock.GetEntityIndex() + " released & had no valid barrel to update the offset of, for some reason")
							continue
						}
						else
							ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "SUCCESS: BarrelRock " + rock.GetEntityIndex() + " released & had a valid barrel to update the offset of")


						// ClientPrint(null, 3, ""+rockanim)

						// When the rock has no moveparent, we'll use this vector.

						do_update = true

						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " using flying offset (identical to Throw_03)")
						offset_qangle = Vector(0, 0, 90)
						offset_vector = Vector(16, 24, 0)

					}
					else
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " not updating offset because the rock is already flying")
				}
				// Spammy and not really useful info
				//else
				//	ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " not updating offset yet because the rock has not yet been thrown")

				if ( do_update )
				{
					// Final setting
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " updating barrel orientation")
					SetPropVector( barrel, "m_vecOrigin", offset_vector )
					SetPropVector( barrel, "m_angRotation", offset_qangle )
				}
				else
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "BarrelRock " + rock.GetEntityIndex() + " not updating barrel orientation")
			}
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