extends Node
## Verify neutral forces: counts, passivity until attacked, and retaliation.
var mission: Node
var t := 0.0
var reported := false

func _ready() -> void:
	Game.settings["tts"] = false
	mission = (load("res://scenes/missions/M01.tscn") as PackedScene).instantiate()
	add_child(mission)

func _process(delta: float) -> void:
	t += delta
	if t > 200.0:
		print("[NEUTRAL] FAIL timeout")
		get_tree().quit(1)
	if mission == null or not bool(mission.get("running")) or reported or t < 3.0:
		return
	reported = true
	var neut := get_tree().get_nodes_in_group("neutrals")
	var military := get_tree().get_nodes_in_group("neutral_military")
	var police := get_tree().get_nodes_in_group("neutral_police")
	var commando := get_tree().get_nodes_in_group("neutral_commando")
	var passive := 0
	for n in neut:
		if not bool(n.get("neutral")):
			continue
		if n.get("target") == null:
			passive += 1
	# Attack one with the hero; it must retaliate.
	var victim = neut[0]
	victim.call("take_damage", 5.0, (victim as Node3D).global_position, Game.player)
	var retaliates: bool = victim.get("target") == Game.player
	# An enemy attacking a neutral must make that neutral target the enemy team.
	var real_enemies := get_tree().get_nodes_in_group("enemies").filter(func(n): return str(n.get("kind")) != "kishor")
	var enemy_retaliation := false
	if neut.size() > 1 and not real_enemies.is_empty():
		var n2 = neut[1]
		n2.call("take_damage", 5.0, (n2 as Node3D).global_position, real_enemies[0])
		enemy_retaliation = n2.get("target") == real_enemies[0]
	var bombs: int = 0
	for n in commando:
		if bool(n.get("bomb_thrower")):
			bombs += 1
	var squads: Dictionary = {}
	for n in military:
		var s := str(n.get("squad"))
		squads[s] = int(squads.get(s, 0)) + 1
	var airforce := get_tree().get_nodes_in_group("neutral_airforce")
	var naval := get_tree().get_nodes_in_group("neutral_naval")
	var protector := get_tree().get_nodes_in_group("neutral_protector")
	var gangs := get_tree().get_nodes_in_group("enemies").filter(func(n): return str(n.get("kind")) == "kishor")
	# Killing an airman must call an airstrike on the attacker.
	var actors_node := Game.level.get_node_or_null("Actors")
	var before: int = actors_node.get_child_count() if actors_node != null else 0
	var airman = airforce[0]
	airman.call("take_damage", 9999.0, (airman as Node3D).global_position, Game.player)
	var after_count: int = actors_node.get_child_count() if actors_node != null else 0
	var after: bool = after_count > before
	print("[NEUTRAL] total=%d military=%d police=%d commando=%d airforce=%d naval=%d protector=%d gangs=%d passive=%d retaliates=%s enemy_retaliation=%s bombers=%d squads=%s airstrike_call=%s" % [
		neut.size(), military.size(), police.size(), commando.size(), airforce.size(), naval.size(),
		protector.size(), gangs.size(), passive, str(retaliates), str(enemy_retaliation), bombs, str(squads), str(after_count - before)])
	var ok := military.size() >= 40 and police.size() >= 40 and airforce.size() >= 40 and naval.size() >= 40 \
		and commando.size() >= 4 and protector.size() == 1 and gangs.size() >= 18 \
		and passive == neut.size() and retaliates and enemy_retaliation and bombs >= 4 and after
	print("[NEUTRAL] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
