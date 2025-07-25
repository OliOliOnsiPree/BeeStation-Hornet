/datum/surgery/core_removal
	name = "core removal"
	steps = list(/datum/surgery_step/incise, /datum/surgery_step/extract_core)
	target_mobtypes = list(/mob/living/simple_animal/slime)
	possible_locs = list(BODY_ZONE_R_ARM,BODY_ZONE_L_ARM,BODY_ZONE_R_LEG,BODY_ZONE_L_LEG,BODY_ZONE_CHEST,BODY_ZONE_HEAD)
	lying_required = FALSE
	ignore_clothes = TRUE

/datum/surgery/core_removal/can_start(mob/user, mob/living/target)
	if(target.stat == DEAD)
		return 1
	return 0

//extract brain
/datum/surgery_step/extract_core
	name = "extract core"
	implements = list(TOOL_HEMOSTAT = 100, TOOL_CROWBAR = 100)
	time = 16

/datum/surgery_step/extract_core/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	display_results(user, target, span_notice("You begin to extract a core from [target]..."),
		"[user] begins to extract a core from [target].",
		"[user] begins to extract a core from [target].")

/datum/surgery_step/extract_core/success(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/mob/living/simple_animal/slime/slime = target
	if(slime.cores > 0)
		slime.cores--
		display_results(user, target, span_notice("You successfully extract a core from [target]. [slime.cores] core\s remaining."),
			"[user] successfully extracts a core from [target]!",
			"[user] successfully extracts a core from [target]!")

		var/obj/item/slime_extract/item = new slime.coretype(slime.loc)
		if(slime.transformeffects & SLIME_EFFECT_GOLD)
			item.sparkly = TRUE
		if(slime.cores <= 0)
			slime.icon_state = "[slime.colour] baby slime dead-nocore"
			return ..()
		else
			return 0
	else
		to_chat(user, span_warning("There aren't any cores left in [target]!"))
		return ..()
