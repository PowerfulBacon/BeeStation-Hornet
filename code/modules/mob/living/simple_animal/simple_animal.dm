/mob/living/simple_animal
	name = "animal"
	icon = 'icons/mob/animal.dmi'
	health = 20
	maxHealth = 20
	gender = PLURAL //placeholder

	status_flags = CANPUSH

	var/icon_living = ""
	var/icon_dead = "" //icon when the animal is dead. Don't use animated icons for this.
	var/icon_gib = null	//We only try to show a gibbing animation if this exists.
	var/flip_on_death = FALSE //Flip the sprite upside down on death. Mostly here for things lacking custom dead sprites.

	var/list/speak = list()
	var/list/speak_emote = list()//	Emotes while speaking IE: Ian [emote], [text] -- Ian barks, "WOOF!". Spoken text is generated from the speak variable.
	var/speak_chance = 0
	var/list/emote_hear = list()	//Hearable emotes
	var/list/emote_see = list()		//Unlike speak_emote, the list of things in this variable only show by themselves with no spoken text. IE: Ian barks, Ian yaps

	var/turns_per_move = 1
	var/turns_since_move = 0
	var/stop_automated_movement = 0 //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = 1	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = 1 //When set to 1 this stops the animal from moving when someone is pulling it.

	//Interaction
	var/response_help   = "pokes"
	var/response_disarm = "shoves"
	var/response_harm   = "hits"
	var/harm_intent_damage = 6 //the damage dealt to a mob when punched. default is default punch damage
	var/force_threshold = 0 //Minimum force required to deal any damage

	//Temperature effect
	var/minbodytemp = 250
	var/maxbodytemp = 350

	//Healable by medical stacks? Defaults to yes.
	var/healable = 1

	//Atmos effect - Yes, you can make creatures that require plasma or co2 to survive. N2O is a trace gas and handled separately, hence why it isn't here. It'd be hard to add it. Hard and me don't mix (Yes, yes make all the dick jokes you want with that.) - Errorage
	var/list/atmos_requirements = list("min_oxy" = 5, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 1, "min_co2" = 0, "max_co2" = 5, "min_n2" = 0, "max_n2" = 0) //Leaving something at 0 means it's off - has no maximum
	var/unsuitable_atmos_damage = 2	//This damage is taken when atmos doesn't fit all the requirements above

	//LETTING SIMPLE ANIMALS ATTACK? WHAT COULD GO WRONG. Defaults to zero so Ian can still be cuddly
	var/melee_damage = 0
	var/obj_damage = 0 //how much damage this simple animal does to objects, if any
	var/armour_penetration = 0 //How much armour they ignore, as a flat reduction from the targets armour value
	var/melee_damage_type = BRUTE //Damage type of a simple mob's melee attack, should it do damage.
	var/list/damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 1, CLONE = 1, STAMINA = 0, OXY = 1) // 1 for full damage , 0 for none , -1 for 1:1 heal from that source
	var/attacktext = "attacks"
	var/attack_sound = null
	var/friendly = "nuzzles" //If the mob does no damage with it's attack
	var/environment_smash = ENVIRONMENT_SMASH_NONE //Set to 1 to allow breaking of crates,lockers,racks,tables; 2 for walls; 3 for Rwalls
	var/hardattacks = FALSE //if true, a simplemob is unaffected by NASTY_BLOCKING

	var/speed = 1 //LETS SEE IF I CAN SET SPEEDS FOR SIMPLE MOBS WITHOUT DESTROYING EVERYTHING. Higher speed is slower, negative speed is faster

	//Hot simple_animal baby making vars
	var/list/childtype = null
	var/next_scan_time = 0
	var/animal_species //Sorry, no spider+corgi buttbabies.

	//simple_animal access
	var/obj/item/card/id/access_card = null	//innate access uses an internal ID card
	var/buffed = 0 //In the event that you want to have a buffing effect on the mob, but don't want it to stack with other effects, any outside force that applies a buff to a simple mob should at least set this to 1, so we have something to check against
	var/gold_core_spawnable = NO_SPAWN //If the mob can be spawned with a gold slime core. HOSTILE_SPAWN are spawned with plasma, FRIENDLY_SPAWN are spawned with blood

	var/datum/component/spawner/nest

	var/sentience_type = SENTIENCE_ORGANIC // Sentience type, for slime potions

	var/list/loot = list() //list of things spawned at mob's loc when it dies
	var/del_on_death = 0 //causes mob to be deleted on death, useful for mobs that spawn lootable corpses
	var/deathmessage = ""

	var/allow_movement_on_non_turfs = FALSE

	var/attacked_sound = "punch" //Played when someone punches the creature

	var/dextrous = FALSE //If the creature has, and can use, hands
	var/dextrous_hud_type = /datum/hud/dextrous

	var/AIStatus = AI_ON //The Status of our AI, can be changed via toggle_ai(togglestatus) to AI_ON (On, usual processing), AI_IDLE (Will not process, but will return to AI_ON if an enemy comes near), AI_OFF (Off, Not processing ever), AI_Z_OFF (Temporarily off due to nonpresence of players)
	var/can_have_ai = TRUE //once we have become sentient, we can never go back

	var/shouldwakeup = FALSE //convenience var for forcibly waking up an idling AI on next check.

	//domestication
	var/tame = 0

	var/my_z // I don't want to confuse this with client registered_z

	var/do_footstep = FALSE
	///Generic flags
	var/simple_mob_flags = NONE

	var/special_process = FALSE

/mob/living/simple_animal/Initialize()
	. = ..()
	GLOB.simple_animals[AIStatus] += src
	if(gender == PLURAL)
		gender = pick(MALE,FEMALE)
	if(!real_name)
		real_name = name
	if(!loc)
		stack_trace("Simple animal being instantiated in nullspace")
	update_simplemob_varspeed()
	if(dextrous)
		AddComponent(/datum/component/personal_crafting)

/mob/living/simple_animal/Destroy()
	GLOB.simple_animals[AIStatus] -= src
	if (SSnpcpool.state == SS_PAUSED && LAZYLEN(SSnpcpool.currentrun))
		SSnpcpool.currentrun -= src

	if(nest)
		nest.spawned_mobs -= src
		nest = null

	var/turf/T = get_turf(src)
	if (T && AIStatus == AI_Z_OFF)
		SSidlenpcpool.idle_mobs_by_zlevel[T.z] -= src

	return ..()

/mob/living/simple_animal/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		. += "<span class='deadsay'>Upon closer examination, [p_they()] appear[p_s()] to be dead.</span>"

/mob/living/simple_animal/initialize_footstep()
	if(do_footstep)
		..()

/mob/living/simple_animal/updatehealth()
	..()
	health = CLAMP(health, 0, maxHealth)

/mob/living/simple_animal/update_stat()
	if(status_flags & GODMODE)
		return
	if(stat != DEAD)
		if(health <= 0)
			death()
		else
			stat = CONSCIOUS
	med_hud_set_status()


/mob/living/simple_animal/handle_status_effects()
	..()
	if(stuttering)
		stuttering = 0

/mob/living/simple_animal/proc/handle_automated_action()
	set waitfor = FALSE
	return

/mob/living/simple_animal/proc/handle_automated_movement()
	set waitfor = FALSE
	if(!stop_automated_movement && wander)
		if((isturf(loc) || allow_movement_on_non_turfs) && (mobility_flags & MOBILITY_MOVE))		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if(turns_since_move >= turns_per_move)
				if(!(stop_automated_movement_when_pulled && pulledby)) //Some animals don't move when pulled
					var/anydir = pick(GLOB.cardinals)
					if(Process_Spacemove(anydir))
						Move(get_step(src, anydir), anydir)
						turns_since_move = 0
			return 1

/mob/living/simple_animal/proc/handle_automated_speech(var/override)
	set waitfor = FALSE
	if(speak_chance)
		if(prob(speak_chance) || override)
			if(speak?.len)
				if((emote_hear && emote_hear.len) || (emote_see && emote_see.len))
					var/length = speak.len
					if(emote_hear && emote_hear.len)
						length += emote_hear.len
					if(emote_see && emote_see.len)
						length += emote_see.len
					var/randomValue = rand(1,length)
					if(randomValue <= speak.len)
						say(pick(speak), forced = "poly")
					else
						randomValue -= speak.len
						if(emote_see && randomValue <= emote_see.len)
							emote("me [pick(emote_see)]", 1)
						else
							emote("me [pick(emote_hear)]", 2)
				else
					say(pick(speak), forced = "poly")
			else
				if(!(emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					emote("me", 1, pick(emote_see))
				if((emote_hear && emote_hear.len) && !(emote_see && emote_see.len))
					emote("me", 2, pick(emote_hear))
				if((emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					var/length = emote_hear.len + emote_see.len
					var/pick = rand(1,length)
					if(pick <= emote_see.len)
						emote("me", 1, pick(emote_see))
					else
						emote("me", 2, pick(emote_hear))

/mob/living/simple_animal/proc/environment_air_is_safe()
	. = TRUE

	if(pulledby && pulledby.grab_state >= GRAB_KILL && atmos_requirements["min_oxy"])
		. = FALSE //getting choked

	if(isturf(loc) && isopenturf(loc))
		var/turf/open/ST = loc
		if(ST.air)
			var/tox = ST.air.get_moles(/datum/gas/plasma)
			var/oxy = ST.air.get_moles(/datum/gas/oxygen)
			var/n2  = ST.air.get_moles(/datum/gas/nitrogen)
			var/co2 = ST.air.get_moles(/datum/gas/carbon_dioxide)

			if(atmos_requirements["min_oxy"] && oxy < atmos_requirements["min_oxy"])
				. = FALSE
			else if(atmos_requirements["max_oxy"] && oxy > atmos_requirements["max_oxy"])
				. = FALSE
			else if(atmos_requirements["min_tox"] && tox < atmos_requirements["min_tox"])
				. = FALSE
			else if(atmos_requirements["max_tox"] && tox > atmos_requirements["max_tox"])
				. = FALSE
			else if(atmos_requirements["min_n2"] && n2 < atmos_requirements["min_n2"])
				. = FALSE
			else if(atmos_requirements["max_n2"] && n2 > atmos_requirements["max_n2"])
				. = FALSE
			else if(atmos_requirements["min_co2"] && co2 < atmos_requirements["min_co2"])
				. = FALSE
			else if(atmos_requirements["max_co2"] && co2 > atmos_requirements["max_co2"])
				. = FALSE
		else
			if(atmos_requirements["min_oxy"] || atmos_requirements["min_tox"] || atmos_requirements["min_n2"] || atmos_requirements["min_co2"])
				. = FALSE

/mob/living/simple_animal/proc/environment_temperature_is_safe(datum/gas_mixture/environment)
	. = TRUE
	var/areatemp = get_temperature(environment)
	if((areatemp < minbodytemp) || (areatemp > maxbodytemp))
		. = FALSE

/mob/living/simple_animal/handle_environment(datum/gas_mixture/environment)
	var/atom/A = loc
	if(isturf(A))
		var/areatemp = get_temperature(environment)
		if(abs(areatemp - bodytemperature) > 5)
			var/diff = areatemp - bodytemperature
			diff = diff / 5
			adjust_bodytemperature(diff)

	if(!environment_air_is_safe())
		adjustHealth(unsuitable_atmos_damage)
		if(unsuitable_atmos_damage > 0)
			throw_alert("not_enough_oxy", /atom/movable/screen/alert/not_enough_oxy)
	else
		clear_alert("not_enough_oxy")

	handle_temperature_damage()

/mob/living/simple_animal/proc/handle_temperature_damage()
	if(bodytemperature < minbodytemp)
		adjustHealth(unsuitable_atmos_damage)
		switch(unsuitable_atmos_damage)
			if(1 to 5)
				throw_alert("temp", /atom/movable/screen/alert/cold, 1)
			if(5 to 10)
				throw_alert("temp", /atom/movable/screen/alert/cold, 2)
			if(10 to INFINITY)
				throw_alert("temp", /atom/movable/screen/alert/cold, 3)
	else if(bodytemperature > maxbodytemp)
		adjustHealth(unsuitable_atmos_damage)
		switch(unsuitable_atmos_damage)
			if(1 to 5)
				throw_alert("temp", /atom/movable/screen/alert/hot, 1)
			if(5 to 10)
				throw_alert("temp", /atom/movable/screen/alert/hot, 2)
			if(10 to INFINITY)
				throw_alert("temp", /atom/movable/screen/alert/hot, 3)
	else
		clear_alert("temp")

/mob/living/simple_animal/gib()
	if(butcher_results || guaranteed_butcher_results)
		var/list/butcher = list()
		if(butcher_results)
			butcher += butcher_results
		if(guaranteed_butcher_results)
			butcher += guaranteed_butcher_results
		var/atom/Tsec = drop_location()
		for(var/path in butcher)
			for(var/i in 1 to butcher[path])
				new path(Tsec)
	..()

/mob/living/simple_animal/gib_animation()
	if(icon_gib)
		new /obj/effect/temp_visual/gib_animation/animal(loc, icon_gib)

/mob/living/simple_animal/say_mod(input, message_mode)
	if(speak_emote && speak_emote.len)
		verb_say = pick(speak_emote)
	. = ..()

/mob/living/simple_animal/emote(act, m_type=1, message = null, intentional = FALSE)
	if(stat)
		return
	. = ..()

/mob/living/simple_animal/proc/set_varspeed(var_value)
	speed = var_value
	update_simplemob_varspeed()

/mob/living/simple_animal/proc/update_simplemob_varspeed()
	if(speed == 0)
		remove_movespeed_modifier(MOVESPEED_ID_SIMPLEMOB_VARSPEED, TRUE)
	add_movespeed_modifier(MOVESPEED_ID_SIMPLEMOB_VARSPEED, TRUE, 100, multiplicative_slowdown = speed, override = TRUE)

/mob/living/simple_animal/get_stat_tab_status()
	var/list/tab_data = ..()
	tab_data["Health"] = GENERATE_STAT_TEXT("[round((health / maxHealth) * 100)]%")
	return tab_data

/mob/living/simple_animal/proc/drop_loot()
	if(loot.len)
		for(var/i in loot)
			new i(loc)

/mob/living/simple_animal/death(gibbed)
	movement_type &= ~FLYING
	if(nest)
		nest.spawned_mobs -= src
		nest = null
	drop_loot()
	if(dextrous)
		drop_all_held_items()
	if(!gibbed)
		if(deathsound || deathmessage || !del_on_death)
			INVOKE_ASYNC(src, /mob.proc/emote, "deathgasp")
	if(del_on_death)
		..()
		//Prevent infinite loops if the mob Destroy() is overridden in such
		//a manner as to cause a call to death() again
		del_on_death = FALSE
		qdel(src)
	else
		health = 0
		icon_state = icon_dead
		if(flip_on_death)
			transform = transform.Turn(180)
		density = FALSE
		..()

/mob/living/simple_animal/proc/CanAttack(atom/the_target)
	if(see_invisible < the_target.invisibility)
		return FALSE
	if(ismob(the_target))
		var/mob/M = the_target
		if(M.status_flags & GODMODE)
			return FALSE
	if (isliving(the_target))
		var/mob/living/L = the_target
		if(L.stat != CONSCIOUS)
			return FALSE
	if (ismecha(the_target))
		var/obj/mecha/M = the_target
		if (M.occupant)
			return FALSE
	return TRUE

/mob/living/simple_animal/handle_fire()
	return TRUE

/mob/living/simple_animal/IgniteMob()
	return FALSE

/mob/living/simple_animal/ExtinguishMob()
	return

/mob/living/simple_animal/revive(full_heal = 0, admin_revive = 0)
	if(..()) //successfully ressuscitated from death
		icon = initial(icon)
		icon_state = icon_living
		density = initial(density)
		mobility_flags = MOBILITY_FLAGS_DEFAULT
		update_mobility()
		. = 1
		setMovetype(initial(movement_type))

/mob/living/simple_animal/proc/make_babies() // <3 <3 <3
	set waitfor = 0
	if(gender != FEMALE || stat || next_scan_time > world.time || !childtype || !animal_species || !SSticker.IsRoundInProgress())
		return
	next_scan_time = world.time + (5 MINUTES)
	var/mob/living/simple_animal/partner
	var/children = 0
	for(var/mob/living/M in ohearers(7, src))
		if(M.stat) //Check if it's conscious FIRST.
			continue
		else if(is_type_in_list(M, childtype)) //Check for children SECOND.
			children++
		else if(istype(M, animal_species))
			if(M.ckey || M.gender == FEMALE) //Better safe than sorry ;_;
				continue
			partner = M
		else if(!faction_check_mob(M)) //shyness check. we're not shy in front of things that share a faction with us.
			return //we never mate when not alone, so just abort early
		CHECK_TICK

	if(partner && children < 3)
		var/childspawn = pickweight(childtype)
		var/turf/target = get_turf(loc)
		if(target)
			return new childspawn(target)

/mob/living/simple_animal/canUseTopic(atom/movable/M, be_close=FALSE, no_dextery=FALSE, no_tk=FALSE)
	if(incapacitated())
		to_chat(src, "<span class='warning'>You can't do that right now!</span>")
		return FALSE
	if(be_close && !in_range(M, src))
		to_chat(src, "<span class='warning'>You are too far away!</span>")
		return FALSE
	if(!(no_dextery || dextrous))
		to_chat(src, "<span class='warning'>You don't have the dexterity to do this!</span>")
		return FALSE
	return TRUE

/mob/living/simple_animal/stripPanelUnequip(obj/item/what, mob/who, where)
	if(!canUseTopic(who, BE_CLOSE))
		return
	else
		..()

/mob/living/simple_animal/stripPanelEquip(obj/item/what, mob/who, where)
	if(!canUseTopic(who, BE_CLOSE))
		return
	else
		..()

/mob/living/simple_animal/update_mobility(value_otherwise = TRUE)
	if(IsUnconscious() || IsParalyzed() || IsStun() || IsKnockdown() || IsParalyzed() || stat || resting)
		drop_all_held_items()
		mobility_flags = NONE
	else if(buckled)
		mobility_flags = MOBILITY_FLAGS_INTERACTION
	else
		if(value_otherwise)
			mobility_flags = MOBILITY_FLAGS_DEFAULT
		else
			mobility_flags = NONE
	if(!(mobility_flags & MOBILITY_MOVE))
		walk(src, 0) //stop mid walk

	update_transform()
	update_action_buttons_icon()

/mob/living/simple_animal/update_transform()
	var/matrix/ntransform = matrix(transform) //aka transform.Copy()
	var/changed = FALSE

	if(resize != RESIZE_DEFAULT_SIZE)
		changed = TRUE
		ntransform.Scale(resize)
		resize = RESIZE_DEFAULT_SIZE

	if(changed)
		animate(src, transform = ntransform, time = 2, easing = EASE_IN|EASE_OUT)

/mob/living/simple_animal/proc/sentience_act() //Called when a simple animal gains sentience via gold slime potion
	toggle_ai(AI_OFF) // To prevent any weirdness.
	can_have_ai = FALSE

/mob/living/simple_animal/update_sight()
	if(!client)
		return
	if(stat == DEAD)
		sight = (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = 8
		see_invisible = SEE_INVISIBLE_OBSERVER
		return

	see_invisible = initial(see_invisible)
	see_in_dark = initial(see_in_dark)
	sight = initial(sight)

	if(client.eye != src)
		var/atom/A = client.eye
		if(A.update_remote_sight(src)) //returns 1 if we override all other sight updates.
			return
	sync_lighting_plane_alpha()

/mob/living/simple_animal/get_idcard(hand_first)
	return access_card

/mob/living/simple_animal/can_hold_items()
	return dextrous

/mob/living/simple_animal/IsAdvancedToolUser()
	return dextrous

/mob/living/simple_animal/activate_hand(selhand)
	if(!dextrous)
		return ..()
	if(!selhand)
		selhand = (active_hand_index % held_items.len)+1
	if(istext(selhand))
		selhand = lowertext(selhand)
		if(selhand == "right" || selhand == "r")
			selhand = 2
		if(selhand == "left" || selhand == "l")
			selhand = 1
	if(selhand != active_hand_index)
		swap_hand(selhand)
	else
		mode()

/mob/living/simple_animal/swap_hand(hand_index)
	if(!dextrous)
		return ..()
	if(!hand_index)
		hand_index = (active_hand_index % held_items.len)+1
	var/obj/item/held_item = get_active_held_item()
	if(held_item)
		if(istype(held_item, /obj/item/twohanded))
			var/obj/item/twohanded/T = held_item
			if(T.wielded == 1)
				to_chat(usr, "<span class='warning'>Your other hand is too busy holding [T].</span>")
				return
	var/oindex = active_hand_index
	active_hand_index = hand_index
	if(hud_used)
		var/atom/movable/screen/inventory/hand/H
		H = hud_used.hand_slots["[hand_index]"]
		if(H)
			H.update_icon()
		H = hud_used.hand_slots["[oindex]"]
		if(H)
			H.update_icon()

/mob/living/simple_animal/put_in_hands(obj/item/I, del_on_fail = FALSE, merge_stacks = TRUE)
	. = ..(I, del_on_fail, merge_stacks)
	update_inv_hands()

/mob/living/simple_animal/update_inv_hands()
	if(client && hud_used && hud_used.hud_version != HUD_STYLE_NOHUD)
		var/obj/item/l_hand = get_item_for_held_index(1)
		var/obj/item/r_hand = get_item_for_held_index(2)
		if(r_hand)
			r_hand.layer = ABOVE_HUD_LAYER
			r_hand.plane = ABOVE_HUD_PLANE
			r_hand.screen_loc = ui_hand_position(get_held_index_of_item(r_hand))
			client.screen |= r_hand
		if(l_hand)
			l_hand.layer = ABOVE_HUD_LAYER
			l_hand.plane = ABOVE_HUD_PLANE
			l_hand.screen_loc = ui_hand_position(get_held_index_of_item(l_hand))
			client.screen |= l_hand

//ANIMAL RIDING

/mob/living/simple_animal/user_buckle_mob(mob/living/M, mob/user)
	var/datum/component/riding/riding_datum = GetComponent(/datum/component/riding)
	if(riding_datum)
		if(user.incapacitated())
			return
		for(var/atom/movable/A in get_turf(src))
			if(A != src && A != M && A.density)
				return
		M.forceMove(get_turf(src))
		return ..()

/mob/living/simple_animal/relaymove(mob/user, direction)
	var/datum/component/riding/riding_datum = GetComponent(/datum/component/riding)
	if(tame && riding_datum)
		riding_datum.handle_ride(user, direction)

/mob/living/simple_animal/buckle_mob(mob/living/buckled_mob, force = 0, check_loc = 1)
	. = ..()
	LoadComponent(/datum/component/riding)

/mob/living/simple_animal/proc/toggle_ai(togglestatus)
	if(!can_have_ai && (togglestatus != AI_OFF))
		return
	if (AIStatus != togglestatus)
		if (togglestatus > 0 && togglestatus < 5)
			if (togglestatus == AI_Z_OFF || AIStatus == AI_Z_OFF)
				var/turf/T = get_turf(src)
				if (AIStatus == AI_Z_OFF)
					SSidlenpcpool.idle_mobs_by_zlevel[T.z] -= src
				else
					SSidlenpcpool.idle_mobs_by_zlevel[T.z] += src
			GLOB.simple_animals[AIStatus] -= src
			GLOB.simple_animals[togglestatus] += src
			AIStatus = togglestatus
		else
			stack_trace("Something attempted to set simple animals AI to an invalid state: [togglestatus]")

/mob/living/simple_animal/proc/consider_wakeup()
	if (pulledby || shouldwakeup)
		toggle_ai(AI_ON)

/mob/living/simple_animal/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(!ckey && !stat)//Not unconscious
		if(AIStatus == AI_IDLE)
			toggle_ai(AI_ON)


/mob/living/simple_animal/onTransitZ(old_z, new_z)
	..()
	if (AIStatus == AI_Z_OFF)
		SSidlenpcpool.idle_mobs_by_zlevel[old_z] -= src
		toggle_ai(initial(AIStatus))
