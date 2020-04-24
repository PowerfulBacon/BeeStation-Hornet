// Thanks to Burger from Burgerstation for the foundation for this

/*
BYOND Forum posts that helped me:
http://www.byond.com/forum/post/1133166
http://www.byond.com/forum/post/1072433
http://www.byond.com/forum/post/940994
http://www.byond.com/docs/ref/skinparams.html#Fonts
*/

#define COLOR_JOB_UNKOWN "#dda583"
#define COLOR_PERSON_UNKNOWN "#999999"

GLOBAL_LIST_INIT(job_colors_pastel, list(
	"Assistant" = 		"#bdbdbd",
	"Captain" = 		"#FFDC9B",
	"Head of Personnel" = "#4C4CDD",
	"Bartender" = 		"#B2CEB3",
	"Cook" = 			"#A2FBB9",
	"Botanist" =		"#95DE85",
	"Quartermaster" =	"#C79C52",
	"Cargo Technician" ="#D3A372",
	"Shaft Miner" =		"#CE957E",
	"Clown" =			"#FF83D7",
	"Mime" = 			"#BAD3BB",
	"Janitor" = 		"#97FBEA",
	"Curator" = 		"#A2FBB9",
	"Lawyer" = 			"#C07D7D",
	"Chaplain" =		"#8AB48C",
	"Chief Engineer" = 	"#CFBB72",
	"Station Engineer" ="#D9BC89",
	"Atmospheric Technician" = "#D4A07D",
	"Chief Medical Officer" = "#7A97DA",
	"Medical Doctor" = 	"#6CB1C5",
	"Chemist" = 		"#82BDCE",
	"Geneticist" = 		"#83BBBF",
	"Virologist" = 		"#75AEA3",
	"Paramedic" = 		"#8FBEB4",
	"Research Director"="#974EA9",
	"Scientist" =		"#C772C7",
	"Roboticist" = 		"#AC71BA",
	"Head of Security" ="#D33049",
	"Warden" = 			"#EA545E",
	"Detective" = 		"#C78B8B",
	"Security Officer" ="#E6A3A3",
	"Brig Physician" = 	"#B364B3",
	"Prisoner" = 		"#d38a5c",
	"CentCom" = 		"#90FD6D",
	"Unknown"=			COLOR_JOB_UNKOWN,
))

/mob/living
	var/list/stored_chat_text = list()

/proc/get_job_colour(job_title)
	return GLOB.job_colors_pastel[job_title]

/proc/animate_chat(mob/living/target, message, message_language, message_mode, list/show_to, duration)

	var/static/list/chatOverhead_colors = list("#83c0dd","#8396dd","#9983dd","#dd83b6","#dd8383","#83dddc","#83dd9f","#a5dd83","#ddd983","#dda583","#dd8383")
	var/text_color

	var/mob/living/carbon/human/target_as_human = target
	if(istype(target_as_human))
		if(target_as_human.wear_id?.GetID())
			var/datum/job/wearer_job = target_as_human.wear_id.GetJobName()
			text_color = get_job_colour(wearer_job)
		else
			text_color = COLOR_PERSON_UNKNOWN
	else
		text_color = pick(chatOverhead_colors)

	var/css = ""

	if(copytext(message, length(message) - 1) == "!!")
		css += "font-weight: bold;"
	if(istype(target.get_active_held_item(), /obj/item/megaphone))
		css += "font-size: 8px;"
		if(istype(target.get_active_held_item(), /obj/item/megaphone/clown))
			text_color = "#ff2abf"
	else if((message_mode == MODE_WHISPER) || (message_mode == MODE_WHISPER_CRIT) || (message_mode == MODE_HEADSET) || (message_mode in GLOB.radiochannels))
		css += "font-size: 6px;"

	css += "color: [text_color];"

	message = copytext(message, 1, 120)

	var/datum/language/D = GLOB.language_datum_instances[message_language]

	// create 2 messages, one that appears if you know the language, and one that appears when you don't know the language
	var/image/I = image(loc = target, layer=FLY_LAYER)
	I.alpha = 0
	I.maptext_width = 128
	I.maptext_height = 64
	I.pixel_x = -48
	I.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	I.maptext = "<center><span class='chatOverhead' style='[css]'>[message]</span></center>"

	var/image/O = image(loc = target, layer=FLY_LAYER)
	O.alpha = 0
	O.maptext_width = 128
	O.maptext_height = 64
	O.pixel_x = -48
	O.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	O.maptext = "<center><span class='chatOverhead' style='[css]'>[D.scramble(message)]</span></center>"

	target.stored_chat_text += I
	target.stored_chat_text += O

	// find a client that's connected to measure the height of the message, so it knows how much to bump up the others
	if(length(GLOB.clients))
		var/client/C = null
		for(var/client/player in GLOB.clients)
			if(player.byond_version >= 513)
				C = player
				break
		if(C)
			var/moveup = text2num(splittext(C.MeasureText(I.maptext, width = 128), "x")[2])
			for(var/image/old in target.stored_chat_text)
				if(old != I && old != O)
					var/pixel_y_new = old.pixel_y + moveup
					animate(old, 2, pixel_y = pixel_y_new)
		else // oh god this shouldn't happen, but MeasureText() was introduced in 513.1490 as a client proc
			for(var/image/old in target.stored_chat_text)
				if(old != I && old != O)
					var/pixel_y_new = old.pixel_y + 10
					animate(old, 2, pixel_y = pixel_y_new)

	for(var/client/C in show_to)
		if(C.mob.can_hear() && C.prefs.overhead_chat)
			if(C.mob.can_speak_in_language(message_language))
				C.images += I
			else
				C.images += O

	animate(I, 1, alpha = 255, pixel_y = 24)
	animate(O, 1, alpha = 255, pixel_y = 24)

	// wait a little bit, then delete the message
	spawn(duration)
		var/pixel_y_new = I.pixel_y + 10
		animate(I, 2, pixel_y = pixel_y_new, alpha = 0)
		animate(O, 2, pixel_y = pixel_y_new, alpha = 0)
		sleep(2)
		for(var/client/C in show_to)
			if(C.mob.can_hear() && C.prefs.overhead_chat)
				if(C.mob.can_speak_in_language(message_language))
					C.images -= I
				else
					C.images -= O

		target.stored_chat_text -= I
		target.stored_chat_text -= O
		qdel(I)
		qdel(O)
