GLOBAL_LIST_EMPTY(servants_of_ratvar)	//List of minds in the cult
GLOBAL_LIST_EMPTY(human_servants_of_ratvar)	//Humans in the cult
GLOBAL_LIST_EMPTY(cyborg_servants_of_ratvar)

GLOBAL_VAR(ratvar_arrival_tick)	//The world.time that Ratvar will arrive if the gateway is not disrupted

GLOBAL_VAR_INIT(installed_integration_cogs, 0)

GLOBAL_VAR(celestial_gateway)	//The celestial gateway
GLOBAL_VAR_INIT(ratvar_risen, FALSE)	//Has ratvar risen?
GLOBAL_VAR_INIT(gateway_opening, FALSE)	//Is the gateway currently active?

//A useful list containing all scriptures with the index of the name.
//This should only be used for looking up scriptures
GLOBAL_LIST_EMPTY(clockcult_all_scriptures)

GLOBAL_VAR_INIT(clockcult_power, 2500)
GLOBAL_VAR_INIT(clockcult_vitality, 200)

GLOBAL_VAR(clockcult_eminence)

//==========================
//===Clock cult Gamemode ===
//==========================

/datum/game_mode/clockcult
	name = "clockcult"
	config_tag = "clockcult"
	report_type = "clockcult"
	false_report_weight = 5
	required_players = 24
	required_enemies = 4
	recommended_enemies = 4
	antag_flag = ROLE_SERVANT_OF_RATVAR
	enemy_minimum_age = 14

	title_icon = "clockcult"
	announce_span = "danger"
	announce_text = "A powerful group of fanatics is trying to summon their deity!\n\
	<span class='danger'>Servants</span>: Convert more servants and defend the Ark of the Clockwork Justicar!\n\
	<span class='notice'>Crew</span>: Prepare yourselfs and destroy the Ark of the Clockwork Justicar."

	var/clock_cultists = CLOCKCULT_MIN_SERVANTS
	var/list/selected_servants = list()

	var/datum/team/clock_cult/main_cult

/datum/game_mode/clockcult/pre_setup()
	//Load Reebe
	var/list/errorList = list()
	var/list/reebe = SSmapping.LoadGroup(errorList, "Reebe", "map_files/generic", "CityOfCogs.dmm", default_traits=ZTRAITS_REEBE, silent=TRUE)
	if(errorList.len)
		message_admins("Reebe failed to load")
		log_game("Reebe failed to load")
		return FALSE
	for(var/datum/parsed_map/map in reebe)
		map.initTemplateBounds()
	//How many cultists?
	var/players = get_active_player_count()
	players = round(players / CLOCKCULT_CREW_PER_CULT)
	players = clamp(players, CLOCKCULT_MIN_SERVANTS, CLOCKCULT_MAX_SERVANTS)
	//Generate cultists
	for(var/i in 1 to players)
		if(!antag_candidates.len)
			break
		var/datum/mind/clockie = antag_pick(antag_candidates, ROLE_SERVANT_OF_RATVAR)
		antag_candidates -= clockie
		selected_servants += clockie
		clockie.assigned_role = ROLE_SERVANT_OF_RATVAR
		clockie.special_role = ROLE_SERVANT_OF_RATVAR
	//Generate scriptures
	for(var/categorypath in typesof(/datum/clockcult/scripture))
		var/datum/clockcult/scripture/S = new categorypath
		GLOB.clockcult_all_scriptures[S.name] = S
	return TRUE

/datum/game_mode/clockcult/post_setup(report)
	var/list/spawns = GLOB.servant_spawns.Copy()
	main_cult = new
	main_cult.setup_objectives()
	//Create team
	for(var/datum/mind/servant_mind in selected_servants)
		servant_mind.current.forceMove(pick_n_take(spawns))
		var/datum/antagonist/servant_of_ratvar/S = add_servant_of_ratvar(servant_mind.current, team=main_cult)
		S.equip_carbon(servant_mind.current)
		S.equip_servant()
	//Setup the conversion limits for auto opening the ark
	calculate_clockcult_values()
	return ..()

/datum/game_mode/clockcult/generate_report()
	return "Central Command's higher dimensional affairs division has been recently investigating a huge, anomalous energy spike \
	emanating from a neutron star close to your sector. It is currently theorised that an ancient group of fanatics praising an \
	eldritch deity made from brass and other outdated materials are abusing the energy of the dying star to breach dimensional \
	boundaries. The bluespace veil is faltering at your current location, making it a prime target for dangerous individuals to \
	abuse dimensional interdiction. Any evidence of tampering with bluespace fields should be reported to your local chaplain and \
	Central Command if a connection is still available at the time of discovery."

/datum/game_mode/clockcult/set_round_result()
	..()
	if(check_cult_victory())
		SSticker.mode_result = "win - clockcult win"
		SSticker.news_report = CLOCK_SUMMON
	else if(LAZYLEN(GLOB.cyborg_servants_of_ratvar))
		SSticker.mode_result = "loss - staff destroyed the ark"
		SSticker.news_report = CLOCK_SILICONS
	else
		SSticker.mode_result = "loss - staff destroyed the ark"
		SSticker.news_report = CLOCK_PROSELYTIZATION

/datum/game_mode/clockcult/check_finished(force_ending)
	return force_ending

/datum/game_mode/clockcult/proc/check_cult_victory()
	return GLOB.ratvar_risen

/datum/game_mode/clockcult/generate_credit_text()
	var/list/round_credits = list()
	var/len_before_addition

	if(GLOB.ratvar_risen)
		round_credits += "<center><h1>Ratvar has been released from his prison!</h1>"
	else
		round_credits += "<center><h1>The clock cultists failed to summon Ratvar, he will remain trapped forever to rust!</h1>"
	round_credits += "<center><h1>The Servants of Ratvar:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/operative in GLOB.servants_of_ratvar)
		round_credits += "<center><h2>[operative.name] as a servant of Ratvar!</h2>"
	if(len_before_addition == round_credits.len)
		round_credits += list("<center><h2>The servants were annihilated!</h2>", "<center><h2>Their remains could not be identified!</h2>")
	round_credits += "<br>"

	round_credits += ..()
	return round_credits

/datum/game_mode/proc/update_clockcult_icons_added(datum/mind/cult_mind)
	var/datum/atom_hud/antag/culthud = GLOB.huds[ANTAG_HUD_CLOCKWORK]
	culthud.join_hud(cult_mind.current)
	set_antag_hud(cult_mind.current, "clockwork")

/datum/game_mode/proc/update_clockcult_icons_removed(datum/mind/cult_mind)
	var/datum/atom_hud/antag/culthud = GLOB.huds[ANTAG_HUD_CLOCKWORK]
	culthud.leave_hud(cult_mind.current)
	set_antag_hud(cult_mind.current, null)

//==========================
//==== Clock cult procs ====
//==========================

/proc/is_servant_of_ratvar(mob/living/M)
	return M?.mind?.has_antag_datum(/datum/antagonist/servant_of_ratvar)

//Similar to cultist one, except silicons are allowed
/proc/is_convertable_to_clockcult(mob/living/M)
	if(!istype(M))
		return FALSE
	if(!M.mind)
		return FALSE
	if(ishuman(M) && (M.mind.assigned_role in list("Captain", "Chaplain")))
		return FALSE
	if(is_servant_of_ratvar(M))
		return FALSE
	if(M.mind.enslaved_to && !is_servant_of_ratvar(M.mind.enslaved_to))
		return FALSE
	if(M.mind.unconvertable)
		return FALSE
	if(iscultist(M) || isconstruct(M) || ispAI(M))
		return FALSE
	if(HAS_TRAIT(M, TRAIT_MINDSHIELD))
		return FALSE
	return TRUE

/proc/flee_reebe()
	for(var/mob/living/M in GLOB.mob_list)
		if(!is_reebe(M.z))
			continue
		var/safe_place = find_safe_turf()
		M.forceMove(safe_place)
		if(!is_servant_of_ratvar(M))
			M.SetSleeping(50)

//Transmits a message to everyone in the cult
//Doesn't work if the cultists contain holy water, or are not on the station or Reebe
//TODO: SANITIZE MESSAGES WITH THE NORMAL SAY STUFF (punctuation)
/proc/hierophant_message(msg, mob/living/sender, span = "<span class='brass'>", use_sanitisation=TRUE, say=TRUE)
	var/hierophant_message = "[span]"
	if(sender?.reagents)
		if(sender.reagents.has_reagent(/datum/reagent/water/holywater, 1))
			to_chat(sender, "<span class='nezbere'>[pick("You fail to transmit your cries for help.", "Your calls into the void go unanswered.", "You try to transmit your message, but the hierophant network is silent.")]</span>")
			return FALSE
	if(!msg)
		if(sender)
			to_chat(sender, "<span class='brass'>You cannot transmit nothing!</span>")
		return FALSE
	if(use_sanitisation)
		msg = sanitize(msg)
	if(sender)
		if(say)
			sender.say("#[text2ratvar(msg)]")
		msg = sender.treat_message(msg)
		hierophant_message += "<b>[sender.name]</b> transmits, \"[msg]\""
	else
		hierophant_message += msg
	if(span)
		hierophant_message += "</span>"
	for(var/datum/mind/mind in GLOB.servants_of_ratvar)
		var/mob/M = mind.current
		if((isliving(M) && !is_servant_of_ratvar(M)) || isnewplayer(M))
			continue
		if(M.reagents)
			if(M.reagents.has_reagent(/datum/reagent/water/holywater, 1))
				if(pick(20))
					to_chat(M, "<span class='nezbere'>You hear the cogs whispering to you, but cannot understand their words.</span>")
				continue
		to_chat(M, hierophant_message)
