/obj/machinery/dominator
	name = "dominator"
	desc = "A visibly sinister device. Looks like you can break it if you hit it enough."
	icon = 'icons/obj/machines/dominator.dmi'
	icon_state = "dominator"
	density = 1
	anchored = 1
	layer = 3.6
	var/maxhealth = 200
	var/health = 200
	var/datum/gang/gang
	var/operating = 0	//0=standby or broken, 1=takeover
	var/warned = 0	//if this device has set off the warning at <3 minutes yet
	var/datum/effect_system/spark_spread/spark_system

/obj/machinery/dominator/tesla_act()
	qdel(src)

/obj/machinery/dominator/New()
	..()
	SetLuminosity(2)
	poi_list |= src
	spark_system = new
	spark_system.set_up(5, 1, src)

/obj/machinery/dominator/examine(mob/user)
	..()
	if(stat & BROKEN)
		user << "<span class='danger'>It looks completely busted.</span>"
		return

	var/time
	if(gang && isnum(gang.dom_timer))
		time = max(gang.dom_timer, 0)
		if(time > 0)
			user << "<span class='notice'>Hostile Takeover in progress. Estimated [time] seconds remain.</span>"
		else
			user << "<span class='notice'>Hostile Takeover of [station_name()] successful. Have a great day.</span>"
	else
		user << "<span class='notice'>System on standby.</span>"
	user << "<span class='danger'>System Integrity: [round((health/maxhealth)*100,1)]%</span>"

/obj/machinery/dominator/process()
	..()
	if(gang && isnum(gang.dom_timer))
		if(gang.dom_timer > 0)
			playsound(loc, 'sound/items/timer.ogg', 10, 0)
			if(!warned && (gang.dom_timer < 180))
				warned = 1
				var/area/domloc = get_area(loc)
				gang.message_gangtools("Less than 3 minutes remain in hostile takeover. Defend your dominator at [domloc.map_name]!")
				for(var/datum/gang/G in ticker.mode.gangs)
					if(G != gang)
						G.message_gangtools("WARNING: [gang.name] Gang takeover imminent. Their dominator at [domloc.map_name] must be destroyed!",1,1)
		else
			SSmachine.processing -= src

/obj/machinery/dominator/take_damage(damage, damage_type = BRUTE, sound_effect = 1)
	switch(damage_type)
		if(BURN)
			if(sound_effect)
				playsound(src.loc, 'sound/items/Welder.ogg', 100, 1)
		if(BRUTE)
			if(sound_effect)
				if(damage)
					playsound(src, 'sound/effects/bang.ogg', 50, 1)
				else
					playsound(loc, 'sound/weapons/tap.ogg', 50, 1)
		else
			return
	health -= damage

	if(health > (maxhealth/2))
		if(prob(damage*2))
			spark_system.start()
	else if(!(stat & BROKEN))
		spark_system.start()
		overlays += "damage"

	if(!(stat & BROKEN))
		if(health <= 0)
			set_broken()

	if(health <= -100)
		new /obj/item/stack/sheet/plasteel(src.loc)
		qdel(src)

/obj/machinery/dominator/proc/set_broken()
	if(gang)
		gang.dom_timer = "OFFLINE"

		var/takeover_in_progress = 0
		for(var/datum/gang/G in ticker.mode.gangs)
			if(isnum(G.dom_timer))
				takeover_in_progress = 1
				break
		if(!takeover_in_progress)
			SSshuttle.emergencyNoEscape = 0
			if(SSshuttle.emergency.mode == SHUTTLE_STRANDED)
				SSshuttle.emergency.mode = SHUTTLE_DOCKED
				SSshuttle.emergency.timer = world.time
				priority_announce("Hostile enviroment resolved. You have 3 minutes to board the Emergency Shuttle.", null, 'sound/AI/shuttledock.ogg', "Priority")
			else
				priority_announce("All hostile activity within station systems have ceased.","Network Alert")

			if(get_security_level() == "delta")
				set_security_level("red")

		gang.message_gangtools("Hostile takeover cancelled: Dominator is no longer operational.[gang.dom_attempts ? " You have [gang.dom_attempts] attempt remaining." : " The station network will have likely blocked any more attempts by us."]",1,1)

	SetLuminosity(0)
	icon_state = "dominator-broken"
	overlays.Cut()
	operating = 0
	stat |= BROKEN
	SSmachine.processing -= src

/obj/machinery/dominator/Destroy()
	if(!(stat & BROKEN))
		set_broken()
	poi_list.Remove(src)
	qdel(spark_system)
	return ..()

/obj/machinery/dominator/emp_act(severity)
	take_damage(100, BURN, 0)
	..()

/obj/machinery/dominator/ex_act(severity, target)
	if(target == src)
		qdel(src)
		return
	switch(severity)
		if(1)
			qdel(src)
		if(2)
			take_damage(120, BRUTE, 0)
		if(3)
			take_damage(30, BRUTE, 0)
	return

/obj/machinery/dominator/bullet_act(obj/item/projectile/P)
	. = ..()
	if(P.damage)
		var/damage_amount = P.damage
		if(P.forcedodge)
			damage_amount *= 0.5
		visible_message("<span class='danger'>[src] was hit by [P].</span>")
		take_damage(damage_amount, P.damage_type, 0)


/obj/machinery/dominator/blob_act(obj/effect/blob/B)
	take_damage(110, BRUTE, 0)

/obj/machinery/dominator/attack_hand(mob/user)
	if(operating || (stat & BROKEN))
		examine(user)
		return

	var/datum/gang/tempgang

	if(user.mind in ticker.mode.get_all_gangsters())
		tempgang = user.mind.gang_datum
	else
		examine(user)
		return

	if(isnum(tempgang.dom_timer))
		user << "<span class='warning'>Error: Hostile Takeover is already in progress.</span>"
		return

	if(!tempgang.dom_attempts)
		user << "<span class='warning'>Error: Unable to breach station network. Firewall has logged our signature and is blocking all further attempts.</span>"
		return

	var/time = round(get_domination_time(tempgang)/60,0.1)
	if(alert(user,"With [round((tempgang.territory.len/start_state.num_territories)*100, 1)]% station control, a takeover will require [time] minutes.\nYour gang will be unable to gain influence while it is active.\nThe entire station will likely be alerted to it once it starts.\nYou have [tempgang.dom_attempts] attempt(s) remaining. Are you ready?","Confirm","Ready","Later") == "Ready")
		if (isnum(tempgang.dom_timer) || !tempgang.dom_attempts || !in_range(src, user) || !istype(src.loc, /turf))
			return 0

		var/area/A = get_area(loc)
		var/locname = initial(A.name)

		gang = tempgang
		gang.dom_attempts --
		priority_announce("Network breach detected in [locname]. The [gang.name] Gang is attempting to seize control of the station!","Network Alert")
		gang.domination()
		src.name = "[gang.name] Gang [src.name]"
		operating = 1
		icon_state = "dominator-[gang.color]"
		SetLuminosity(3)
		SSmachine.processing += src

		gang.message_gangtools("Hostile takeover in progress: Estimated [time] minutes until victory.[gang.dom_attempts ? "" : " This is your final attempt."]")
		for(var/datum/gang/G in ticker.mode.gangs)
			if(G != gang)
				G.message_gangtools("Enemy takeover attempt detected in [locname]: Estimated [time] minutes until our defeat.",1,1)

/obj/machinery/dominator/attack_hulk(mob/user)
	user.visible_message("<span class='danger'>[user] smashes [src].</span>",\
	"<span class='danger'>You punch [src].</span>",\
	"<span class='italics'>You hear metal being slammed.</span>")
	take_damage(5)

/obj/machinery/dominator/attacked_by(obj/item/I, mob/living/user)
	add_fingerprint(user)
	..()


