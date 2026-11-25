extends RefCounted
## Weapon statistics shared by the player, villains and allies.
## spread / ads_spread are cone half-angles in degrees. recoil is degrees of camera kick.

const WEAPONS := {
	"bd08": {
		"name": "বিডি-০৮ অ্যাসল্ট রাইফেল", "short": "বিডি-০৮", "damage": 34.0, "rpm": 620.0, "mag": 30, "ammo": "rifle",
		"reload": 2.3, "spread": 2.2, "ads_spread": 0.4, "recoil": 0.85, "range": 170.0, "pen": 2,
		"auto": true, "noise": 55.0, "sound": "sfx_rifle", "zoom": 0.62,
	},
	"pistol": {
		"name": "টাইপ-৫৪ পিস্তল", "short": "পিস্তল", "damage": 28.0, "rpm": 330.0, "mag": 8, "ammo": "pistol",
		"reload": 1.5, "spread": 1.8, "ads_spread": 0.6, "recoil": 1.7, "range": 85.0, "pen": 1,
		"auto": false, "noise": 38.0, "sound": "sfx_pistol", "zoom": 0.8,
	},
	"type56": {
		"name": "টাইপ-৫৬ রাইফেল", "short": "টাইপ-৫৬", "damage": 37.0, "rpm": 600.0, "mag": 30, "ammo": "rifle",
		"reload": 2.6, "spread": 2.8, "ads_spread": 0.6, "recoil": 1.2, "range": 160.0, "pen": 2,
		"auto": true, "noise": 55.0, "sound": "sfx_type56", "zoom": 0.66,
	},
	"sniper": {
		"name": "স্নাইপার রাইফেল", "short": "স্নাইপার", "damage": 48.0, "rpm": 30.0, "mag": 5, "ammo": "rifle",
		"reload": 3.0, "spread": 0.3, "ads_spread": 0.1, "recoil": 4.0, "range": 260.0, "pen": 3,
		"auto": false, "noise": 90.0, "sound": "sfx_sniper", "zoom": 0.3,
	},
	"m4": {
		"name": "M4A1 ডাইরেক্ট-অ্যাকশন", "short": "M4A1", "damage": 31.0, "rpm": 750.0, "mag": 30, "ammo": "rifle",
		"reload": 2.1, "spread": 1.6, "ads_spread": 0.35, "recoil": 0.7, "range": 180.0, "pen": 2,
		"auto": true, "noise": 52.0, "sound": "sfx_rifle", "zoom": 0.6,
	},
	"mp5": {
		"name": "MP5 সাবমেশিন গান", "short": "MP5", "damage": 22.0, "rpm": 900.0, "mag": 30, "ammo": "pistol",
		"reload": 1.9, "spread": 2.4, "ads_spread": 0.7, "recoil": 1.1, "range": 90.0, "pen": 1,
		"auto": true, "noise": 42.0, "sound": "sfx_pistol", "zoom": 0.75,
	},
	"awp": {
		"name": "AWP মার্কসম্যান", "short": "AWP", "damage": 72.0, "rpm": 35.0, "mag": 5, "ammo": "rifle",
		"reload": 3.2, "spread": 0.2, "ads_spread": 0.05, "recoil": 5.0, "range": 320.0, "pen": 4,
		"auto": false, "noise": 95.0, "sound": "sfx_sniper", "zoom": 0.25,
	},
	"lmg": {
		"name": "M249 স্কোয়াড অটোমেটিক", "short": "M249", "damage": 30.0, "rpm": 650.0, "mag": 60, "ammo": "rifle",
		"reload": 4.0, "spread": 3.4, "ads_spread": 1.0, "recoil": 1.6, "range": 190.0, "pen": 3,
		"auto": true, "noise": 65.0, "sound": "sfx_rifle", "zoom": 0.7,
	},
	"deagle": {
		"name": "ডেজার্ট ঈগল", "short": "D.Eagle", "damage": 48.0, "rpm": 260.0, "mag": 7, "ammo": "pistol",
		"reload": 1.8, "spread": 2.0, "ads_spread": 0.5, "recoil": 3.0, "range": 110.0, "pen": 2,
		"auto": false, "noise": 55.0, "sound": "sfx_pistol", "zoom": 0.7,
	},
}

const AMMO_MAX := {"rifle": 300, "pistol": 96}
const AMMO_NAMES := {"rifle": "৭.৬২×৩৯", "pistol": "৭.৬২×২৫"}
