#define FLAT_ICON_CACHE_MAX_SIZE 250

SUBSYSTEM_DEF(stat)
	name = "Stat"
	wait = 2 SECONDS
	priority = FIRE_PRIORITY_STAT
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME	//RUNLEVEL_INIT doesn't work, so the stat panel will not auto update during this time (But that is good since we don't want to waste processing time during that phase).
	init_order = INIT_ORDER_STAT
	flags = SS_NO_INIT | SS_BACKGROUND

	var/list/flat_icon_cache = list()	//Assoc list, datum = flat icon
	var/list/currentrun = list()

/datum/controller/subsystem/stat/fire(resumed = 0)
	if (!resumed)
		src.currentrun = GLOB.clients.Copy()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(currentrun.len)
		var/client/C = currentrun[currentrun.len]
		currentrun.len--

		if (C)
			var/mob/M = C.mob
			if(M)
				//Auto-update, not forced
				M.UpdateMobStat(FALSE)

		if (MC_TICK_CHECK)
			return

//Note: Doesn't account for decals on items.
//Whoever examins an item with a decal first, everyone else will see that items decals.
//Significantly reduces server lag though, like MASSIVELY!
/datum/controller/subsystem/stat/proc/get_flat_icon(atom/A)
	var/what_to_search = "[A.type][A.icon_state]"
	//Mobs are more important than items.
	//Mob icons will change if their name changes, their type changes or their overlays change.
	if(istype(A, /mob))
		var/mob/M = A
		var/overlay_hash = ""
		for(var/image/I as() in M.overlays)
			overlay_hash = "[overlay_hash][I.icon_state]"
		what_to_search = "[M.type][M.name][overlay_hash]"
	//Makes it shorter
	what_to_search = sha1(what_to_search)
	thing = flat_icon_cache[what_to_search]
	if(thing)
		return thing
	//Adding a new icon
	//If the list gets too big just remove the first thing
	if(flat_icon_cache.len > FLAT_ICON_CACHE_MAX_SIZE)
		flat_icon_cache.Cut(1, 2)
	thing = icon2base64(getFlatIcon(A, no_anim=TRUE))
	flat_icon_cache[what_to_search] = thing
	return thing

/datum/controller/subsystem/stat/proc/send_global_alert(title, message)
	for(var/client/C in GLOB.clients)
		if(C?.tgui_panel)
			C.tgui_panel.give_alert_popup(title, message)

/datum/controller/subsystem/stat/proc/clear_global_alert()
	for(var/client/C in GLOB.clients)
		if(C?.tgui_panel)
			C.tgui_panel.clear_alert_popup()

#undef FLAT_ICON_CACHE_MAX_SIZE
