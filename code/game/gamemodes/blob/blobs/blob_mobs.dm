
////////////////
// BASE TYPE //
////////////////

//Do not spawn
/mob/living/simple_animal/hostile/blob
	icon = 'icons/mob/blob.dmi'
	pass_flags = PASSBLOB
	faction = list("blob")
	bubble_icon = "blob"
	speak_emote = null //so we use verb_yell/verb_say/etc
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	minbodytemp = 0
	maxbodytemp = 360
	unique_name = 1
	a_intent = "harm"
	var/mob/camera/blob/overmind = null
	var/obj/effect/blob/factory/factory = null

/mob/living/simple_animal/hostile/blob/update_icons()
	if(overmind)
		color = overmind.blob_reagent_datum.color
	else
		color = initial(color)

/mob/living/simple_animal/hostile/blob/Destroy()
	if(overmind)
		overmind.blob_mobs -= src
	return ..()

/mob/living/simple_animal/hostile/blob/blob_act(obj/effect/blob/B)
	if(stat != DEAD && health < maxHealth)
		for(var/i in 1 to 2)
			var/obj/effect/overlay/temp/heal/H = PoolOrNew(/obj/effect/overlay/temp/heal, get_turf(src)) //hello yes you are being healed
			if(overmind)
				H.color = overmind.blob_reagent_datum.complementary_color
			else
				H.color = "#000000"
		adjustHealth(-maxHealth*0.0125)

/mob/living/simple_animal/hostile/blob/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	..()
	adjustFireLoss(Clamp(0.01 * exposed_temperature, 1, 5))

/mob/living/simple_animal/hostile/blob/CanPass(atom/movable/mover, turf/target, height = 0)
	if(istype(mover, /obj/effect/blob))
		return 1
	return ..()

/mob/living/simple_animal/hostile/blob/Process_Spacemove(movement_dir = 0)
	for(var/obj/effect/blob/B in range(1, src))
		return 1
	return ..()

/mob/living/simple_animal/hostile/blob/handle_inherent_channels(message, message_mode)
	if(message_mode == MODE_BINARY)
		blob_chat(message)
		return ITALICS | REDUCE_RANGE
	else
		..()

/mob/living/simple_animal/hostile/blob/proc/blob_chat(msg)
	var/spanned_message = say_quote(msg, get_spans())
	var/rendered = "<font color=\"#EE4000\"><b>\[Blob Telepathy\] [real_name]</b> [spanned_message]</font>"
	for(var/M in mob_list)
		if(isovermind(M) || istype(M, /mob/living/simple_animal/hostile/blob))
			M << rendered
		if(isobserver(M))
			M << "<a href='?src=\ref[M];follow=\ref[src]'>(F)</a> [rendered]"

////////////////
// BLOB SPORE //
////////////////

/mob/living/simple_animal/hostile/blob/blobspore
	name = "blob spore"
	desc = "A floating, fragile spore."
	icon_state = "blobpod"
	icon_living = "blobpod"
	health = 40
	maxHealth = 40
	verb_say = "psychically pulses"
	verb_ask = "psychically probes"
	verb_exclaim = "psychically yells"
	verb_yell = "psychically screams"
	melee_damage_lower = 2
	melee_damage_upper = 4
	attacktext = "hits"
	attack_sound = 'sound/weapons/genhit1.ogg'
	flying = 1
	var/death_cloud_size = 1 //size of cloud produced from a dying spore
	var/list/human_overlays = list()
	var/is_zombie = 0
	gold_core_spawnable = 1

/mob/living/simple_animal/hostile/blob/blobspore/New(loc, var/obj/effect/blob/factory/linked_node)
	if(istype(linked_node))
		factory = linked_node
		factory.spores += src
	..()

/mob/living/simple_animal/hostile/blob/blobspore/Life()
	if(!is_zombie && isturf(src.loc))
		for(var/mob/living/carbon/human/H in view(src,1)) //Only for corpse right next to/on same tile
			if(H.stat == DEAD)
				Zombify(H)
				break
	if(factory && z != factory.z)
		death()
	..()

/mob/living/simple_animal/hostile/blob/blobspore/proc/Zombify(mob/living/carbon/human/H)
	is_zombie = 1
	if(H.wear_suit)
		var/obj/item/clothing/suit/armor/A = H.wear_suit
		if(A.armor && A.armor["melee"])
			maxHealth += A.armor["melee"] //That zombie's got armor, I want armor!
	maxHealth += 40
	health = maxHealth
	name = "blob zombie"
	desc = "A shambling corpse animated by the blob."
	melee_damage_lower += 8
	melee_damage_upper += 11
	flying = 0
	death_cloud_size = 0
	icon = H.icon
	icon_state = "zombie_s"
	H.hair_style = null
	H.update_hair()
	human_overlays = H.overlays
	update_icons()
	H.loc = src
	visible_message("<span class='warning'>The corpse of [H.name] suddenly rises!</span>")

/mob/living/simple_animal/hostile/blob/blobspore/death(gibbed)
	..(1)
	// On death, create a small smoke of harmful gas (s-Acid)
	var/datum/effect_system/smoke_spread/chem/S = new
	var/turf/location = get_turf(src)

	// Create the reagents to put into the air
	create_reagents(10)

	if(overmind && overmind.blob_reagent_datum)
		reagents.add_reagent(overmind.blob_reagent_datum.id, 10)
	else
		reagents.add_reagent("spore", 10)

	// Attach the smoke spreader and setup/start it.
	S.attach(location)
	S.set_up(reagents, death_cloud_size, location, silent=1)
	S.start()

	ghostize()
	qdel(src)

/mob/living/simple_animal/hostile/blob/blobspore/Destroy()
	if(factory)
		factory.spores -= src
	factory = null
	if(contents)
		for(var/mob/M in contents)
			M.loc = src.loc
	return ..()

/mob/living/simple_animal/hostile/blob/blobspore/update_icons()
	..()
	if(is_zombie)
		overlays.Cut()
		overlays = human_overlays
		var/image/I = image('icons/mob/blob.dmi', icon_state = "blob_head")
		if(overmind)
			I.color = overmind.blob_reagent_datum.color
		color = initial(color)//looks better.
		overlays += I

/mob/living/simple_animal/hostile/blob/blobspore/weak
	name = "fragile blob spore"
	health = 20
	maxHealth = 20
	melee_damage_lower = 1
	melee_damage_upper = 2
	death_cloud_size = 0

/////////////////
// BLOBBERNAUT //
/////////////////

/mob/living/simple_animal/hostile/blob/blobbernaut
	name = "blobbernaut"
	desc = "A hulking, mobile chunk of blobmass."
	icon_state = "blobbernaut"
	icon_living = "blobbernaut"
	icon_dead = "blobbernaut_dead"
	health = 200
	maxHealth = 200
	damage_coeff = list(BRUTE = 0.5, BURN = 1, TOX = 1, CLONE = 1, STAMINA = 0, OXY = 1)
	next_move_modifier = 1.5 //slow-ass attack speed, 3 times higher than how fast the blob can attack
	melee_damage_lower = 20
	melee_damage_upper = 20
	attacktext = "slams"
	attack_sound = 'sound/effects/blobattack.ogg'
	verb_say = "gurgles"
	verb_ask = "demands"
	verb_exclaim = "roars"
	verb_yell = "bellows"
	force_threshold = 10
	pressure_resistance = 40
	mob_size = MOB_SIZE_LARGE
	see_invisible = SEE_INVISIBLE_MINIMUM
	see_in_dark = 8

/mob/living/simple_animal/hostile/blob/blobbernaut/New()
	..()
	verbs -= /mob/living/verb/pulled //no pulling people deep into the blob

/mob/living/simple_animal/hostile/blob/blobbernaut/Life()
	if(..())
		var/damagesources = 0
		if(!(locate(/obj/effect/blob) in range(2, src)))
			damagesources++
		if(!factory)
			damagesources++
		if(damagesources)
			for(var/i in 1 to damagesources)
				adjustHealth(maxHealth*0.025) //take 2.5% maxhealth as damage when not near the blob or if the naut has no factory, 5% if both
			var/list/viewing = list()
			for(var/mob/M in viewers(src))
				if(M.client)
					viewing += M.client
			var/image/I = new('icons/mob/blob.dmi', src, "nautdamage", MOB_LAYER+0.01)
			I.appearance_flags = RESET_COLOR
			if(overmind)
				I.color = overmind.blob_reagent_datum.complementary_color
			flick_overlay(I, viewing, 8)

/mob/living/simple_animal/hostile/blob/blobbernaut/adjustHealth(amount)
	. = ..()
	update_health_hud()

/mob/living/simple_animal/hostile/blob/blobbernaut/update_health_hud()
	if(hud_used)
		hud_used.healths.maptext = "<div align='center' valign='middle' style='position:relative; top:0px; left:6px'><font color='#e36600'>[round((health / maxHealth) * 100, 0.5)]%</font></div>"

/mob/living/simple_animal/hostile/blob/blobbernaut/AttackingTarget()
	if(isliving(target))
		if(overmind)
			var/mob/living/L = target
			var/mob_protection = L.get_permeability_protection()
			overmind.blob_reagent_datum.reaction_mob(L, VAPOR, 20, 0, mob_protection, overmind)//this will do between 10 and 20 damage(reduced by mob protection), depending on chemical, plus 4 from base brute damage.
	if(target)
		..()

/mob/living/simple_animal/hostile/blob/blobbernaut/update_icons()
	..()
	if(overmind) //if we have an overmind, we're doing chemical reactions instead of pure damage
		melee_damage_lower = 4
		melee_damage_upper = 4
		attacktext = overmind.blob_reagent_datum.blobbernaut_message
	else
		melee_damage_lower = initial(melee_damage_lower)
		melee_damage_upper = initial(melee_damage_upper)
		attacktext = initial(attacktext)

/mob/living/simple_animal/hostile/blob/blobbernaut/death(gibbed)
	..(gibbed)
	if(factory)
		factory.naut = null //remove this naut from its factory
		factory.maxhealth = initial(factory.maxhealth)
	flick("blobbernaut_death", src)
