/obj/machinery/computer/weapons
	name = "weapons control console"
	desc = "a computer for controlling the weapon systems of your shuttle."
	icon_screen = "cameras"
	icon_keyboard = "security_key"
	circuit = /obj/item/circuitboard/computer/security
	light_color = LIGHT_COLOR_RED
	ui_x = 870
	ui_y = 708

	var/list/weapon_weakrefs = list()	//A list of weakrefs to the weapon systems
	var/shuttle_id = "exploration"	//The shuttle we are connected to
	var/selected_ship_id = null
	var/list/concurrent_users = list()

	// Stuff needed to render the map
	var/map_name
	var/const/default_map_size = 15
	var/obj/screen/cam_screen
	var/obj/screen/plane_master/lighting/cam_plane_master
	var/obj/screen/background/cam_background

/obj/machinery/computer/weapons/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	map_name = "weapon_console_[REF(src)]_map"
	// Initialize map objects
	cam_screen = new
	cam_screen.name = "screen"
	cam_screen.assigned_map = map_name
	cam_screen.del_on_map_removal = FALSE
	cam_screen.screen_loc = "[map_name]:1,1"
	cam_plane_master = new
	cam_plane_master.name = "plane_master"
	cam_plane_master.assigned_map = map_name
	cam_plane_master.del_on_map_removal = FALSE
	cam_plane_master.screen_loc = "[map_name]:CENTER"
	cam_background = new
	cam_background.assigned_map = map_name
	cam_background.del_on_map_removal = FALSE

/obj/machinery/computer/weapons/Destroy()
	qdel(cam_screen)
	qdel(cam_plane_master)
	qdel(cam_background)
	return ..()

/obj/machinery/computer/weapons/ui_interact(\
		mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, \
		datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	// Update UI
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		var/user_ref = REF(user)
		var/is_living = isliving(user)
		// Ghosts shouldn't count towards concurrent users, which produces
		// an audible terminal_on click.
		if(is_living)
			concurrent_users += user_ref
		// Turn on the console
		if(length(concurrent_users) == 1 && is_living)
			playsound(src, 'sound/machines/terminal_on.ogg', 25, FALSE)
			use_power(active_power_usage)
		// Register map objects
		user.client.register_map_obj(cam_screen)
		user.client.register_map_obj(cam_plane_master)
		user.client.register_map_obj(cam_background)
		// Open UI
		ui = new(user, src, ui_key, "WeaponConsole", name, ui_x, ui_y, master_ui, state)
		ui.open()

/obj/machinery/computer/weapons/ui_data(mob/user)
	var/list/data = list()
	var/obj/docking_port/mobile/connected_port = SSshuttle.getShuttle(shuttle_id)
	data["selectedShip"] = selected_ship_id
	data["weapons"] = list()
	data["ships"] = list()
	//Enemy Ships
	for(var/ship_id in SSbluespace_exploration.tracked_ships)
		var/datum/ship_datum/ship = SSbluespace_exploration.tracked_ships[ship_id]
		//Shooting ourself, 🤔
		if(ship.mobile_port_id == shuttle_id)
			continue
		var/list/other_ship = list(
			id = ship_id,
			name = ship.ship_name,
			faction = ship.ship_faction,
			health = ship.integrity_remaining,
			maxHealth = ship.max_ship_integrity * SHIP_INTEGRITY_FACTOR,
			critical = ship.critical,
		)
		data["ships"] += list(other_ship)
	if(!connected_port)
		return data
	var/list/turfs = connected_port.return_turfs()
	//Weapons
	for(var/turf/T in turfs)
		for(var/obj/machinery/shuttle_weapon/weapon in T)
			var/list/active_weapon = list(
				name = weapon.name,
				cooldownLeft = max(weapon.next_shot_world_time - world.time, 0),
				cooldown = weapon.cooldown,
				inaccuracy = weapon.innaccuracy,
			)
			data["weapons"] += list(active_weapon)
	return data

/obj/machinery/computer/weapons/ui_static_data(mob/user)
	var/list/data = list()
	data["mapRef"] = map_name
	return data

/obj/machinery/computer/weapons/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("target_ship")
			var/s_id = params["id"]
			playsound(src, get_sfx("terminal_type"), 25, FALSE)

			if(!(s_id in SSbluespace_exploration.tracked_ships))
				show_camera_static()
				return TRUE

			var/obj/docking_port/mobile/target = SSshuttle.getShuttle(s_id)
			selected_ship_id = s_id

			if(!target)
				show_camera_static()
				return TRUE

			var/list/visible_turfs = target.return_turfs()

			cam_screen.vis_contents = visible_turfs
			cam_background.icon_state = "clear"

			var/list/projection = target.return_coords()
			cam_background.fill_rect(1, 1, abs(projection[3] - projection[1]) + 1, abs(projection[4] - projection[2]) + 1)

			return TRUE

/obj/machinery/computer/weapons/proc/show_camera_static()
	cam_screen.vis_contents.Cut()
	cam_background.icon_state = "scanline2"
	cam_background.fill_rect(1, 1, default_map_size, default_map_size)

/obj/machinery/computer/weapons/ui_close(mob/user)
	var/user_ref = REF(user)
	var/is_living = isliving(user)
	// Living creature or not, we remove you anyway.
	concurrent_users -= user_ref
	// Unregister map objects
	user.client.clear_map(map_name)
	// Turn off the console
	if(length(concurrent_users) == 0 && is_living)
		playsound(src, 'sound/machines/terminal_off.ogg', 25, FALSE)
		use_power(0)
