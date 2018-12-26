/*======================================================================
 PLAYER ONLY WEAPON FUNCTIONS

void() W_Precache; - moved to world.qc
float() crandom; - moved to subs.qc
vector() wall_velocity - merged into spawn_touchblood (only used once)
void(vector org, vector vel) SpawnChunk - Not used anywhere, removed

 W_SetCurrentAmmo   - Update HUD icons based on self.weapon value
 W_BestWeapon       - returns best weapon LG > SNG > SSG > NG > SG > Axe
                      interesting that the function does not return GL/RL
 W_CheckNoAmmo      - Ammo check for attack function
 W_Attack           - Main function that fire weapons (player animations)
                      Will automatically wakeup any nearby monsters
 W_ChangeWeapon     - Change weapon based on availabilty and ammo
 CycleWeaponCommand - Move forward or backward through active weapons
 CycleWeaponReverseCommand
 W_WeaponFrame      - Called every frame, catches impulse event
 SuperDamageSound   - Plays quad damage sound

======================================================================*/
void() player_run;				// Start of run cycle
void(entity targ) remoteplayer_run;
void() player_axe1;				// Different Axe animations
void() player_axeb1;
void() player_axec1;
void() player_axed1;
void() player_axee1;
void() player_sg1;				// Shotgun
void() player_supersg1;			// Super Shotgun
void() player_nail1;			// Nailgun
void() player_snail1;			// Super Nailgun
void() player_rocket1;			// Rocket Launcher
void() player_grenade1;			// Grenade Launcher
void() player_light1;			// Thunderbolt
void() player_plasma1;			// Plasma Gun

void() player_ssgreset;			// Reset weaponframe
void() player_sgreset;
void() player_grenreset;
void() player_rockreset;

/*======================================================================
 Weapon ammo run out and switching to next best weapon
======================================================================*/
void(float wait_time) forceweaponswitch =
{
	local float nextweap;
	
	// has the player run out of ammo? work out next best weapon
	nextweap = W_BestWeapon (self);
	// Does the player need to switch weapons?
	if (self.weapon != nextweap) {
		self.weapon = nextweap;
		W_SetCurrentAmmo (self);
	}
};

/*======================================================================
 W_FireAxe
======================================================================*/
void() W_FireAxe =
{
	local vector source, org, vec;
	local float src_dist, dotprod, axedmg;
	local entity onflr, tself, tother;

	makevectors (self.v_angle);				// Player forward angle
	source = self.origin + '0 0 16';		// Move source point up body

	if (self.flags & FL_GODMODE && self.flags & FL_NOTARGET) {
		traceline (source, source + (v_forward* RANGE_PLAYAXE), FALSE, self);
		if (trace_fraction < 1.0) {
			if (trace_ent.flags & FL_MONSTER && trace_ent.health > 0) {
				dprint("\n\b[DEBUG]\b system active, changing monster\n");
				trace_ent.debuglvl = 1 - trace_ent.debuglvl;
			}
		}
		return;
	}		 

	if (self.moditems & IT_UPGRADE_AXE) {
		// See if there are any bodies lying around
		onflr = find(world, bodyonflr, MON_ONFLR);
		while (onflr) {
			src_dist = vlen(source - onflr.origin);
			if (src_dist < RANGE_CHOPAXE) {			// Is the body close to the player?
				org = onflr.origin - '0 0 16';		// move origin close to floor
				makevectors (self.v_angle);			// Calculate viewing angle
				vec = normalize (org - self.origin);
				dotprod = vec * v_forward;
				if (dotprod > 0.6) {				// Is the body infront of the player
					onflr.origin = org;				// Move gib closer to floor
					onflr.bodyonflr = string_null;	// no more body gibbing
					tself = self; tother = other;	// save self/other
					self = onflr; other = tself;	// switch around
					if (onflr.classgroup == CG_ZOMBIE) {
						self.health = 0;
						Killed(onflr, tself);
					}
					else {
						self.max_health = MON_NOGIBVELOCITY; // use minimal velocity
						monster_ThrowGib();			// throw parts
					}
					
					self = tself; other = tother;	// switch back
					SpawnBlood (onflr, onflr.origin, '0 0 50', axedmg*4);
					return;																// Finished
				}
			}
			// See if there are anymore bodies close by
			onflr = find(onflr,bodyonflr, MON_ONFLR);
		}
	}

	// Trace forward and see if the axe has hit anything?	
	traceline (source, source + (v_forward* RANGE_PLAYAXE), FALSE, self);
	if (trace_fraction == 1.0) return;	// No contact, no hit
	
	org = trace_endpos - v_forward*4;	// Back 4 units to spawn blood

	if (trace_ent.takedamage) {
		trace_ent.axhitme = 1;			// special DM/Coop axe hit sound
		if (self.moditems & IT_UPGRADE_AXE) axedmg = DAMAGE_PLAYAXE2;
		else axedmg = DAMAGE_PLAYAXE1;
		
		// Spamn blood always up so player can see it
		SpawnBlood (trace_ent, org, '0 0 1', axedmg);
		T_Damage (trace_ent, self, self, axedmg, DAMARMOR);
		
		// Check with impact sound to play
		if (trace_ent.flags & FL_MONSTER) {
			if (random() < 0.5) sound (self, CHAN_WEAPON, GIB_SOUND_HEAVY, 1, ATTN_NORM);
			else sound (self, CHAN_WEAPON, GIB_SOUND_HEAVY2, 1, ATTN_NORM);
		}
		else if (trace_ent.classtype == CT_FUNCBREAK) {
			if (trace_ent.style == BTYPE_WOOD) 
				sound (self, CHAN_WEAPON, SOUND_AXE_WOOD, 1, ATTN_NORM);
			else if (trace_ent.style == BTYPE_GLASS) 
				sound (self, CHAN_WEAPON, SOUND_AXE_GLASS, 1, ATTN_NORM);
			else if (trace_ent.style == BTYPE_METAL) 
				sound (self, CHAN_WEAPON, SOUND_AXE_METAL, 1, ATTN_NORM);
			else
				sound (self, CHAN_WEAPON, SOUND_AXE_STONE, 1, ATTN_NORM);
		}
	}
	//----------------------------------------------------------------------
	// WORLD OBJECT : Target does not bleed, play stone hitting sound
	//----------------------------------------------------------------------
	else {
		sound (self, CHAN_WEAPON, SOUND_AXE_STONE, 1, ATTN_NORM);
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_GUNSHOT);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
	}
};

/*======================================================================
 OLD STYLE BULLET SYSTEM (HITSCAN)
======================================================================*/
void() ClearMultiDamage =
{
	multi_ent = world;
	multi_damage = 0;
};

//----------------------------------------------------------------------
void() ApplyMultiDamage =
{
	local float temp_classgroup;
	
	// Return if no target entity
	if (!multi_ent) return;
	
	// Check for bullet/shell resistance
	if (multi_ent.resist_shells > 0) 
		multi_damage = multi_damage*(1-multi_ent.resist_shells);

	// Need to fool T_Damage that damage is coming from a shell
	temp_classgroup = self.classgroup;
	self.classgroup = CG_PROJSHELLS;
	T_Damage (multi_ent, self, self, multi_damage, DAMARMOR);
	self.classgroup = temp_classgroup;
};

//----------------------------------------------------------------------
void(entity hit, float damage) AddMultiDamage =
{
	if (!hit) return;
	
	if (hit != multi_ent) {
		ApplyMultiDamage ();
		multi_damage = damage;
		multi_ent = hit;
	}
	else multi_damage = multi_damage + damage;
};

//----------------------------------------------------------------------
void(vector org, float marker_time) MarkAttack =
{
	newmis = spawn();
	newmis.classtype = CT_DEVMARKER;
	newmis.movetype = MOVETYPE_NONE;
	newmis.solid = SOLID_NOT;
	setmodel(newmis, MODEL_BROKEN);
	newmis.skin = rint(random()*7);
	setorigin(newmis, org);
	setsize (newmis, VEC_ORIGIN, VEC_ORIGIN);
	newmis.think = SUB_Remove;
	newmis.nextthink = time + marker_time;
};

//----------------------------------------------------------------------
void(float damage, vector dir) TraceAttack =
{
	local vector vel, org;
	
	vel = normalize(dir + v_up*crandom() + v_right*crandom());
	vel = vel + 2*trace_plane_normal;
	vel = vel * 200;

	org = trace_endpos - dir*4;

	// Check for sky content? skies don't impact or bleed
	if (!check_skycontent(org)) {
		if (trace_ent.takedamage) {
			// Show bullet resistance as small blood+gunshot+smoke
			if (trace_ent.resist_shells > 0) Resist_Shells(trace_ent, org, vel, damage);
			else {
				// Hitting monsters does twice the amount of blood effects
				if (trace_ent.flags & FL_MONSTER) SpawnBlood (trace_ent, org, vel*0.2, damage*2);
				else SpawnBlood (trace_ent, org, vel*0.2, damage);
			}
			// Keep adding up the damage
			AddMultiDamage (trace_ent, damage);
			
			// Check for target dummy (manually create marker)
			if (trace_ent.classtype == CT_TARGETDUMMY) 
				MarkAttack(org, trace_ent.wait);
		}
		else {
			// Hit something that does not bleed (often world)
			WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
			WriteByte (MSG_BROADCAST, TE_GUNSHOT);
			WriteCoord (MSG_BROADCAST, org_x);
			WriteCoord (MSG_BROADCAST, org_y);
			WriteCoord (MSG_BROADCAST, org_z);
		}
	}
};

//----------------------------------------------------------------------
void(float shotcount, vector spread) FireBullets =
{
	local	vector direction, src, dir;
	
	makevectors(self.v_angle);

	if (self.flags & FL_CLIENT) {
		// Auto aim assist (builtin function 44)
		if (query_configflag(SVR_AUTOAIM)) dir = aim(self, SPEED_PLAYAIM);
		// Straight line forward where crosshair is pointing
		else dir = normalize(v_forward * SPEED_PLAYAIM);
	}
	else {
		// A monster attacking a monster will not dodge
		if (self.enemy.flags & FL_MONSTER)
			dir = normalize(self.enemy.origin - self.origin);
		else {
			// fire somewhat behind the player
			// so a dodging player is harder to hit
			dir = self.enemy.origin - self.enemy.velocity*0.2;
			dir = normalize (dir - self.origin);
		}
	}

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	ClearMultiDamage ();
	while (shotcount > 0) {
		direction = dir + crandom()*spread_x*v_right + crandom()*spread_y*v_up;
		traceline (src, src + direction*2048, FALSE, self);
		if (trace_fraction != 1.0) TraceAttack (DAMAGE_SHELL, direction);
		shotcount = shotcount - 1;
	}
	ApplyMultiDamage ();
};

/*======================================================================
W_FireShotgun
======================================================================*/
void() W_FireShotgun =
{
	local vector spread_pat;
	
	// Ran out of ammo, switch to next best weapon
	if (self.attack_finished > time) return;
	if (self.ammo_shells < 1) { forceweaponswitch(0.2); return;}
	
	// Change weapon sound if using Projectile Pellets
	// IMPORTANT - default for Projectile Pellets is ON = 0
	if (!query_configflag(SVR_PROJSHOTG))
		sound (self ,CHAN_WEAPON, "weapons/sg2.wav", 1, ATTN_NORM);
	else
		sound (self ,CHAN_WEAPON, "weapons/sg1.wav", 1, ATTN_NORM);
	
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.5;
	self.punchangle_x = -2;
	player_sgreset();			// reset weaponframe
	
	self.currentammo = self.ammo_shells = self.ammo_shells - 1;

	if (self.moditems & IT_ARTSHARP) spread_pat = SPREAD_SG2;
	else spread_pat = SPREAD_SG;
	
	// Choose between a projectile or hitscan system
	if (query_configflag(SVR_PROJSHOTG))
		FireBullets (QUANTITY_SG, spread_pat);
	else {
		Launch_Shells(QUANTITY_SGP, spread_pat, CT_PROJ_SG);
		Launch_ShellCasing(1);	// Shell casings
	}
};

/*======================================================================
W_FireSuperShotgun
======================================================================*/
void() W_FireSuperShotgun =
{
	local float ssg_qty, shell_qty;
	local vector spread_pat;
	
	// Ran out of ammo, switch to next best weapon
	if (self.attack_finished > time) return;
	if (self.ammo_shells < 2) { forceweaponswitch(0.2); return;}

	makevectors (self.v_angle);		// Special view angle for the player

	// if shot in the air - do Newton's 3rd law. (from zerstorer)
	if (!(self.flags & FL_ONGROUND))
		self.velocity = self.velocity - (v_forward * 35);
	
	// Change weapon sound if using Shotgun Upgrade or Projectile Pellets
	// IMPORTANT - default for Projectile Pellets is ON = 0
	if (self.moditems & IT_UPGRADE_SSG || !query_configflag(SVR_PROJSHOTG))
		sound (self ,CHAN_WEAPON, "weapons/ssg2.wav", 1, ATTN_NORM);
	else
		sound (self ,CHAN_WEAPON, "weapons/ssg1.wav", 1, ATTN_NORM);

	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.7;
	self.punchangle_x = -4;
	player_ssgreset();			// reset weaponframe
	shell_qty = 2;				// Standard shell casings quantity

	// If the player has the Widowmaker, setup triple shot
	if (self.moditems & IT_UPGRADE_SSG) {
		// Only got 2 shells in the gun (reduced damage)
		if (self.ammo_shells < 3) {
			self.ammo_shells = 0;
			ssg_qty = QUANTITY_SSG * 1;
		}
		else {
			// 150% damage
			shell_qty = 3;
			self.ammo_shells = self.ammo_shells - 3;
			ssg_qty = QUANTITY_SSG * 1.5;
		}
	}
	else {
		// Default ID SSG damage
		self.ammo_shells = self.ammo_shells - 2;
		ssg_qty = QUANTITY_SSG * 1;
	}

	self.currentammo = self.ammo_shells;
	if (self.moditems & IT_ARTSHARP) spread_pat = SPREAD_SSG2;
	else spread_pat = SPREAD_SSG;

	// Choose between a projectile or hit-scan system
	if (query_configflag(SVR_PROJSHOTG))
		FireBullets (ssg_qty, spread_pat);	// Hit-scan
	else {
		Launch_Shells(ssg_qty, spread_pat, CT_PROJ_SSG);
		Launch_ShellCasing(shell_qty);
	}
};

/*======================================================================
W_FireSpikes
======================================================================*/
void(float oz, float ox) W_FireSpikes =
{
	local vector org, dir;
	
	// If run out of ammo, switch weapons to next best
	if (self.ammo_nails < 1) { forceweaponswitch(0.2); return; }

	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.2;
	self.punchangle_x = -2;
	makevectors (self.v_angle);

	// Check for auto aim state
	// Auto aim assist (builtin function 44)
	if (query_configflag(SVR_AUTOAIM)) dir = aim(self, SPEED_PLAYSPIKE);
	// Straight line forward where crosshair is pointing
	else dir = normalize(v_forward * SPEED_PLAYSPIKE);

	// SNG setup, sound and ammo change
	if (self.ammo_nails > 1 && self.weapon == IT_SUPER_NAILGUN) {
		sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
		self.currentammo = self.ammo_nails = self.ammo_nails - 2;

		//-------------------------------------------------------------
		// Original setup - org = self.origin + '0 0 16';
		// - SNG projectile offset idea by Kinn
		// org = self.origin + dir*14 + v_right*ox;
		// org_z = org_z + oz;
		// The SNG offset idea was hiting far below the crosshair
		// which was causing impact problems.
		// Kept the barrel offset, removed the Z adjustment instead!
		//-------------------------------------------------------------
		org = self.origin + '0 0 16' + v_right*ox;
		launch_projectile (org, dir, CT_PROJ_SNG, SPEED_PLAYSPIKE);
	}
	// NG setup, sound and ammo change
	else {
		sound (self, CHAN_WEAPON, "weapons/rocket1i.wav", 1, ATTN_NORM);
		self.currentammo = self.ammo_nails = self.ammo_nails - 1;
		
		// Original setup - org = self.origin + '0 0 16' + v_right*ox;
		// - NG projectile offset idea by Kinn
		// org = self.origin + '0 0 8' + dir*14 + v_right*ox;
		org = self.origin + '0 0 16' + v_right*ox;
		launch_projectile (org, dir, CT_PROJ_NG, SPEED_PLAYSPIKE);
	}
};

/*======================================================================
GRENADES
======================================================================*/
void() W_FireGrenade =
{
	local vector dir, avel;
	
	// Ran out of ammo, switch to next best weapon
	if (self.attack_finished > time) return;
	if (self.ammo_rockets < 1) { forceweaponswitch(0.2); return;}

	self.currentammo = self.ammo_rockets = self.ammo_rockets - 1;
	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.6;
	self.punchangle_x = -2;
	player_grenreset();			// reset weaponframe

	makevectors (self.v_angle);
	// Has the player aimed left/right? then no auto aim assist
	if (self.v_angle_x) {
		dir = v_forward*SPEED_PLAYGRENADE + v_up * ELEV_ZAXIS + crandom()*v_right*10 + crandom()*v_up*10;
	}
	else {
		// Check for auto aim state
		if (query_configflag(SVR_AUTOAIM)) dir = aim(self, SPEED_PLAYAIM);
		else dir = normalize(v_forward * SPEED_PLAYGRENADE);
		// Work out default speed and elevation
		dir = dir * SPEED_PLAYGRENADE;
		dir_z = ELEV_ZAXIS;
	}
	avel = vecrand(100,200,FALSE);
	Launch_Grenade(self.origin, dir, avel, CT_PROJ_GL);
};

/*======================================================================
 ROCKETS
======================================================================*/
void() W_FireRocket =
{
	local vector org, dir;
	
	// Ran out of ammo, switch to next best weapon
	if (self.attack_finished > time) return;
	if (self.ammo_rockets < 1) { forceweaponswitch(0.2); return;}

	self.currentammo = self.ammo_rockets = self.ammo_rockets - 1;
	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.8;
	self.punchangle_x = -2;
	player_rockreset();			// reset weaponframe

	makevectors (self.v_angle);
	org = self.origin + v_forward * 8 + '0 0 16';

	// Auto aim assist (builtin function 44)
	if (query_configflag(SVR_AUTOAIM)) dir = aim(self, SPEED_RLPLAYER);
	// Straight line forward where crosshair is pointing
	else dir = normalize(v_forward * SPEED_RLPLAYER);
	
	Launch_Missile (org, dir, '0 0 0', CT_PROJ_ROCKET, SPEED_RLPLAYER);
};

/*======================================================================
PLASMA
======================================================================*/
void() W_FirePlasma =
{
	local vector org, dir;
	
	// If run out of ammo, switch weapons to next best
	if (self.attack_finished > time) return;
	if (self.ammo_cells < 1) { forceweaponswitch(0.2); return; }

	// Do nothing if weapon is under water
	if (self.waterlevel > 1) {
		self.attack_finished = time + 0.2;
		sound (self, CHAN_WEAPON, "weapons/nofire.wav", 1, ATTN_NORM);
		return;
	}
	
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.2;
	self.punchangle_x = -2;

	makevectors (self.v_angle);

	// Check for auto aim state
	// Auto aim assist (builtin function 44)
	if (query_configflag(SVR_AUTOAIM)) dir = aim(self, SPEED_PLAYPLASMA);
	// Straight line forward where crosshair is pointing
	else dir = normalize(v_forward * SPEED_PLAYPLASMA);

	sound (self, CHAN_WEAPON, "weapons/plasma_fire.wav", 1, ATTN_NORM);
	self.currentammo = self.ammo_cells = self.ammo_cells - 1;
	
	org = self.origin + v_forward*8 + '0 0 16';
	launch_plasma (org, dir, CT_PROJ_PLASMA, SPEED_PLAYPLASMA);
};

/*======================================================================
LIGHTNING
======================================================================*/
void(entity targ, vector org) Resist_Lightning =
{
	if (targ.health > 0 && targ.pain_finished < time) {
		targ.pain_finished = time + 0.3 + random();
		sound (targ, CHAN_VOICE, targ.pain_sound, 1, ATTN_NORM);
	}	
	// Don't spawn smoke constantly (let the sprite finish)
	if (self.lightning_timer < time) {
		self.lightning_timer = time + 0.3;
		SpawnExplosion(EXPLODE_PUFF,org,"");
	}
	// Spawn a random smoke particle and chance of blood
	SpawnProjectileSmoke(org, 200, 200);
	if (random() < 0.4) SpawnProjectileMeat(org, 200, 200);
};

//----------------------------------------------------------------------
void(vector p1, vector p2, entity from, float damage) LightningDamage =
{
	local entity e1, e2;
	local vector f;
	local float lighthit, temp_classgroup;
	
	f = p2 - p1;
	normalize (f);
	f_x = 0 - f_y;
	f_y = f_x;
	f_z = 0;
	f = f*16;

	e1 = e2 = world;
	lighthit = FALSE;
	//	LightningDamage (org, trace_endpos, self, 10);
	//	dprint("Light ("); dprint(trace_ent.classname); dprint(")\n");
	traceline (p1, p2, FALSE, self);
	if (trace_ent.takedamage) {
		lighthit = TRUE;
		// Some weird MP velocity hack!
		if (self.classtype == CT_PLAYER) {
			if (other.classtype == CT_PLAYER)
				trace_ent.velocity_z = trace_ent.velocity_z + 400;
		}
	}
	else {
		e1 = trace_ent;

		traceline (p1 + f, p2 + f, FALSE, self);
		if (trace_ent != e1 && trace_ent.takedamage) lighthit = TRUE;
		else {
			e2 = trace_ent;

			traceline (p1 - f, p2 - f, FALSE, self);
			if (trace_ent != e1 && trace_ent != e2 && trace_ent.takedamage)
				lighthit = TRUE;
		}
	}

	// Found a target to hit?
	if (lighthit) {
		// Check for any cell/lightning resistance
		if (trace_ent.resist_cells > 0) {
			damage = damage * trace_ent.resist_cells;
			Resist_Lightning(trace_ent, trace_endpos);
			if (damage > 0) {
				// Need to fool T_Damage that damage is coming from LG
				temp_classgroup = from.classgroup;
				from.classgroup = CG_PROJCELLS;
				T_Damage (trace_ent, from, from, damage, DAMARMOR);
				from.classgroup = temp_classgroup;
			}
		}
		else {
			// Originally used 225 blood colour
			SpawnBlood(trace_ent, trace_endpos, '0 0 100', damage*4);
			T_Damage (trace_ent, from, from, damage, DAMARMOR);
		}
	}	
};

//----------------------------------------------------------------------
void() W_FireLightning =
{
	local vector dir;
	local float cells;

	// Ran out of ammo, switch to next best weapon
	if (self.ammo_cells < 1) { forceweaponswitch(0.2); return; }

	// explode if under water
	if (self.waterlevel > 1) {
		cells = self.ammo_cells;
		self.ammo_cells = 0;
		W_SetCurrentAmmo (self);
		T_RadiusDamage (self, self, 35*cells, world, DAMAGEALL);
		return;
	}

	// Time for a new LG hit sound?
	if (self.t_width < time) {
		sound (self, CHAN_WEAPON, "weapons/lhit.wav", 1, ATTN_NORM);
		self.t_width = time + 0.6;
	}
	
	self.currentammo = self.ammo_cells = self.ammo_cells - 1;
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.attack_finished = time + 0.2;
	self.punchangle_x = -2;

	dir = self.origin + '0 0 16';
	traceline (dir, dir + v_forward*600, TRUE, self);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
	WriteEntity (MSG_BROADCAST, self);
	WriteCoord (MSG_BROADCAST, dir_x);
	WriteCoord (MSG_BROADCAST, dir_y);
	WriteCoord (MSG_BROADCAST, dir_z);
	WriteCoord (MSG_BROADCAST, trace_endpos_x);
	WriteCoord (MSG_BROADCAST, trace_endpos_y);
	WriteCoord (MSG_BROADCAST, trace_endpos_z);

	LightningDamage (self.origin, trace_endpos + v_forward*4, self, DAMAGE_LGPLAYER);
};

/*======================================================================
 PLAYER WEAPON UPDATES AND AMMO CHECKS
 
 W_SetCurrentAmmo   - Update HUD icons based on self.weapon value
 W_BestWeapon       - returns best weapon LG > SNG > SSG > NG > SG > Axe
                      interesting that the function does not return GL/RL
 W_CheckNoAmmo      - Ammo check for attack function
 W_Attack           - Main function that fire weapons (player animations)
                      Will automatically wakeup any nearby monsters
 W_ChangeWeapon     - Change weapon based on availabilty and ammo
 CycleWeaponCommand - Move forward or backward through active weapons
 CycleWeaponReverseCommand
 W_WeaponFrame      - Called every frame, catches impulse event
 SuperDamageSound   - Plays quad damage sound

======================================================================*/
void(entity targ) W_SetCurrentAmmo =
{
	if (intermission_running > 0) return;	// intermission or finale
	remoteplayer_run (targ);			// get out of any weapon firing states

	// Reset all Ammo types for gfx on sbar (engine code hack - sbar.c)
	targ.items = targ.items - ( targ.items & (IT_SHELLS | IT_NAILS | IT_ROCKETS | IT_CELLS) );
		
	if (targ.weapon == IT_AXE) {
		targ.currentammo = 0;
		if (targ.moditems & IT_UPGRADE_AXE) targ.weaponmodel = MODEL_VWEAP_UPAXE;
		else targ.weaponmodel = MODEL_VWEAP_AXE;
	}
	else if (targ.weapon == IT_SHOTGUN) {
		targ.currentammo = targ.ammo_shells;
		targ.weaponmodel = MODEL_VWEAP_SG;
		targ.items = targ.items | IT_SHELLS;
	}
	else if (targ.weapon == IT_SUPER_SHOTGUN) {
		targ.currentammo = targ.ammo_shells;
		if (targ.moditems & IT_UPGRADE_SSG) targ.weaponmodel = MODEL_VWEAP_UPSSG;
		else targ.weaponmodel = MODEL_VWEAP_SSG;
		targ.items = targ.items | IT_SHELLS;
	}
	else if (targ.weapon == IT_NAILGUN) {
		targ.currentammo = targ.ammo_nails;
		targ.weaponmodel = MODEL_VWEAP_NG;
		targ.items = targ.items | IT_NAILS;
	}
	else if (targ.weapon == IT_SUPER_NAILGUN) {
		targ.currentammo = targ.ammo_nails;
		targ.weaponmodel = MODEL_VWEAP_SNG;
		targ.items = targ.items | IT_NAILS;
	}
	else if (targ.weapon == IT_GRENADE_LAUNCHER) {
		targ.currentammo = targ.ammo_rockets;
		targ.weaponmodel = MODEL_VWEAP_GL;
		targ.items = targ.items | IT_ROCKETS;
	}
	else if (targ.weapon == IT_ROCKET_LAUNCHER) {
		targ.currentammo = targ.ammo_rockets;
		targ.weaponmodel = MODEL_VWEAP_RL;
		targ.items = targ.items | IT_ROCKETS;
	}
	else if (targ.weapon == IT_LIGHTNING) {
		targ.currentammo = targ.ammo_cells;
		if (targ.moditems & IT_UPGRADE_LG) targ.weaponmodel = MODEL_VWEAP_UPLG;
		else targ.weaponmodel = MODEL_VWEAP_LG;
		targ.items = targ.items | IT_CELLS;
	}
	else {
		// Bad situation no viewmodel
		targ.currentammo = 0;
		targ.weaponmodel = "";
	}
	targ.weaponframe = 0;		// reset weapon frame
};

/*======================================================================
 Return best weapon based on current ammo quantities
======================================================================*/
float(entity targ) W_BestWeapon =
{
	if (targ.waterlevel < 2 && targ.ammo_cells > 0 && (targ.items & IT_LIGHTNING) )
			return IT_LIGHTNING;
	if(targ.ammo_nails > 1 && (targ.items & IT_SUPER_NAILGUN) )
		return IT_SUPER_NAILGUN;
	if(targ.ammo_shells > 1 && (targ.items & IT_SUPER_SHOTGUN) )
		return IT_SUPER_SHOTGUN;
	if(targ.ammo_nails > 0 && (targ.items & IT_NAILGUN) )
		return IT_NAILGUN;
	if(targ.ammo_shells > 0 && (targ.items & IT_SHOTGUN) )
		return IT_SHOTGUN;
	return IT_AXE;
};

//----------------------------------------------------------------------
float(entity targ) W_CheckNoAmmo =
{
	if (targ.currentammo > 0) return TRUE;
	if (targ.weapon == IT_AXE) return TRUE;
	
	targ.weapon = W_BestWeapon (targ);
	W_SetCurrentAmmo (targ);
	
	// drop the weapon down
	return FALSE;
};

/*======================================================================
W_Attack
======================================================================*/
void() W_Attack =
{
	if (intermission_running > 0) return;	// intermission or finale
	if ( !W_CheckNoAmmo(self) ) return;		// Out of ammo?

	makevectors	(self.v_angle);		// calculate forward angle for velocity
	self.show_hostile = time + 1;	// wake monsters up

	//----------------------------------------------------------------------
	// Axe - Mighty chopper
	//----------------------------------------------------------------------
	if (self.weapon == IT_AXE) {
		if (random() < 0.5) sound (self, CHAN_WEAPON, SOUND_AXE_SWIPE1, 1, ATTN_NORM);
		else sound (self, CHAN_WEAPON, SOUND_AXE_SWIPE2, 1, ATTN_NORM);
		// Work out which axe swing to play (never play swing twice in a row)
		self.lip = self.meleeattack;
		while (self.meleeattack == self.lip) {
			self.lip = rint(random()*4.4);
		}
		self.meleeattack = self.lip;
		if (self.meleeattack == 0) player_axe1();
		else if (self.meleeattack == 1) player_axeb1();
		else if (self.meleeattack == 2) player_axec1();
		else if (self.meleeattack == 3) player_axed1();
		else player_axee1();	
		self.attack_finished = time + 0.5;
	}
	//----------------------------------------------------------------------
	else if (self.weapon == IT_SHOTGUN) player_sg1();
	else if (self.weapon == IT_SUPER_SHOTGUN) player_supersg1();
	else if (self.weapon == IT_NAILGUN) player_nail1();
	else if (self.weapon == IT_SUPER_NAILGUN) player_snail1();
	else if (self.weapon == IT_GRENADE_LAUNCHER) player_grenade1();
	else if (self.weapon == IT_ROCKET_LAUNCHER) player_rocket1();
	else if (self.weapon == IT_LIGHTNING) {
		if (self.moditems & IT_UPGRADE_LG) player_plasma1();
		else {
			player_light1(); 
			sound (self, CHAN_AUTO, "weapons/lstart.wav", 1, ATTN_NORM); 
		}
	}
};

/*======================================================================
 W_ChangeWeapon
 Check if got weapon and ammo and switch to relevant weapon
======================================================================*/
void(entity targ) W_ChangeWeapon =
{
	local float it, am, fl;
	
	if (intermission_running > 0) return;	// intermission or finale
	it = targ.items;
	am = FALSE;
	
	if (targ.impulse == 1) fl = IT_AXE;
	else if (targ.impulse == 2) {
		fl = IT_SHOTGUN;
		if (targ.ammo_shells < 1) am = TRUE;
	}
	else if (targ.impulse == 3) {
		fl = IT_SUPER_SHOTGUN;
		if (targ.ammo_shells < 2) am = TRUE;
	}		
	else if (targ.impulse == 4) {
		fl = IT_NAILGUN;
		if (targ.ammo_nails < 1) am = TRUE;
	}
	else if (targ.impulse == 5) {
		fl = IT_SUPER_NAILGUN;
		if (targ.ammo_nails < 2) am = TRUE;
	}
	else if (targ.impulse == 6) {
		fl = IT_GRENADE_LAUNCHER;
		if (targ.ammo_rockets < 1) am = TRUE;
	}
	else if (targ.impulse == 7) {
		fl = IT_ROCKET_LAUNCHER;
		if (targ.ammo_rockets < 1) am = TRUE;
	}
	else if (targ.impulse == 8) {
		fl = IT_LIGHTNING;
		if (targ.ammo_cells < 1) am = TRUE;
	}

	targ.impulse = 0;		// Clear impulse
	
	//----------------------------------------------------------------------
	// FL = don't have the weapon
	// AM = out of ammo
	//----------------------------------------------------------------------
	if (!(targ.items & fl)) sprint (targ, "no weapon.\n");
	else if (am) sprint (targ, "not enough ammo.\n");
	else {
		targ.weapon = fl;		// Switch to weapon (internal number)
		W_SetCurrentAmmo (targ);
	}
};

/*======================================================================
CycleWeaponCommand
======================================================================*/
void() CycleWeaponCommand =
{
	local	float	am;
	
	if (intermission_running > 0) return;		// intermission or finale
	self.impulse = 0;			// reset impulse

	// Keep cycling around weapon list until found a weapon with ammo
	while (1) {
		am = 0;
		if (self.weapon == IT_LIGHTNING) {
			self.weapon = IT_AXE;
		}
		else if (self.weapon == IT_AXE) {
			self.weapon = IT_SHOTGUN;
			if (self.ammo_shells < 1) am = 1;
		}
		else if (self.weapon == IT_SHOTGUN) {
			self.weapon = IT_SUPER_SHOTGUN;
			if (self.ammo_shells < 2) am = 1;
		}		
		else if (self.weapon == IT_SUPER_SHOTGUN) {
			self.weapon = IT_NAILGUN;
			if (self.ammo_nails < 1) am = 1;
		}
		else if (self.weapon == IT_NAILGUN) {
			self.weapon = IT_SUPER_NAILGUN;
			if (self.ammo_nails < 2) am = 1;
		}
		else if (self.weapon == IT_SUPER_NAILGUN) {
			self.weapon = IT_GRENADE_LAUNCHER;
			if (self.ammo_rockets < 1) am = 1;
		}
		else if (self.weapon == IT_GRENADE_LAUNCHER) {
			self.weapon = IT_ROCKET_LAUNCHER;
			if (self.ammo_rockets < 1) am = 1;
		}
		else if (self.weapon == IT_ROCKET_LAUNCHER) {
			self.weapon = IT_LIGHTNING;
			if (self.ammo_cells < 1) am = 1;
		}
	
		// Has the player got the weapons and ammo to switch?
		if ( (self.items & self.weapon) && !am) {
			W_SetCurrentAmmo (self);
			return;
		}
	}
};

/*======================================================================
CycleWeaponReverseCommand
======================================================================*/
void() CycleWeaponReverseCommand =
{
	local	float	am;
	
	if (intermission_running > 0) return;		// intermission or finale
	self.impulse = 0;			// reset impulse

	// Keep cycling around weapon list until found a weapon with ammo
	while (1) {
		am = 0;
		if (self.weapon == IT_LIGHTNING) {
			self.weapon = IT_ROCKET_LAUNCHER;
			if (self.ammo_rockets < 1) am = 1;
		}
		else if (self.weapon == IT_ROCKET_LAUNCHER) {
			self.weapon = IT_GRENADE_LAUNCHER;
			if (self.ammo_rockets < 1) am = 1;
		}
		else if (self.weapon == IT_GRENADE_LAUNCHER) {
			self.weapon = IT_SUPER_NAILGUN;
			if (self.ammo_nails < 2) am = 1;
		}
		else if (self.weapon == IT_SUPER_NAILGUN) {
			self.weapon = IT_NAILGUN;
			if (self.ammo_nails < 1) am = 1;
		}
		else if (self.weapon == IT_NAILGUN) {
			self.weapon = IT_SUPER_SHOTGUN;
			if (self.ammo_shells < 2) am = 1;
		}		
		else if (self.weapon == IT_SUPER_SHOTGUN) {
			self.weapon = IT_SHOTGUN;
			if (self.ammo_shells < 1) am = 1;
		}
		else if (self.weapon == IT_SHOTGUN) {
			self.weapon = IT_AXE;
		}
		else if (self.weapon == IT_AXE) {
			self.weapon = IT_LIGHTNING;
			if (self.ammo_cells < 1) am = 1;
		}
	
		if ( (self.items & self.weapon) && !am) {
			W_SetCurrentAmmo (self);
			return;
		}
	}
};

/*======================================================================
W_WeaponFrame
======================================================================*/
void() W_WeaponFrame =
{
	if (time < self.attack_finished) return;
	ImpulseCommands ();

	// check for attack
	if (self.button0) {
		// originally - SuperDamageSound
		// Only play one powerup sound at once
		if (self.super_damage_finished > 0 && self.powerup_sound < time) {
			if (self.super_sound < time) {
				self.super_sound = time + 1;
				self.powerup_sound = time + 1;
				sound (self, CHAN_BODY, SOUND_ARTQUAD3, 1, ATTN_NORM);
			}
		}
		// Only play one powerup sound at once
		if (self.sharpshoot_finished > 0 && self.powerup_sound < time) {
			// Only works with the shotguns
			if (self.weapon == IT_SHOTGUN || self.weapon == IT_SUPER_SHOTGUN) {
				if (self.sharpshooter_sound < time) {
					self.sharpshooter_sound = time + 0.5;
					// Only play the sound every other shot
					self.powerup_sound = time + 1;
					sound (self, CHAN_BODY, SOUND_ARTSHARP3, 1, ATTN_NORM);
				}
			}
		}
		// Only play one powerup sound at once
		if (self.nailpiercer_finished > 0 && self.powerup_sound < time) {
			// Only works with nailgun + super nailgun
			if (self.weapon == IT_NAILGUN || self.weapon == IT_SUPER_NAILGUN) {
				if (self.nailpiercer_sound < time) {
					self.nailpiercer_sound = time + 0.5;
					self.powerup_sound = time + 1;
					sound (self, CHAN_BODY, SOUND_ARTNAILP3, 1, ATTN_NORM);
				}
			}
		}
		// Check for weapon updates
		W_Attack ();
	}
};