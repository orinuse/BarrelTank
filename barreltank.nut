
local SetPropInt = ::NetProps.SetPropInt.bindenv(::NetProps)
local SetPropVector = ::NetProps.SetPropVector.bindenv(::NetProps)
local GetPropVector = ::NetProps.GetPropVector.bindenv(::NetProps)
local GetPropString = ::NetProps.GetPropString.bindenv(::NetProps)
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

local RoundToDecimal = function(val, decimalPlaces)
{
	local f = pow(10, decimalPlaces) * 1.0;
	local newVal = val * f;
	newVal = floor(newVal + 0.5)
	newVal = (newVal * 1.0) / f;

	return newVal;
}

::RockEvent <- {}

::RockEvent.OnGameEvent_round_start_post_nav <- function(params)
{
	local MAXPLAYERS = 33

	// local world = EntIndexToHScript(0) //idk why this doesn't work
	local worldspawn = Entities.First() // FindByClassname(null, "worldspawn")
	// Doing it this way ensures these get destroyed when the round starts
	local lastthink_rock_handle = array(2048)
	local lastthink_rock_origin = array(2048)
	local lastthink_rock_angles = array(2048)
	local lastthink_rock_onnext = array(2048)
	local lastthink_rock_flying = array(2048)

	// Scan for any rocks in play
	/// This is done as a think function, which differs from SM.
	/// Although, we also don't need to iterate over literally the entire entity dict, because OnEntityCreated and OnEntityDestroyed exist there, and not here for reasons beyond my comprehension.
	::LookForRock <- function()
	{
		// Iterate over all edicts in the map
		for ( local entid = MAXPLAYERS; entid < 2048; entid++ )
		{
			// Get a script handle from this edict.
			local rock = EntIndexToHScript( entid )

			// Whether or not this entity is a valid tank rock
			local is_rock = false
			// If the rock is NOT valid, and it was not valid on the previous frame, then we'll skip the rest of the code here.
			if ( rock != null && rock.GetClassname() == "tank_rock" )
				is_rock = true
			else if ( lastthink_rock_handle[entid] == null )
				continue

			local tank = null
			local barrel = null

			local rockname = ( rock != null ) ? rock.GetName() : "<no name>"

			// Was this edict in the table on the last tick, but now gone, not a rock, or not the same rock?
			// If so, the rock that was in this slot broke, so spawn a barrel.
			if ( lastthink_rock_handle[entid] != null && ( rock == null || !is_rock || ( is_rock && lastthink_rock_handle[entid] != rock.GetEntityHandle() ) ) )
			{
				// No, it just vanished, break a barrel here and ignore the rest of the code.
				ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") breaking because it stopped existing")
				ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "-> is_rock: " + is_rock)
				ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "-> rock.GetEntityHandle(): " + ( rock != null ? rock.GetEntityHandle() : "null" ) )
				ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, "-> lastthink_rock_handle[entid]: " + lastthink_rock_handle[entid] )

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
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") broke successfully, and the current edict is not a valid rock, halting here")
					continue
				}
				else
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") broke successfully, but the current edict became a different valid rock on the same frame, allow new BarrelRock")
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
					// Set a frame delay.
					/// I have tried up to 4 frames of delay, it doesn't seem to matter.
					if ( lastthink_rock_onnext[entid] == null )
						lastthink_rock_onnext[entid] = 1

					if ( lastthink_rock_onnext[entid] > 0 )
					{
						// No, set this to true so we fail this check on the next frame, and instead run the code as intended.
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - Found new BarrelRock " + rockname + " (" + entid + "), delaying spawn code for " + lastthink_rock_onnext[entid] + " more frame" + ( lastthink_rock_onnext[entid] == 1 ? "" : "s"))
						lastthink_rock_onnext[entid] = lastthink_rock_onnext[entid] - 1;
						// Don't fill the handle yet
						continue
					}
					else
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") running spawn code")

					// We've passed the one-frame-delay check, fill stuff.
					tank = rock.GetOwnerEntity()

					local tankid = -1
					// If the owner entity is valid, grab its index, it's the tank.
					if ( tank != null ) tankid = tank.GetEntityIndex()

					lastthink_rock_handle[entid] = rock.GetEntityHandle()

					/// For reasons unknown, m_vecOrigin and m_angRotation are empty at this point, but GetOrigin and GetAngles return seemingly ok values.
					/// I don't know why. This code works fine in the SuperTanks 2 plugin.
					lastthink_rock_origin[entid] = GetPropVector( rock, "m_vecOrigin" ) // rock.GetOrigin() 
					lastthink_rock_angles[entid] = GetPropVector( rock, "m_angRotation" ) // rock.GetAngles()
					// Only need to do this to be rid of QAngle because it's stinky
					// lastthink_rock_angles[entid] = Vector( lastthink_rock_angles[entid].x, lastthink_rock_angles[entid].y, lastthink_rock_angles[entid].z )

					rockname = format("rock_%d_%d_bt", entid, tankid)
					local barrelname = format("barrel_%d_%d_bt", entid, tankid)

					rock.__KeyValueFromString("targetname", rockname)

					// Now that we've set the rock's name, let's retrieve it in case the name gets culled for any reason after application.
					// rockname = GetPropString( rock, "m_iName" );

					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") spawning a new barrel with origin " + lastthink_rock_origin[entid] + ", angles " + lastthink_rock_angles[entid])

					// Fill the barrel variable with a new prop_dynamic_override
					barrel = SpawnEntityFromTable("prop_dynamic_override", {
						origin = lastthink_rock_origin[entid],
						angles = lastthink_rock_angles[entid],
						targetname = barrelname,
						parentname = rockname,
						model = MODEL_BARREL
					})

					// Fire SetParent so we modify the parent->child relationship
					DoEntFire(barrelname, "SetParent", rockname, -1, barrel, barrel)
					DoEntFire(barrelname, "Enable", "", -1, null, null)
					DoEntFire(barrelname, "DisableCollision", "", -1, null, null)
					SetPropEntity( barrel, "m_hOwnerEntity", rock )

					// Don't render the rock
					SetPropInt( rock, "m_nRenderMode", 10 )


					/// These values match those used in SuperTanks 2.
					do_update = true
					if ( tank.GetSequence() == tank.LookupSequence("Throw_03") )
					{
						offset_qangle = Vector(0, 0, 90)
						offset_vector = Vector(16, 24, 0)
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") using Throw_03 offset")
					}
					else
					{
						offset_qangle = Vector(0, -90, 90)
						offset_vector = Vector(24, 0, 0)
						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") using Throw_02/Throw_04 offset")
					}
				}
				else if ( lastthink_rock_handle[entid] == rock.GetEntityHandle() )
				{
					// The rock is continuing to exist, so we'll just grab its info.
					barrel = rock.FirstMoveChild()
					tank = rock.GetOwnerEntity()
				}
				else
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - WARNING: Logical error in BarrelRock " + rockname + " (" + entid + "): Last think handle ID does not match current handle ID, skill issue tbh")

				// Wait for the rock to have no moveparent.
				// Once it loses its moveparent, we'll update lastthink_rock_flying[entid] to true so we don't keep running this code over and over while it's flying (since there'd be no real reason to do that)
				// This effectively acts like a 
				if ( rock.GetMoveParent() == null )
				{
					// We hit a valid flying rock entity, let's update its vectors.
					/// For reasons unknown, m_vecOrigin and m_angRotation are empty at this point, but GetOrigin and GetAngles return seemingly ok values.
					/// I don't know why. This code works fine in the SuperTanks 2 plugin.
					lastthink_rock_origin[entid] = GetPropVector( rock, "m_vecOrigin" ) // rock.GetOrigin()
					lastthink_rock_angles[entid] = GetPropVector( rock, "m_angRotation" ) // rock.GetAngles()
					// Only need to do this to be rid of QAngle because it's stinky
					// lastthink_rock_angles[entid] = Vector( lastthink_rock_angles[entid].x, lastthink_rock_angles[entid].y, lastthink_rock_angles[entid].z )
					
					if ( lastthink_rock_flying[entid] != true )
					{
						lastthink_rock_flying[entid] = true

						if ( barrel == null )
						{
							ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - WARNING: BarrelRock " + rockname + " (" + entid + ") released & had no valid barrel to update the offset of, for some reason")
							continue
						}
						else
							ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") released & had a valid barrel to update the offset of")

						// When the rock has no moveparent, we'll use this vector.

						do_update = true

						ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") using flying offset (identical to Throw_03)")
						offset_qangle = Vector(0, 0, 90)
						offset_vector = Vector(16, 24, 0)

					}
				}

				/// Note from playtesting with hellmet: For some reason, setting the origin AT ALL fucks this up.
				/// Doing it with SetPropVector makes the barrel entirely invisible, for no apparent reason.
				/// Doing it with vscript's natives only seems to work when the rock is thrown, but does not work correctly for when it spawns.
				/// When using SetPropVector here, it does not matter whether or not you use GetPropVector, it will be set incorrectly always.
				/// Doing this code in the SuperTanks 2 SM plugin yields the exact result you'd expect: The relative offset of the barrel is set correctly, since its parent is now the rock.
				if ( do_update )
				{
					// Final setting
					ClientPrint(null, DirectorScript.HUD_PRINTCONSOLE, RoundToDecimal(Time(),4) + " - BarrelRock " + rockname + " (" + entid + ") updating barrel orientation - offset " + offset_vector + ", angles " + offset_qangle)
					// NOTE: do not do anything at all and suddenly it works a little bit, the offsets are wrong but at least the barrel is there at all?
					// barrel.SetOrigin( offset_vector )
					// barrel.SetAngles( QAngle( offset_qangle.x, offset_qangle.y, offset_qangle.z ) )
					SetPropVector( barrel, "m_vecOrigin", offset_vector )
					SetPropVector( barrel, "m_angRotation", offset_qangle )
				}
			}
		}
		return -1
	}
	
	worldspawn.ValidateScriptScope()
	worldspawn.GetScriptScope().LookForRock <- LookForRock
	AddThinkToEnt(worldspawn, "LookForRock")
}


Msg("Barrel Tank Loaded\n")

__CollectGameEventCallbacks(::RockEvent)
