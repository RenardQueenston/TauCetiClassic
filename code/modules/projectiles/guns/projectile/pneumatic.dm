/obj/item/weapon/storage/pneumatic
	name = "pneumatic cannon"
	desc = "A large gas-powered cannon."
	icon = 'icons/obj/gun.dmi'
	icon_state = "pneumatic"
	item_state = "pneumatic"
	w_class = 5.0
	flags =  FPRINT | TABLEPASS | CONDUCT
	slot_flags = SLOT_BELT
	max_w_class = 3
	max_combined_w_class = 20

	var/obj/item/weapon/tank/tank = null                // Tank of gas for use in firing the cannon.
	var/obj/item/weapon/storage/tank_container          // Something to hold the tank item so we don't accidentally fire it.
	var/pressure_setting = 10                           // Percentage of the gas in the tank used to fire the projectile.
	var/possible_pressure_amounts = list(5,10,20,25,50) // Possible pressure settings.
	var/minimum_tank_pressure = 10                      // Minimum pressure to fire the gun.
	var/cooldown = 0                                    // Whether or not we're cooling down.
	var/cooldown_time = 50                              // Time between shots.
	var/force_divisor = 400                             // Force equates to speed. Speed/5 equates to a damage multiplier for whoever you hit.
	                                                    // For reference, a fully pressurized oxy tank at 50% gas release firing a health
	                                                    // analyzer with a force_divisor of 10 hit with a damage multiplier of 3000+.
/obj/item/weapon/storage/pneumatic/New()
	..()
	tank_container = new(src)
	tank_container.tag = "gas_tank_holder"

/obj/item/weapon/storage/pneumatic/verb/set_pressure() //set amount of tank pressure.

	set name = "Set valve pressure"
	set category = "Object"
	set src in range(0)
	var/N = input("Percentage of tank used per shot:","[src]") as null|anything in possible_pressure_amounts
	if (N)
		pressure_setting = N
		usr << "You dial the pressure valve to [pressure_setting]%."

/obj/item/weapon/storage/pneumatic/verb/eject_tank() //Remove the tank.

	set name = "Eject tank"
	set category = "Object"
	set src in range(0)

	if(tank)
		usr << "You twist the valve and pop the tank out of [src]."
		tank.loc = usr.loc
		tank = null
		icon_state = "pneumatic"
		item_state = "pneumatic"
		usr.update_icons()
	else
		usr << "There's no tank in [src]."

/obj/item/weapon/storage/pneumatic/attackby(obj/item/W as obj, mob/user as mob)
	if(!tank && istype(W,/obj/item/weapon/tank))
		user.remove_from_mob(W)
		tank = W
		tank.loc = src.tank_container
		user.visible_message("[user] jams [W] into [src]'s valve and twists it closed.","You jam [W] into [src]'s valve and twist it closed.")
		icon_state = "pneumatic-tank"
		item_state = "pneumatic-tank"
		user.update_icons()
	else
		..()

/obj/item/weapon/storage/pneumatic/examine()
	set src in view()
	..()
	if (!(usr in view(2)) && usr!=src.loc) return
	usr << "The valve is dialed to [pressure_setting]%."
	if(tank)
		usr << "The tank dial reads [tank.air_contents.return_pressure()] kPa."
	else
		usr << "Nothing is attached to the tank valve!"

/obj/item/weapon/storage/pneumatic/afterattack(atom/target as mob|obj|turf|area, mob/living/user as mob|obj, flag, params)
	if (istype(target, /obj/item/weapon/storage/backpack ))
		return

	else if (target.loc == user.loc)
		return

	else if (locate (/obj/structure/table, src.loc))
		return

	else if(target == user)
		return

	if (length(contents) == 0)
		user << "There's nothing in [src] to fire!"
		return 0
	else
		spawn(0) Fire(target,user,params)

/obj/item/weapon/storage/pneumatic/attack(mob/living/M as mob, mob/living/user as mob, def_zone)
	if (length(contents) > 0)
		if(user.a_intent == "hurt")
			user.visible_message("\red <b> \The [user] fires \the [src] point blank at [M]!</b>")
			Fire(M,user)
			return
		else
			Fire(M,user)
			return

/obj/item/weapon/storage/pneumatic/proc/Fire(atom/target as mob|obj|turf|area, mob/living/user as mob|obj, params, reflex = 0)

	if (!tank)
		user << "There is no gas tank in [src]!"
		return 0

	if (cooldown)
		user << "The chamber hasn't built up enough pressure yet!"
		return 0

	add_fingerprint(user)

	var/turf/curloc = get_turf(user)
	var/turf/targloc = get_turf(target)
	if (!istype(targloc) || !istype(curloc))
		return

	var/fire_pressure = (tank.air_contents.return_pressure()/100)*pressure_setting

	if (fire_pressure < minimum_tank_pressure)
		user << "There isn't enough gas in the tank to fire [src]."
		return 0

	var/obj/item/object = contents[1]
	var/speed = ((fire_pressure*tank.volume)/object.w_class)/force_divisor //projectile speed.
	if(speed>80) speed = 80 //damage cap.

	user.visible_message("<span class='danger'>[user] fires [src] and launches [object] at [target]!</span>","<span class='danger'>You fire [src] and launch [object] at [target]!</span>")

	src.remove_from_storage(object,user.loc)
	object.throw_at(target,10,speed,user)

	var/lost_gas_amount = tank.air_contents.total_moles*(pressure_setting/100)
	var/datum/gas_mixture/removed = tank.air_contents.remove(lost_gas_amount)
	user.loc.assume_air(removed)

	cooldown = 1
	spawn(cooldown_time)
		cooldown = 0
		user << "[src]'s gauge informs you it's ready to be fired again."

//Constructable pneumatic cannon.

/obj/item/weapon/cannonframe
	name = "pneumatic cannon frame"
	desc = "A half-finished pneumatic cannon."
	icon_state = "pneumatic0"
	item_state = "pneumatic"

	var/buildstate = 0

/obj/item/weapon/cannonframe/update_icon()
	icon_state = "pneumatic[buildstate]"

/obj/item/weapon/cannonframe/examine()
	..()
	switch(buildstate)
		if(1) usr << "It has a pipe segment installed."
		if(2) usr << "It has a pipe segment welded in place."
		if(3) usr << "It has an outer chassis installed."
		if(4) usr << "It has an outer chassis welded in place."
		if(5) usr << "It has a transfer valve installed."

/obj/item/weapon/cannonframe/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/pipe))
		if(buildstate == 0)
			user.drop_item()
			qdel(W)
			user << "\blue You secure the piping inside the frame."
			buildstate++
			update_icon()
			return
	else if(istype(W,/obj/item/stack/sheet/metal))
		if(buildstate == 2)
			var/obj/item/stack/sheet/metal/M = W
			if(M.amount >= 5)
				M.use(5)
				user << "\blue You assemble a chassis around the cannon frame."
				buildstate++
				update_icon()
			else
				user << "\blue You need at least five metal sheets to complete this task."
			return
	else if(istype(W,/obj/item/device/transfer_valve))
		if(buildstate == 4)
			user.drop_item()
			qdel(W)
			user << "\blue You install the transfer valve and connect it to the piping."
			buildstate++
			update_icon()
			return
	else if(istype(W,/obj/item/weapon/weldingtool))
		if(buildstate == 1)
			var/obj/item/weapon/weldingtool/T = W
			if(T.remove_fuel(0,user))
				if(!src || !T.isOn()) return
				playsound(src.loc, 'sound/items/Welder2.ogg', 100, 1)
				user << "\blue You weld the pipe into place."
				buildstate++
				update_icon()
		if(buildstate == 3)
			var/obj/item/weapon/weldingtool/T = W
			if(T.remove_fuel(0,user))
				if(!src || !T.isOn()) return
				playsound(src.loc, 'sound/items/Welder2.ogg', 100, 1)
				user << "\blue You weld the metal chassis together."
				buildstate++
				update_icon()
		if(buildstate == 5)
			var/obj/item/weapon/weldingtool/T = W
			if(T.remove_fuel(0,user))
				if(!src || !T.isOn()) return
				playsound(src.loc, 'sound/items/Welder2.ogg', 100, 1)
				user << "\blue You weld the valve into place."
				new /obj/item/weapon/storage/pneumatic(get_turf(src))
				qdel(src)
		return
	else
		..()