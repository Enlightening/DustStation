// Powersink - used to drain station power

/obj/item/device/powersink
	desc = "A nulling power sink which drains energy from electrical systems."
	name = "power sink"
	icon_state = "powersink0"
	item_state = "electronic"
	w_class = 4
	flags = CONDUCT
	throwforce = 5
	throw_speed = 1
	throw_range = 2
	materials = list(MAT_METAL=750)
	origin_tech = "powerstorage=3;syndicate=5"
	var/drain_rate = 1600000	// amount of power to drain per tick
	var/power_drained = 0 		// has drained this much power
	var/max_power = 1e10		// maximum power that can be drained before exploding
	var/mode = 0		// 0 = off, 1=clamped (off), 2=operating
	var/admins_warned = 0 // stop spam, only warn the admins once that we are about to boom

	var/const/DISCONNECTED = 0
	var/const/CLAMPED_OFF = 1
	var/const/OPERATING = 2

	var/obj/structure/cable/attached		// the attached cable

/obj/item/device/powersink/update_icon()
	icon_state = "powersink[mode == OPERATING]"

/obj/item/device/powersink/proc/set_mode(value)
	if(value == mode)
		return
	switch(value)
		if(DISCONNECTED)
			attached = null
			if(mode == OPERATING)
				SSobj.processing.Remove(src)
			anchored = 0

		if(CLAMPED_OFF)
			if(!attached)
				return
			if(mode == OPERATING)
				SSobj.processing.Remove(src)
			anchored = 1

		if(OPERATING)
			if(!attached)
				return
			SSobj.processing |= src
			anchored = 1

	mode = value
	update_icon()
	SetLuminosity(0)

/obj/item/device/powersink/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/weapon/screwdriver))
		if(mode == DISCONNECTED)
			var/turf/T = loc
			if(isturf(T) && !T.intact)
				attached = locate() in T
				if(!attached)
					user << "<span class='warning'>This device must be placed over an exposed, powered cable node!</span>"
				else
					set_mode(CLAMPED_OFF)
					user.visible_message( \
						"[user] attaches \the [src] to the cable.", \
						"<span class='notice'>You attach \the [src] to the cable.</span>",
						"<span class='italics'>You hear some wires being connected to something.</span>")
			else
				user << "<span class='warning'>This device must be placed over an exposed, powered cable node!</span>"
		else
			set_mode(DISCONNECTED)
			user.visible_message( \
				"[user] detaches \the [src] from the cable.", \
				"<span class='notice'>You detach \the [src] from the cable.</span>",
				"<span class='italics'>You hear some wires being disconnected from something.</span>")
	else
		return ..()

/obj/item/device/powersink/attack_paw()
	return

/obj/item/device/powersink/attack_ai()
	return

/obj/item/device/powersink/attack_hand(mob/user)
	switch(mode)
		if(DISCONNECTED)
			..()

		if(CLAMPED_OFF)
			user.visible_message( \
				"[user] activates \the [src]!", \
				"<span class='notice'>You activate \the [src].</span>",
				"<span class='italics'>You hear a click.</span>")
			message_admins("Power sink activated by [key_name_admin(user)](<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) (<A HREF='?_src_=holder;adminplayerobservefollow=\ref[user]'>FLW</A>) at ([x],[y],[z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>)")
			log_game("Power sink activated by [key_name(user)] at ([x],[y],[z])")
			set_mode(OPERATING)

		if(OPERATING)
			user.visible_message( \
				"[user] deactivates \the [src]!", \
				"<span class='notice'>You deactivate \the [src].</span>",
				"<span class='italics'>You hear a click.</span>")
			set_mode(CLAMPED_OFF)

/obj/item/device/powersink/process()
	if(!attached)
		set_mode(DISCONNECTED)
		return

	var/datum/powernet/PN = attached.powernet
	if(PN)
		SetLuminosity(5)

		// found a powernet, so drain up to max power from it

		var/drained = min ( drain_rate, PN.avail )
		PN.load += drained
		power_drained += drained

		// if tried to drain more than available on powernet
		// now look for APCs and drain their cells
		if(drained < drain_rate)
			for(var/obj/machinery/power/terminal/T in PN.nodes)
				if(istype(T.master, /obj/machinery/power/apc))
					var/obj/machinery/power/apc/A = T.master
					if(A.operating && A.cell)
						A.cell.charge = max(0, A.cell.charge - 50)
						power_drained += 50
						if(A.charging == 2) // If the cell was full
							A.charging = 1 // It's no longer full

	if(power_drained > max_power * 0.98)
		if (!admins_warned)
			admins_warned = 1
			message_admins("Power sink at ([x],[y],[z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>) is 95% full. Explosion imminent.")
		playsound(src, 'sound/effects/screech.ogg', 100, 1, 1)

	if(power_drained >= max_power)
		SSobj.processing.Remove(src)
		explosion(src.loc, 4,8,16,32)
		qdel(src)
