/obj/item/organ/heart/gland
	name = "fleshy mass"
	desc = "A nausea-inducing hunk of twisting flesh and metal."
	icon = 'icons/obj/abductor.dmi'
	icon_state = "gland"
	status = ORGAN_ROBOTIC
	organ_flags = NONE
	beating = TRUE
	var/true_name = "baseline placebo referencer"

	/// The minimum time between activations
	var/cooldown_low = 30 SECONDS
	/// The maximum time between activations
	var/cooldown_high = 30 SECONDS
	/// The cooldown for activations
	COOLDOWN_DECLARE(activation_cooldown)
	/// The number of remaining uses this gland has.
	var/uses = 0 // -1 For infinite
	var/human_only = FALSE
	var/active = FALSE

	var/mind_control_uses = 1
	var/mind_control_duration = 1800
	var/active_mind_control = FALSE

/obj/item/organ/heart/gland/Initialize(mapload)
	. = ..()
	icon_state = pick(list("health", "spider", "slime", "emp", "species", "egg", "vent", "mindshock", "viral"))

/obj/item/organ/heart/gland/examine(mob/user)
	. = ..()
	if(HAS_TRAIT(user.mind, TRAIT_ABDUCTOR_SCIENTIST_TRAINING) || isobserver(user))
		. += span_notice("It is \a [true_name].")

/obj/item/organ/heart/gland/proc/ownerCheck()
	if(ishuman(owner))
		return TRUE
	if(!human_only && iscarbon(owner))
		return TRUE
	return FALSE

/obj/item/organ/heart/gland/proc/Start()
	active = 1
	COOLDOWN_START(src, activation_cooldown, rand(cooldown_low, cooldown_high))

/obj/item/organ/heart/gland/proc/update_gland_hud()
	if(!owner)
		return
	var/image/holder = owner.hud_list[GLAND_HUD]
	var/icon/I = icon(owner.icon, owner.icon_state, owner.dir)
	holder.pixel_y = I.Height() - world.icon_size
	if(active_mind_control)
		holder.icon_state = "hudgland_active"
	else if(mind_control_uses)
		holder.icon_state = "hudgland_ready"
	else
		holder.icon_state = "hudgland_spent"

/obj/item/organ/heart/gland/proc/mind_control(command, mob/living/user)
	if(!ownerCheck() || !mind_control_uses || active_mind_control)
		return
	mind_control_uses--
	to_chat(owner, span_userdanger("You suddenly feel an irresistible compulsion to follow an order..."))
	to_chat(owner, "[span_mindcontrol("[command]")]")
	active_mind_control = TRUE
	log_admin("[key_name(user)] sent an abductor mind control message to [key_name(owner)]: [command]")
	deadchat_broadcast(span_deadsay("[span_name("[user]")] sent an abductor mind control message to [span_name("[owner]")]: [span_boldmessage("[command]")]"), follow_target = owner, turf_target = get_turf(owner), message_type = DEADCHAT_REGULAR)
	update_gland_hud()
	var/atom/movable/screen/alert/mind_control/mind_alert = owner.throw_alert("mind_control", /atom/movable/screen/alert/mind_control)
	mind_alert.command = command
	addtimer(CALLBACK(src, PROC_REF(clear_mind_control)), mind_control_duration)

/obj/item/organ/heart/gland/proc/clear_mind_control()
	if(!ownerCheck() || !active_mind_control)
		return
	to_chat(owner, span_userdanger("You feel the compulsion fade, and you <i>completely forget</i> about your previous orders."))
	owner.clear_alert("mind_control")
	active_mind_control = FALSE

/obj/item/organ/heart/gland/Remove(mob/living/carbon/gland_owner, special = FALSE, pref_load = FALSE)
	. = ..()
	active = FALSE
	if(initial(uses) == 1)
		uses = initial(uses)
	var/datum/atom_hud/abductor/hud = GLOB.huds[DATA_HUD_ABDUCTOR]
	hud.remove_from_hud(gland_owner)
	clear_mind_control()

/obj/item/organ/heart/gland/Insert(mob/living/carbon/gland_owner, special = FALSE, drop_if_replaced = TRUE)
	. = ..()
	if(!.)
		return

	if(special != 2 && uses) // Special 2 means abductor surgery
		Start()
	var/datum/atom_hud/abductor/hud = GLOB.huds[DATA_HUD_ABDUCTOR]
	hud.add_to_hud(gland_owner)
	update_gland_hud()

/obj/item/organ/heart/gland/on_life(delta_time, times_fired)
	SHOULD_CALL_PARENT(FALSE)
	if(!beating)
		// alien glands are immune to stopping.
		beating = TRUE
	if(!active)
		return
	if(!ownerCheck())
		active = FALSE
		return
	if(COOLDOWN_FINISHED(src, activation_cooldown))
		activate()
		uses--
		COOLDOWN_START(src, activation_cooldown, rand(cooldown_low, cooldown_high))
	if(!uses)
		active = FALSE

/obj/item/organ/heart/gland/proc/activate()
	return

/obj/item/organ/heart/gland/heals
	true_name = "coherency harmonizer"
	cooldown_low = 200
	cooldown_high = 400
	uses = -1
	icon_state = "health"
	mind_control_uses = 3
	mind_control_duration = 3000

/obj/item/organ/heart/gland/heals/activate()
	to_chat(owner, span_notice("You feel curiously revitalized."))
	owner.adjustToxLoss(-20, FALSE, TRUE)
	owner.heal_bodypart_damage(20, 20, 0, TRUE)
	owner.adjustOxyLoss(-20)

/obj/item/organ/heart/gland/slime
	true_name = "gastric animation galvanizer"
	cooldown_low = 600
	cooldown_high = 1200
	uses = -1
	icon_state = "slime"
	mind_control_uses = 1
	mind_control_duration = 2400

/obj/item/organ/heart/gland/slime/on_insert(mob/living/carbon/gland_owner)
	. = ..()
	owner.faction |= FACTION_SLIME
	owner.grant_language(/datum/language/slime, source = LANGUAGE_GLAND)

/obj/item/organ/heart/gland/slime/on_remove(mob/living/carbon/gland_owner)
	. = ..()
	if(!owner) // Add null check
		return
	owner.faction -= FACTION_SLIME
	owner.remove_language(/datum/language/slime, source = LANGUAGE_GLAND)

/obj/item/organ/heart/gland/slime/activate()
	to_chat(owner, span_warning("You feel nauseated!"))
	owner.vomit(20)

	var/mob/living/simple_animal/slime/Slime = new(get_turf(owner), "grey")
	Slime.set_friends(list(owner))
	Slime.set_leader(owner)

/obj/item/organ/heart/gland/mindshock
	true_name = "neural crosstalk uninhibitor"
	cooldown_low = 400
	cooldown_high = 700
	uses = -1
	icon_state = "mindshock"
	mind_control_uses = 1
	mind_control_duration = 6000

/obj/item/organ/heart/gland/mindshock/activate()
	to_chat(owner, span_notice("You get a headache."))

	var/turf/T = get_turf(owner)
	for(var/mob/living/carbon/H in orange(4,T))
		if(H == owner)
			continue
		switch(pick(1,3))
			if(1)
				to_chat(H, span_userdanger("You hear a loud buzz in your head, silencing your thoughts!"))
				H.Stun(50)
			if(2)
				to_chat(H, span_warning("You hear an annoying buzz in your head."))
				H.confused += 15
				H.adjustOrganLoss(ORGAN_SLOT_BRAIN, 10, 160)
			if(3)
				H.hallucination += 60

/obj/item/organ/heart/gland/pop
	true_name = "anthropmorphic translocator"
	cooldown_low = 900
	cooldown_high = 1800
	uses = -1
	human_only = TRUE
	icon_state = "species"
	mind_control_uses = 5
	mind_control_duration = 300

/obj/item/organ/heart/gland/pop/activate()
	to_chat(owner, span_notice("You feel unlike yourself."))
	randomize_human(owner, TRUE)
	var/species = pick(list(/datum/species/human, /datum/species/lizard, /datum/species/moth, /datum/species/fly))
	owner.set_species(species)

/obj/item/organ/heart/gland/ventcrawling
	true_name = "pliant cartilage enabler"
	cooldown_low = 1800
	cooldown_high = 2400
	uses = 1
	icon_state = "vent"
	mind_control_uses = 4
	mind_control_duration = 1800

/obj/item/organ/heart/gland/ventcrawling/activate()
	to_chat(owner, span_notice("You feel very stretchy."))
	owner.ventcrawler = VENTCRAWLER_ALWAYS

/obj/item/organ/heart/gland/viral
	true_name = "contamination incubator"
	cooldown_low = 1800
	cooldown_high = 2400
	uses = 1
	icon_state = "viral"
	mind_control_uses = 1
	mind_control_duration = 1800

/obj/item/organ/heart/gland/viral/activate()
	to_chat(owner, span_warning("You feel sick."))
	var/datum/disease/advance/A = random_virus(pick(2,6),6)
	A.carrier = TRUE
	owner.ForceContractDisease(A, FALSE, TRUE)

/obj/item/organ/heart/gland/viral/proc/random_virus(max_symptoms, max_level)
	if(max_symptoms > VIRUS_SYMPTOM_LIMIT)
		max_symptoms = VIRUS_SYMPTOM_LIMIT
	var/datum/disease/advance/A = new /datum/disease/advance()
	var/list/datum/symptom/possible_symptoms = list()
	for(var/symptom in subtypesof(/datum/symptom))
		var/datum/symptom/S = symptom
		if(initial(S.level) > max_level)
			continue
		if(initial(S.level) <= 0) //unobtainable symptoms
			continue
		possible_symptoms += S
	for(var/i in 1 to max_symptoms)
		var/datum/symptom/chosen_symptom = pick_n_take(possible_symptoms)
		if(chosen_symptom)
			var/datum/symptom/S = new chosen_symptom
			A.symptoms += S
	A.Refresh() //just in case someone already made and named the same disease
	A.Finalize()
	return A

/obj/item/organ/heart/gland/trauma
	true_name = "white matter randomiser"
	cooldown_low = 800
	cooldown_high = 1200
	uses = 5
	icon_state = "emp"
	mind_control_uses = 3
	mind_control_duration = 1800

/obj/item/organ/heart/gland/trauma/activate()
	to_chat(owner, span_warning("You feel a spike of pain in your head."))
	if(prob(33))
		owner.gain_trauma_type(BRAIN_TRAUMA_SPECIAL, rand(TRAUMA_RESILIENCE_BASIC, TRAUMA_RESILIENCE_LOBOTOMY))
	else
		if(prob(20))
			owner.gain_trauma_type(BRAIN_TRAUMA_SEVERE, rand(TRAUMA_RESILIENCE_BASIC, TRAUMA_RESILIENCE_LOBOTOMY))
		else
			owner.gain_trauma_type(BRAIN_TRAUMA_MILD, rand(TRAUMA_RESILIENCE_BASIC, TRAUMA_RESILIENCE_LOBOTOMY))

/obj/item/organ/heart/gland/spiderman
	true_name = "araneae cloister accelerator"
	cooldown_low = 450
	cooldown_high = 900
	uses = -1
	icon_state = "spider"
	mind_control_uses = 2
	mind_control_duration = 2400

/obj/item/organ/heart/gland/spiderman/activate()
	to_chat(owner, span_warning("You feel something crawling in your skin."))
	owner.faction |= FACTION_SPIDER
	new /obj/structure/spider/spiderling(owner.drop_location())

/obj/item/organ/heart/gland/egg
	true_name = "roe/enzymatic synthesizer"
	cooldown_low = 300
	cooldown_high = 400
	uses = -1
	icon_state = "egg"
	lefthand_file = 'icons/mob/inhands/misc/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/food_righthand.dmi'
	mind_control_uses = 2
	mind_control_duration = 1800

/obj/item/organ/heart/gland/egg/activate()
	owner.visible_message(span_alertalien("[owner] [pick(EGG_LAYING_MESSAGES)]"))
	var/turf/T = owner.drop_location()
	new /obj/item/food/egg/gland(T)

/obj/item/organ/heart/gland/electric
	true_name = "electron accumulator/discharger"
	cooldown_low = 800
	cooldown_high = 1200
	uses = -1
	mind_control_uses = 2
	mind_control_duration = 900

/obj/item/organ/heart/gland/electric/on_insert(mob/living/carbon/gland_owner)
	. = ..()
	ADD_TRAIT(gland_owner, TRAIT_SHOCKIMMUNE, ABDUCTOR_GLAND_TRAIT)

/obj/item/organ/heart/gland/electric/on_remove(mob/living/carbon/gland_owner)
	. = ..()
	REMOVE_TRAIT(gland_owner, TRAIT_SHOCKIMMUNE, ABDUCTOR_GLAND_TRAIT)

/obj/item/organ/heart/gland/electric/activate()
	owner.visible_message(span_danger("[owner]'s skin starts emitting electric arcs!"),\
	span_warning("You feel electric energy building up inside you!"))
	playsound(get_turf(owner), "sparks", 100, 1, -1)
	addtimer(CALLBACK(src, PROC_REF(zap)), rand(30, 100))

/obj/item/organ/heart/gland/electric/proc/zap()
	tesla_zap(owner, 4, 8000, TESLA_MOB_DAMAGE | TESLA_OBJ_DAMAGE | TESLA_MOB_STUN)
	playsound(get_turf(owner), 'sound/magic/lightningshock.ogg', 50, 1)

/obj/item/organ/heart/gland/chem
	true_name = "intrinsic pharma-provider"
	cooldown_low = 50
	cooldown_high = 50
	uses = -1
	mind_control_uses = 3
	mind_control_duration = 1200
	var/list/possible_reagents = list()

/obj/item/organ/heart/gland/chem/Initialize(mapload)
	. = ..()
	for(var/R in subtypesof(/datum/reagent/drug) + subtypesof(/datum/reagent/medicine) + typesof(/datum/reagent/toxin))
		possible_reagents += R

/obj/item/organ/heart/gland/chem/activate()
	var/chem_to_add = pick(possible_reagents)
	owner.reagents.add_reagent(chem_to_add, 2)
	owner.adjustToxLoss(-2, TRUE, TRUE)
	..()

/obj/item/organ/heart/gland/plasma
	true_name = "effluvium sanguine-synonym emitter"
	cooldown_low = 1200
	cooldown_high = 1800
	uses = -1
	mind_control_uses = 1
	mind_control_duration = 800

/obj/item/organ/heart/gland/plasma/activate()
	to_chat(owner, span_warning("You feel bloated."))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(to_chat), owner, span_userdanger("A massive stomachache overcomes you.")), 150)
	addtimer(CALLBACK(src, PROC_REF(vomit_plasma)), 200)

/obj/item/organ/heart/gland/plasma/proc/vomit_plasma()
	if(!owner)
		return
	owner.visible_message(span_danger("[owner] vomits a cloud of plasma!"))
	var/turf/open/T = get_turf(owner)
	if(istype(T))
		T.atmos_spawn_air("plasma=50;TEMP=[T20C]")
	owner.vomit()
