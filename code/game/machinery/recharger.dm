/obj/machinery/recharger
	name = "recharger"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "recharger0"
	desc = "A charging dock for energy based weaponry."
	anchored = 1
	use_power = 1
	idle_power_usage = 4
	active_power_usage = 250
	var/obj/item/weapon/charging = null
	var/recharge_coeff = 1

/obj/machinery/recharger/New()
	..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/recharger()
	component_parts += new /obj/item/weapon/stock_parts/capacitor()
	RefreshParts()

/obj/machinery/recharger/RefreshParts()
	for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
		recharge_coeff = C.rating

/obj/machinery/recharger/attackby(obj/item/weapon/G, mob/user, params)
	if(istype(G, /obj/item/weapon/wrench))
		if(charging)
			user << "<span class='notice'>Remove the charging item first!</span>"
			return
		anchored = !anchored
		power_change()
		user << "<span class='notice'>You [anchored ? "attached" : "detached"] [src].</span>"
		playsound(loc, 'sound/items/Ratchet.ogg', 75, 1)
		return

	if(istype(G, /obj/item/weapon/gun/energy) || istype(G, /obj/item/weapon/melee/baton) || istype(G, /obj/item/ammo_box/magazine/recharge))
		if(anchored)
			if(charging || panel_open)
				return 1

			//Checks to make sure he's not in space doing it, and that the area got proper power.
			var/area/a = get_area(src)
			if(!isarea(a) || a.power_equip == 0)
				user << "<span class='notice'>[src] blinks red as you try to insert [G].</span>"
				return 1

			if (istype(G, /obj/item/weapon/gun/energy))
				var/obj/item/weapon/gun/energy/gun = G
				if(!gun.can_charge)
					user << "<span class='notice'>Your gun has no external power connector.</span>"
					return 1

			if(!user.drop_item())
				return 1
			G.loc = src
			charging = G
			use_power = 2
			update_icon()
		else
			user << "<span class='notice'>[src] isn't connected to anything!</span>"
		return 1

	if(anchored && !charging)
		if(default_deconstruction_screwdriver(user, "rechargeropen", "recharger0", G))
			return

		if(panel_open && istype(G, /obj/item/weapon/crowbar))
			default_deconstruction_crowbar(G)
			return

		if(exchange_parts(user, G))
			return
	return ..()

/obj/machinery/recharger/attack_hand(mob/user)
	if(issilicon(user))
		return

	add_fingerprint(user)
	if(charging)
		charging.update_icon()
		charging.loc = loc
		user.put_in_hands(charging)
		charging = null
		use_power = 1
		update_icon()

/obj/machinery/recharger/attack_paw(mob/user)
	return attack_hand(user)

/obj/machinery/recharger/attack_tk(mob/user)
	if(charging)
		charging.update_icon()
		charging.loc = loc
		charging = null
		use_power = 1
		update_icon()

/obj/machinery/recharger/process()
	if(stat & (NOPOWER|BROKEN) || !anchored)
		return

	var/using_power = 0
	if(charging)
		if(istype(charging, /obj/item/weapon/gun/energy))
			var/obj/item/weapon/gun/energy/E = charging
			if(E.power_supply.charge < E.power_supply.maxcharge)
				E.power_supply.give(E.power_supply.chargerate * recharge_coeff)
				use_power(250 * recharge_coeff)
				using_power = 1


		if(istype(charging, /obj/item/weapon/melee/baton))
			var/obj/item/weapon/melee/baton/B = charging
			if(B.bcell)
				if(B.bcell.give(B.bcell.chargerate * recharge_coeff))
					use_power(200 * recharge_coeff)
					using_power = 1

		if(istype(charging, /obj/item/ammo_box/magazine/recharge))
			var/obj/item/ammo_box/magazine/recharge/R = charging
			if(R.stored_ammo.len < R.max_ammo)
				R.stored_ammo += new R.ammo_type(R)
				use_power(200 * recharge_coeff)
				using_power = 1

	update_icon(using_power)

/obj/machinery/recharger/power_change()
	..()
	update_icon()

/obj/machinery/recharger/emp_act(severity)
	if(stat & (NOPOWER|BROKEN) || !anchored)
		..(severity)
		return

	if(istype(charging,  /obj/item/weapon/gun/energy))
		var/obj/item/weapon/gun/energy/E = charging
		if(E.power_supply)
			E.power_supply.emp_act(severity)

	else if(istype(charging, /obj/item/weapon/melee/baton))
		var/obj/item/weapon/melee/baton/B = charging
		if(B.bcell)
			B.bcell.charge = 0
	..(severity)


/obj/machinery/recharger/update_icon(using_power = 0)	//we have an update_icon() in addition to the stuff in process to make it feel a tiny bit snappier.
	if(stat & (NOPOWER|BROKEN) || !anchored)
		icon_state = "rechargeroff"
		return
	if(panel_open)
		icon_state = "rechargeropen"
		return
	if(charging)
		if(using_power)
			icon_state = "recharger1"
		else
			icon_state = "recharger2"
		return
	icon_state = "recharger0"