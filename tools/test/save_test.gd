extends Node
## Regression test for IGI-style campaign saving and checkpoint resume.

var fails := 0

func _ck(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("[SAVE] FAIL " + what)

func _ready() -> void:
	Game.clear_checkpoint()
	_ck(not Game.has_checkpoint(), "starts with no checkpoint")
	Game.save_checkpoint(3, 4, {"0": 3, "1": 2}, Vector3(12.0, 0.2, -34.0), 87.5, 640)
	_ck(Game.has_checkpoint(), "checkpoint saved")
	_ck(int(Game.checkpoint.get("mission", 0)) == 3, "mission stored")
	_ck(int(Game.checkpoint.get("obj", 0)) == 4, "objective stored")
	# reload from disk exactly like a fresh launch
	Game.checkpoint = {}
	Game.load_igi_save()
	_ck(Game.has_checkpoint(), "checkpoint survives reload")
	var pa: Array = Game.checkpoint.get("pos", [])
	_ck(pa.size() == 3 and is_equal_approx(float(pa[0]), 12.0), "player position stored")

	Game.reset_stats()
	Game.stats["score"] = 2100
	Game.record_mission_result(1, 7, 7, 0, 130.0)
	_ck(Game.mission_records.has(1), "mission result recorded")
	_ck(str((Game.mission_records[1] as Dictionary).get("medal", "")) == "Gold", "gold medal for clean fast run")
	_ck(Game.unlocked >= 2, "next mission unlocked")
	_ck(Game.rank_for_score(9000) == "Elite", "rank progression")
	_ck(str(Game.rank_for_score(0)) == "Recruit", "initial rank")
	Game.clear_checkpoint()
	_ck(not Game.has_checkpoint(), "checkpoint cleared after completion")

	if fails == 0:
		print("[SAVE] PASS - checkpoint save/reload, medals, unlocks, ranks")
		get_tree().quit(0)
	else:
		print("[SAVE] %d failure(s)" % fails)
		get_tree().quit(1)
