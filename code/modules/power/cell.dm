/obj/item/stock_parts/cell
	name = "power cell"
	desc = "A rechargeable electrochemical power cell."
	icon = 'icons/obj/power.dmi'
	icon_state = "cell"
	item_state = "cell"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	force = 5
	throwforce = 5
	throw_speed = 2
	throw_range = 5
	w_class = WEIGHT_CLASS_SMALL
	/// note %age converted to actual charge in New
	var/charge = 0
	var/maxcharge = 1000
	custom_materials = list(/datum/material/iron=700, /datum/material/glass=50)
	grind_results = list(/datum/reagent/lithium = 15, /datum/reagent/iron = 5, /datum/reagent/silicon = 5)
	/// If the cell has been booby-trapped by injecting it with plasma. Chance on use() to explode.
	var/rigged = FALSE
	/// If the power cell was damaged by an explosion, chance for it to become corrupted and function the same as rigged.
	var/corrupted = FALSE
	///how much power is given every tick in a recharger
	var/chargerate = 100
	///does it self recharge, over time, or not?
	var/self_recharge = FALSE
	///stores the chargerate to restore when hit with EMP, for slime cores
	var/emp_timer = 0
	var/ratingdesc = TRUE
	/// If it's a grown that acts as a battery, add a wire overlay to it.
	var/grown_battery = FALSE

/obj/item/stock_parts/cell/get_cell()
	return src

CREATION_TEST_IGNORE_SUBTYPES(/obj/item/stock_parts/cell)

/obj/item/stock_parts/cell/Initialize(mapload, override_maxcharge)
	. = ..()
	START_PROCESSING(SSobj, src)
	create_reagents(5, INJECTABLE | DRAINABLE)
	if (override_maxcharge)
		maxcharge = override_maxcharge
	charge = maxcharge
	if(ratingdesc)
		desc += " This one has a rating of [display_energy(maxcharge)], and you should not swallow it."
	update_appearance()

/obj/item/stock_parts/cell/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/stock_parts/cell/vv_edit_var(var_name, var_value)
	switch(var_name)
		if(NAMEOF(src, self_recharge))
			if(var_value)
				START_PROCESSING(SSobj, src)
			else
				STOP_PROCESSING(SSobj, src)
	. = ..()

/obj/item/stock_parts/cell/process(delta_time)
	if(emp_timer > world.time)
		return
	if(self_recharge)
		give(chargerate * 0.125 * delta_time)
	else
		return PROCESS_KILL

/obj/item/stock_parts/cell/update_overlays()
	. = ..()
	if(grown_battery)
		. += mutable_appearance('icons/obj/power.dmi', "grown_wires")
	if(charge < 0.01)
		return
	else if(charge/maxcharge >=0.995)
		. += "cell-o2"
	else
		. += "cell-o1"

/obj/item/stock_parts/cell/proc/percent() // return % charge of cell
	return maxcharge ? 100 * charge / maxcharge : 0 //Division by 0 protection

// use power from a cell
/obj/item/stock_parts/cell/use(amount)
	if(rigged && amount > 0)
		plasma_ignition(4)
		return 0
	if(charge < amount)
		return 0
	charge = (charge - amount)
	if(!istype(loc, /obj/machinery/power/apc))
		SSblackbox.record_feedback("tally", "cell_used", 1, type)
	return 1

// recharge the cell
/obj/item/stock_parts/cell/proc/give(amount)
	if(rigged && amount > 0)
		plasma_ignition(4)
		return 0
	if(maxcharge < amount)
		amount = maxcharge
	var/power_used = min(maxcharge-charge,amount)
	charge += power_used
	return power_used

/obj/item/stock_parts/cell/examine(mob/user)
	. = ..()
	if(rigged)
		. += span_danger("This power cell seems to be faulty!")
	else
		. += "The charge meter reads [round(src.percent() )]%."

/obj/item/stock_parts/cell/suicide_act(mob/living/user)
	user.visible_message(span_suicide("[user] is licking the electrodes of [src]! It looks like [user.p_theyre()] trying to commit suicide!"))
	return FIRELOSS

/obj/item/stock_parts/cell/on_reagent_change(changetype)
	rigged = (corrupted || reagents.has_reagent(/datum/reagent/toxin/plasma, 5)) //has_reagent returns the reagent datum
	return ..()


/obj/item/stock_parts/cell/proc/explode()
	var/turf/T = get_turf(src.loc)
	if (charge==0)
		return
	var/devastation_range = -1 //round(charge/11000)
	var/heavy_impact_range = round(sqrt(charge)/60)
	var/light_impact_range = round(sqrt(charge)/30)
	var/flash_range = light_impact_range
	if (light_impact_range==0)
		rigged = FALSE
		corrupt()
		return

	message_admins("[ADMIN_LOOKUPFLW(usr)] has triggered a rigged/corrupted power cell explosion at [AREACOORD(T)].")
	log_game("[key_name(usr)] has triggered a rigged/corrupted power cell explosion at [AREACOORD(T)].")

	//explosion(T, 0, 1, 2, 2)
	explosion(T, devastation_range, heavy_impact_range, light_impact_range, flash_range)
	qdel(src)

/obj/item/stock_parts/cell/proc/corrupt()
	charge /= 2
	maxcharge = max(maxcharge/2, chargerate)
	if (prob(10))
		rigged = TRUE //broken batterys are dangerous
		corrupted = TRUE

/obj/item/stock_parts/cell/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	charge -= 1000 / severity
	if (charge < 0)
		charge = 0
	if(self_recharge)
		emp_timer = world.time + 30 SECONDS


/obj/item/stock_parts/cell/ex_act(severity, target)
	..()
	if(!QDELETED(src))
		switch(severity)
			if(2)
				if(prob(50))
					corrupt()
			if(3)
				if(prob(25))
					corrupt()

/obj/item/stock_parts/cell/attack_self(mob/user)
	if(isethereal(user))
		var/mob/living/carbon/human/H = user
		var/datum/species/ethereal/E = H.dna.species
		if(E.drain_time > world.time)
			return
		var/obj/item/organ/stomach/battery/stomach = H.get_organ_slot(ORGAN_SLOT_STOMACH)
		if(!istype(stomach))
			to_chat(H, span_warning("You can't receive charge!"))
			return
		if(H.nutrition >= NUTRITION_LEVEL_ALMOST_FULL)
			to_chat(user, span_warning("You are already fully charged!"))
			return

		to_chat(H, span_notice("You clumsily channel power through the [src] and into your body, wasting some in the process."))
		E.drain_time = world.time + 25
		while(do_after(user, 20, target = src))
			if(!istype(stomach))
				to_chat(H, span_warning("You can't receive charge!"))
				return
			E.drain_time = world.time + 25
			if(charge > 300)
				stomach.adjust_charge(75)
				charge -= 300 //you waste way more than you receive, so that ethereals cant just steal one cell and forget about hunger
				to_chat(H, span_notice("You receive some charge from the [src]."))
			else
				stomach.adjust_charge(charge/4)
				charge = 0
				to_chat(H, span_notice("You drain the [src]."))
				E.drain_time = 0
				return

			if(stomach.charge >= stomach.max_charge)
				to_chat(H, span_notice("You are now fully charged."))
				E.drain_time = 0
				return
		to_chat(H, span_warning("You fail to receive charge from the [src]!"))
		E.drain_time = 0
	return

/obj/item/stock_parts/cell/blob_act(obj/structure/blob/B)
	SSexplosions.high_mov_atom += src

/obj/item/stock_parts/cell/proc/get_electrocute_damage()
	if(charge >= 1000)
		return clamp(20 + round(charge/25000), 20, 195) + rand(-5,5)
	else
		return 0

/obj/item/stock_parts/cell/get_part_rating()
	return rating * maxcharge

/* Cell variants*/
/obj/item/stock_parts/cell/empty/Initialize(mapload)
	. = ..()
	charge = 0

/obj/item/stock_parts/cell/crap
	name = "\improper Nanotrasen brand rechargeable AA battery"
	desc = "You can't top the plasma top." //TOTALLY TRADEMARK INFRINGEMENT
	maxcharge = 500
	custom_materials = list(/datum/material/glass=40)

/obj/item/stock_parts/cell/crap/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/upgraded
	name = "upgraded power cell"
	desc = "A power cell with a slightly higher capacity than normal!"
	maxcharge = 2500
	custom_materials = list(/datum/material/glass=50)
	chargerate = 1000

/obj/item/stock_parts/cell/upgraded/plus
	name = "upgraded power cell+"
	desc = "A power cell with an even higher capacity than the base model!"
	maxcharge = 5000

/obj/item/stock_parts/cell/secborg
	name = "security borg rechargeable D battery"
	maxcharge = 600	//600 max charge / 100 charge per shot = six shots
	custom_materials = list(/datum/material/glass=40)

/obj/item/stock_parts/cell/secborg/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/pulse //200 pulse shots
	name = "pulse rifle power cell"
	maxcharge = 40000
	chargerate = 1500

/obj/item/stock_parts/cell/pulse/carbine //25 pulse shots
	name = "pulse carbine power cell"
	maxcharge = 5000

/obj/item/stock_parts/cell/pulse/pistol //10 pulse shots
	name = "pulse pistol power cell"
	maxcharge = 2000

/obj/item/stock_parts/cell/high
	name = "high-capacity power cell"
	icon_state = "hcell"
	maxcharge = 10000
	custom_materials = list(/datum/material/glass=60)
	chargerate = 1500
	rating = 1

/obj/item/stock_parts/cell/high/plus
	name = "high-capacity power cell+"
	desc = "Where did these come from?"
	icon_state = "h+cell"
	maxcharge = 15000
	chargerate = 2250

/obj/item/stock_parts/cell/high/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/super
	name = "super-capacity power cell"
	icon_state = "scell"
	maxcharge = 20000
	custom_materials = list(/datum/material/glass=300)
	chargerate = 2000
	rating = 2

/obj/item/stock_parts/cell/super/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/hyper
	name = "hyper-capacity power cell"
	icon_state = "hpcell"
	maxcharge = 30000
	custom_materials = list(/datum/material/glass=400)
	chargerate = 3000
	rating = 3

/obj/item/stock_parts/cell/hyper/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/bluespace
	name = "bluespace power cell"
	desc = "A rechargeable transdimensional power cell."
	icon_state = "bscell"
	maxcharge = 40000
	custom_materials = list(/datum/material/glass=600)
	chargerate = 4000
	rating = 4

/obj/item/stock_parts/cell/bluespace/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/infinite
	name = "infinite-capacity power cell!"
	icon_state = "icell"
	maxcharge = 30000
	custom_materials = list(/datum/material/glass=1000)
	rating = 100
	chargerate = 30000

/obj/item/stock_parts/cell/infinite/use()
	return 1

/obj/item/stock_parts/cell/infinite/abductor
	name = "void core"
	desc = "An alien power cell that produces energy seemingly out of nowhere."
	icon = 'icons/obj/abductor.dmi'
	icon_state = "cell"
	maxcharge = 50000
	ratingdesc = FALSE

/obj/item/stock_parts/cell/infinite/abductor/ComponentInitialize()
	. = ..()
	AddElement(/datum/element/update_icon_blocker)


/obj/item/stock_parts/cell/potato
	name = "potato battery"
	desc = "A rechargeable starch based power cell."
	icon = 'icons/obj/hydroponics/harvest.dmi'
	icon_state = "potato"
	charge = 100
	maxcharge = 300
	custom_materials = null
	grown_battery = TRUE //it has the overlays for wires

/obj/item/stock_parts/cell/high/slime
	name = "charged slime core"
	desc = "A yellow slime core infused with plasma, it crackles with power."
	icon = 'icons/mob/slimes.dmi'
	icon_state = "yellow slime extract"
	custom_materials = null
	rating = 5 //self-recharge makes these desirable
	self_recharge = TRUE // Infused slime cores self-recharge, over time
	chargerate = 100
	maxcharge = 2000

/obj/item/stock_parts/cell/emproof
	name = "\improper EMP-proof cell"
	desc = "An EMP-proof cell."
	maxcharge = 500
	rating = 3

/obj/item/stock_parts/cell/emproof/empty/Initialize(mapload)
	. = ..()
	charge = 0
	update_appearance()

/obj/item/stock_parts/cell/emproof/empty/ComponentInitialize()
	. = ..()
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF)

/obj/item/stock_parts/cell/emproof/corrupt()
	return

/obj/item/stock_parts/cell/beam_rifle
	name = "beam rifle capacitor"
	desc = "A high powered capacitor that can provide huge amounts of energy in an instant."
	maxcharge = 50000
	chargerate = 5000	//Extremely energy intensive

/obj/item/stock_parts/cell/beam_rifle/corrupt()
	return

/obj/item/stock_parts/cell/beam_rifle/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	charge = clamp((charge-(10000/severity)),0,maxcharge)

/obj/item/stock_parts/cell/emergency_light
	name = "miniature power cell"
	desc = "A tiny power cell with a very low power capacity. Used in light fixtures to power them in the event of an outage."
	maxcharge = 120 //Emergency lights use 0.2 W per tick, meaning ~10 minutes of emergency power from a cell
	custom_materials = list(/datum/material/glass = 20)
	w_class = WEIGHT_CLASS_TINY

/obj/item/stock_parts/cell/emergency_light/Initialize(mapload)
	. = ..()
	var/area/A = get_area(src)
	if(!A.lightswitch || !A.light_power)
		charge = 0 //For naturally depowered areas, we start with no power
