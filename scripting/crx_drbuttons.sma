#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_VERSION "1.2"
#define ADMIN_ACCESS ADMIN_BAN
#define MARKED_BUTTON 366636
#define MAX_DISTANCE 400
#define SAFE_TEAM 2

//Comment this line to disable the sounds.
#define ENABLE_SOUNDS

#define SOUND_CLICK "buttons/latchlocked1.wav"
#define SOUND_MARK "buttons/button9.wav"
#define SOUND_UNMARK "buttons/button7.wav"

//Comment this line to disable the beam.
#define BUTTON_SPRITE "sprites/lgtning.spr"

#define BEAM_STARTFRAME 0
#define BEAM_FRAMERATE 10
#define BEAM_LIFE 10
#define BEAM_WIDTH 50
#define BEAM_NOISE 2
#define BEAM_BRIGHTNESS 255
#define BEAM_SPEED 30

new const g_iColors[][] = {
	{ 0, 0, 255 },
	{ 255, 0, 0 }
}

new const g_szPrefix[] = "^4[CTSafe Buttons]^1"
new const g_szButtons[][] = { "func_button", "func_rot_button", "button_target" }
new g_szDirectory[256], g_szFilename[256]
new g_msgSayText
new g_iSprite
new g_iCount

public plugin_init()
{
	register_plugin("DeathRun CT-Safe Buttons", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CTSafeButtons", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("CTSafeButtons.txt")
	register_clcmd("drop", "cmdMarkButton")
	
	for(new i; i < sizeof(g_szButtons); i++)
		RegisterHam(Ham_Use, g_szButtons[i], "eventUseButton", 0)
	
	new szMap[32]
	get_mapname(szMap, charsmax(szMap))
	strtolower(szMap)
	get_datadir(g_szDirectory, charsmax(g_szDirectory))
	add(g_szDirectory, charsmax(g_szDirectory), "/CTSafeButtons")	
	formatex(g_szFilename, charsmax(g_szFilename), "%s/%s.txt", g_szDirectory, szMap)
	
	if(!dir_exists(g_szDirectory))
		mkdir(g_szDirectory)
	
	g_msgSayText = get_user_msgid("SayText")
	fileRead(0)
}

public plugin_end()
	fileRead(1)
	
fileRead(iWrite)
{
	new iFilePointer
	
	switch(iWrite)
	{
		case 0:
		{
			iFilePointer = fopen(g_szFilename, "rt")
	
			if(iFilePointer)
			{
				new szData[40], szClass[32], szModel[5], iEnt
				
				while(!feof(iFilePointer))
				{
					fgets(iFilePointer, szData, charsmax(szData))
					trim(szData)
					
					if(szData[0] == EOS || szData[0] == ';')
						continue
						
					parse(szData, szClass, charsmax(szClass), szModel, charsmax(szModel))
					iEnt = find_ent_by_model(-1, szClass, szModel)
					
					if(pev_valid(iEnt))
					{
						set_pev(iEnt, pev_iuser2, MARKED_BUTTON)
						g_iCount++
					}
				}
				
				fclose(iFilePointer)
			}
		}
		case 1:
		{
			delete_file(g_szFilename)
			
			if(!g_iCount)
				return
				
			iFilePointer = fopen(g_szFilename, "wt")
			
			if(iFilePointer)
			{
				new szModel[5], iEnt = FM_NULLENT
				
				for(new i; i < sizeof(g_szButtons); i++)
				{
					iEnt = FM_NULLENT
					
					while((iEnt = find_ent_by_class(iEnt, g_szButtons[i])))
					{
						if(pev_valid(iEnt) && pev(iEnt, pev_iuser2) == MARKED_BUTTON)
						{
							pev(iEnt, pev_model, szModel, charsmax(szModel))
							fprintf(iFilePointer, "%s %s^n", g_szButtons[i], szModel)
						}
					}
				}
				
				fclose(iFilePointer)
			}
		}
	}
}

public eventUseButton(iEnt, id)
{
	if(get_user_flags(id) & ADMIN_ACCESS && get_user_button(id) & IN_RELOAD)
	{
		MarkButton(id, iEnt)
		return HAM_SUPERCEDE
	}
		
	if(pev_valid(iEnt) && get_user_team(id) == SAFE_TEAM && pev(iEnt, pev_iuser2) != MARKED_BUTTON)
	{
		ColorChat(id, "%s %L", g_szPrefix, id, "CTSAFE_NOTALLOWED")
		
		#if defined SOUND_CLICK
			client_cmd(id, "spk %s", SOUND_CLICK)
		#endif
		
		return HAM_SUPERCEDE
	}
	
	return HAM_IGNORED
}

public cmdMarkButton(id, iLevel, iCid)
{
	if(!(get_user_flags(id) & ADMIN_ACCESS) || !(get_user_button(id) & IN_RELOAD))
		return PLUGIN_CONTINUE
	
	new iEnt, iBody
	get_user_aiming(id, iEnt, iBody, MAX_DISTANCE)
	
	if(!pev_valid(iEnt) || !is_button(iEnt))
	{
		ColorChat(id, "%s %L", g_szPrefix, id, "CTSAFE_NOTAIMING")
		return PLUGIN_HANDLED
	}
	
	MarkButton(id, iEnt)
	return PLUGIN_HANDLED
}

public plugin_precache()
{
	#if defined ENABLE_SOUNDS
		precache_sound(SOUND_CLICK)
		precache_sound(SOUND_MARK)
		precache_sound(SOUND_UNMARK)
	#endif
	
	#if defined BUTTON_SPRITE
		g_iSprite = precache_model(BUTTON_SPRITE)
	#endif
}

MarkButton(id, iEnt)
{
	new iMark = pev(iEnt, pev_iuser2) == MARKED_BUTTON ? 0 : MARKED_BUTTON
	set_pev(iEnt, pev_iuser2, iMark)
	
	if(iMark)
		g_iCount++
	else
		g_iCount--
	
	#if defined BUTTON_SPRITE
		draw_beam(id, iEnt, iMark ? 0 : 1)
	#endif
	
	#if defined ENABLE_SOUNDS
		client_cmd(id, "spk %s", iMark ? SOUND_MARK : SOUND_UNMARK)
	#endif
	
	ColorChat(id, "%s %L", g_szPrefix, id, iMark ? "CTSAFE_MARKED" : "CTSAFE_UNMARKED")
}

bool:is_button(iEnt)
{
	new szClass[32]
	pev(iEnt, pev_classname, szClass, charsmax(szClass))
	
	for(new i; i < sizeof(g_szButtons); i++)
		if(equal(szClass, g_szButtons[i]))
			return true
	
	return false
}

draw_beam(id, iEnt, iMark)
{
	new iOrigin[3]
	new Float:flMins[3], Float:flMaxs[3]
	get_user_origin(id, iOrigin)
	pev(iEnt, pev_mins, flMins)
	pev(iEnt, pev_maxs, flMaxs)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2])
	engfunc(EngFunc_WriteCoord, (flMins[0] + flMaxs[0]) * 0.5)
	engfunc(EngFunc_WriteCoord, (flMins[1] + flMaxs[1]) * 0.5)
	engfunc(EngFunc_WriteCoord, (flMins[2] + flMaxs[2]) * 0.5)
	write_short(g_iSprite)
	write_byte(BEAM_STARTFRAME)
	write_byte(BEAM_FRAMERATE)
	write_byte(BEAM_LIFE)
	write_byte(BEAM_WIDTH)
	write_byte(BEAM_NOISE)
	write_byte(g_iColors[iMark][0])
	write_byte(g_iColors[iMark][1])
	write_byte(g_iColors[iMark][2])
	write_byte(BEAM_BRIGHTNESS)
	write_byte(BEAM_SPEED)
	message_end()
}

ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i; i < iCount; i++)
	{
		if(is_user_connected(iPlayers[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, iPlayers[i])
			write_byte(iPlayers[i])
			write_string(szMessage)
			message_end()
		}
	}
}