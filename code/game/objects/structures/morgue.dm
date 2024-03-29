/* Morgue stuff
 * Contains:
 *		Morgue
 *		Morgue tray
 *		Crematorium
 *		Crematorium tray
 *		Crematorium button
 */

/*
 * Bodycontainer
 * Parent class for morgue and crematorium
 * For overriding only
 */
/obj/structure/bodycontainer
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "morgue1"
	density = 1
	anchored = 1

	var/obj/structure/tray/connected = null
	var/locked = 0
	var/opendir = SOUTH

/obj/structure/bodycontainer/New()
	..()

/obj/structure/bodycontainer/Destroy()
	open()
	if(connected)
		qdel(connected)
		connected = null
	return ..()

/obj/structure/bodycontainer/on_log()
	update_icon()

/obj/structure/bodycontainer/update_icon()
	return

/obj/structure/bodycontainer/alter_health()
	return src.loc

/obj/structure/bodycontainer/relaymove(mob/user)
	if(user.stat || !isturf(loc))
		return
	open()

/obj/structure/bodycontainer/attack_paw(mob/user)
	return src.attack_hand(user)

/obj/structure/bodycontainer/attack_hand(mob/user)
	if(locked)
		user << "<span class='danger'>It's locked.</span>"
		return
	if(!connected)
		user << "That doesn't appear to have a tray."
		return
	if(connected.loc == src)
		open()
	else
		close()
	add_fingerprint(user)

/obj/structure/bodycontainer/attackby(obj/P, mob/user, params)
	add_fingerprint(user)
	if(istype(P, /obj/item/weapon/pen))
		var/t = stripped_input(user, "What would you like the label to be?", text("[]", name), null)
		if (user.get_active_hand() != P)
			return
		if ((!in_range(src, usr) && src.loc != user))
			return
		if (t)
			name = text("[]- '[]'", initial(name), t)
		else
			name = initial(name)
	else
		return ..()

/obj/structure/bodycontainer/container_resist()
	open()

/obj/structure/bodycontainer/proc/open()
	playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, 1)
	var/turf/T = get_step(src, opendir)
	for(var/atom/movable/AM in src)
		AM.forceMove(T)
	update_icon()

/obj/structure/bodycontainer/proc/close()
	playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, 1)
	for(var/atom/movable/AM in connected.loc)
		if(!AM.anchored || AM == connected)
			AM.forceMove(src)
	update_icon()

/obj/structure/bodycontainer/get_remote_view_fullscreens(mob/user)
	if(user.stat == DEAD || !(user.sight & (SEEOBJS|SEEMOBS)))
		user.overlay_fullscreen("remote_view", /obj/screen/fullscreen/impaired, 2)
/*
 * Morgue
 */
/obj/structure/bodycontainer/morgue
	name = "morgue"
	desc = "Used to keep bodies in until someone fetches them."
	icon_state = "morgue1"
	opendir = EAST

/obj/structure/bodycontainer/morgue/New()
	connected = new/obj/structure/tray/m_tray(src)
	connected.connected = src
	..()

/obj/structure/bodycontainer/morgue/update_icon()
	if (!connected || connected.loc != src) // Open or tray is gone.
		icon_state = "morgue0"
	else
		if(contents.len == 1)  // Empty
			icon_state = "morgue1"
		else
			icon_state = "morgue2" // Dead, brainded mob.
			var/list/compiled = recursive_mob_check(src, 0, 0) // Search for mobs in all contents.
			if(!length(compiled)) // No mobs?
				icon_state = "morgue3"
				return
			for(var/mob/living/M in compiled)
				if(M.client)
					icon_state = "morgue4" // Cloneable
					break

/*
 * Crematorium
 */
var/global/list/crematoriums = new/list()
/obj/structure/bodycontainer/crematorium
	name = "crematorium"
	desc = "A human incinerator. Works well on barbeque nights."
	icon_state = "crema1"
	opendir = SOUTH
	var/id = 1

/obj/structure/bodycontainer/crematorium/Destroy()
	crematoriums.Remove(src)
	return ..()

/obj/structure/bodycontainer/crematorium/New()
	connected = new/obj/structure/tray/c_tray(src)
	connected.connected = src

	crematoriums.Add(src)
	..()

/obj/structure/bodycontainer/crematorium/update_icon()
	if(!connected || connected.loc != src)
		icon_state = "crema0"
	else

		if(src.contents.len > 1)
			src.icon_state = "crema2"
		else
			src.icon_state = "crema1"

		if(locked)
			src.icon_state = "crema_active"

	return

/obj/structure/bodycontainer/crematorium/proc/cremate(mob/user)
	if(locked)
		return //don't let you cremate something twice or w/e

	if(contents.len <= 1)
		audible_message("<span class='italics'>You hear a hollow crackle.</span>")
		return

	else
		audible_message("<span class='italics'>You hear a roar as the crematorium activates.</span>")

		locked = 1
		update_icon()

		for(var/mob/living/M in contents)
			if (M.stat != DEAD)
				M.emote("scream")
			if(user)
				user.attack_log +="\[[time_stamp()]\] Cremated <b>[M]/[M.ckey]</b>"
				log_attack("\[[time_stamp()]\] <b>[user]/[user.ckey]</b> cremated <b>[M]/[M.ckey]</b>")
			else
				log_attack("\[[time_stamp()]\] <b>UNKNOWN</b> cremated <b>[M]/[M.ckey]</b>")
			M.death(1)
			if(M) //some animals get automatically deleted on death.
				M.ghostize()
				qdel(M)

		for(var/obj/O in contents) //obj instead of obj/item so that bodybags and ashes get destroyed. We dont want tons and tons of ash piling up
			if(O != connected) //Creamtorium does not burn hot enough to destroy the tray
				qdel(O)

		new /obj/effect/decal/cleanable/ash(src)
		sleep(30)
		locked = 0
		update_icon()
		playsound(src.loc, 'sound/machines/ding.ogg', 50, 1) //you horrible people


/*
 * Generic Tray
 * Parent class for morguetray and crematoriumtray
 * For overriding only
 */
/obj/structure/tray
	icon = 'icons/obj/stationobjs.dmi'
	density = 1
	layer = 2.9
	var/obj/structure/bodycontainer/connected = null
	anchored = 1
	pass_flags = LETPASSTHROW

/obj/structure/tray/Destroy()
	if(connected)
		connected.connected = null
		connected.update_icon()
		connected = null
	return ..()

/obj/structure/tray/attack_paw(mob/user)
	return src.attack_hand(user)

/obj/structure/tray/attack_hand(mob/user)
	if (src.connected)
		connected.close()
		add_fingerprint(user)
	else
		user << "<span class='warning'>That's not connected to anything!</span>"

/obj/structure/tray/MouseDrop_T(atom/movable/O as mob|obj, mob/user)
	if(!istype(O, /atom/movable) || O.anchored || !Adjacent(user) || !user.Adjacent(O) || O.loc == user)
		return
	if(!ismob(O))
		if(!istype(O, /obj/structure/closet/body_bag))
			return
	else
		var/mob/M = O
		if(M.buckled)
			return
	if(!ismob(user) || user.lying || user.incapacitated())
		return
	O.loc = src.loc
	if (user != O)
		visible_message("<span class='warning'>[user] stuffs [O] into [src].</span>")
	return

/*
 * Crematorium tray
 */
/obj/structure/tray/c_tray
	name = "crematorium tray"
	desc = "Apply body before burning."
	icon_state = "cremat"

/*
 * Morgue tray
 */
/obj/structure/tray/m_tray
	name = "morgue tray"
	desc = "Apply corpse before closing."
	icon_state = "morguet"

/obj/structure/tray/m_tray/CanPass(atom/movable/mover, turf/target, height=0)
	if(height == 0)
		return 1

	if(istype(mover) && mover.checkpass(PASSTABLE))
		return 1
	if(locate(/obj/structure/table) in get_turf(mover))
		return 1
	else
		return 0

/obj/structure/tray/m_tray/CanAStarPass(ID, dir, caller)
	. = !density
	if(ismovableatom(caller))
		var/atom/movable/mover = caller
		. = . || mover.checkpass(PASSTABLE)
