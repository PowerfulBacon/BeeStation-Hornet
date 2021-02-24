/atom/movable/legacy_lighting_object
	name          = ""

	anchored      = TRUE

	icon             = LIGHTING_ICON
	icon_state       = "transparent"
	color            = LIGHTING_BASE_MATRIX
	plane            = LIGHTING_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer            = BACKGROUND_LAYER + LIGHTING_PRIMARY_LAYER
	invisibility     = INVISIBILITY_LIGHTING

	var/needs_update = FALSE
	var/turf/myturf

/atom/movable/legacy_lighting_object/Initialize(mapload)
	. = ..()
	remove_verb(verbs)
	atom_colours.Cut()

	myturf = loc
	if (myturf.legacy_lighting_object)
		qdel(myturf.legacy_lighting_object, force = TRUE)
	myturf.legacy_lighting_object = src

	needs_update = TRUE
	GLOB.lighting_update_objects += src

/atom/movable/legacy_lighting_object/Destroy(var/force)
	if (force)
		GLOB.lighting_update_objects     -= src
		if (loc != myturf)
			var/turf/oldturf = get_turf(myturf)
			var/turf/newturf = get_turf(loc)
			stack_trace("A lighting object was qdeleted with a different loc then it is suppose to have ([COORD(oldturf)] -> [COORD(newturf)])")
		if (isturf(myturf))
			myturf.legacy_lighting_object = null
		myturf = null

		return ..()

	else
		return QDEL_HINT_LETMELIVE

/atom/movable/legacy_lighting_object/proc/update()
	if (loc != myturf)
		if (loc)
			var/turf/oldturf = get_turf(myturf)
			var/turf/newturf = get_turf(loc)
			warning("A lighting object realised it's loc had changed in update() ([myturf]\[[myturf ? myturf.type : "null"]]([COORD(oldturf)]) -> [loc]\[[ loc ? loc.type : "null"]]([COORD(newturf)]))!")

		qdel(src, TRUE)
		return

	// To the future coder who sees this and thinks
	// "Why didn't he just use a loop?"
	// Well my man, it's because the loop performed like shit.
	// And there's no way to improve it because
	// without a loop you can make the list all at once which is the fastest you're gonna get.
	// Oh it's also shorter line wise.
	// Including with these comments.

	// See LIGHTING_CORNER_DIAGONAL in lighting_corner.dm for why these values are what they are.
	var/static/datum/legacy_lighting_corner/dummy/dummy_lighting_corner = new

	var/list/corners = myturf.legacy_corners
	var/datum/legacy_lighting_corner/cr = dummy_lighting_corner
	var/datum/legacy_lighting_corner/cg = dummy_lighting_corner
	var/datum/legacy_lighting_corner/cb = dummy_lighting_corner
	var/datum/legacy_lighting_corner/ca = dummy_lighting_corner
	if (corners) //done this way for speed
		cr = corners[3] || dummy_lighting_corner
		cg = corners[2] || dummy_lighting_corner
		cb = corners[4] || dummy_lighting_corner
		ca = corners[1] || dummy_lighting_corner

	var/max = max(cr.cache_mx, cg.cache_mx, cb.cache_mx, ca.cache_mx)

	var/rr = cr.cache_r
	var/rg = cr.cache_g
	var/rb = cr.cache_b

	var/gr = cg.cache_r
	var/gg = cg.cache_g
	var/gb = cg.cache_b

	var/br = cb.cache_r
	var/bg = cb.cache_g
	var/bb = cb.cache_b

	var/ar = ca.cache_r
	var/ag = ca.cache_g
	var/ab = ca.cache_b

	#if LIGHTING_SOFT_THRESHOLD != 0
	var/set_luminosity = max > LIGHTING_SOFT_THRESHOLD
	#else
	// Because of floating points�?, it won't even be a flat 0.
	// This number is mostly arbitrary.
	var/set_luminosity = max > 1e-6
	#endif

	if((rr & gr & br & ar) && (rg + gg + bg + ag + rb + gb + bb + ab == 8))
	//anything that passes the first case is very likely to pass the second, and addition is a little faster in this case
		icon_state = "transparent"
		color = null
	else if(!set_luminosity)
		icon_state = "dark"
		color = null
	else
		icon_state = null
		color = list(
			rr, rg, rb, 00,
			gr, gg, gb, 00,
			br, bg, bb, 00,
			ar, ag, ab, 00,
			00, 00, 00, 01
		)

// Variety of overrides so the overlays don't get affected by weird things.

/atom/movable/legacy_lighting_object/ex_act(severity)
	return 0

/atom/movable/legacy_lighting_object/singularity_act()
	return

/atom/movable/legacy_lighting_object/singularity_pull()
	return

/atom/movable/legacy_lighting_object/blob_act()
	return

/atom/movable/legacy_lighting_object/onTransitZ()
	return

// Override here to prevent things accidentally moving around overlays.
/atom/movable/legacy_lighting_object/forceMove(atom/destination, var/no_tp=FALSE, var/harderforce = FALSE)
	if(harderforce)
		. = ..()

/atom/movable/lighting_object/onShuttleMove()
	return FALSE
