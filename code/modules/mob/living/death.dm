/mob/living/gib(no_brain, no_organs)
	var/prev_lying = lying
	if(stat != DEAD)
		death(1)

	if(buckled)
		buckled.unbuckle_mob(src,force=1) //to update alien nest overlay, forced because we don't exist anymore

	if(!prev_lying)
		gib_animation()
	if(!no_organs)
		spill_organs(no_brain)
	spawn_gibs()
	qdel(src)

/mob/living/proc/gib_animation()
	return

/mob/living/proc/spawn_gibs()
	gibs(loc, viruses)

/mob/living/proc/spill_organs(no_brain)
	return


/mob/living/dust()
	death(1)

	if(buckled)
		buckled.unbuckle_mob(src,force=1)

	dust_animation()
	spawn_dust()
	qdel(src)

/mob/living/proc/dust_animation()
	return

/mob/living/proc/spawn_dust()
	new /obj/effect/decal/cleanable/ash(loc)


/mob/living/death(gibbed)
	unset_machine()
	timeofdeath = world.time
	tod = worldtime2text()
	if(mind)
		mind.store_memory("Time of death: [tod]", 0)
	living_mob_list -= src
	if(!gibbed)
		dead_mob_list += src
	else if(buckled)
		buckled.unbuckle_mob(src,force=1)
	paralysis = 0
	stunned = 0
	weakened = 0
	set_drugginess(0)
	SetSleeping(0, 0)
	blind_eyes(1)
	reset_perspective(null)
	hide_fullscreens()
	update_action_buttons_icon()
	update_damage_hud()
	update_health_hud()
	update_canmove()
