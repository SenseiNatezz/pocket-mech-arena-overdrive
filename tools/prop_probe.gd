extends Node
## Debug: fires the Gundam's main gun at the nearest barricade and crate and reports what happens.

func _ready() -> void:
	Controls.ignore_real_input = true
	_run.call_deferred()


func _clear_spot(target: Node2D) -> Vector2:
	for off in [Vector2(-220, 0), Vector2(220, 0), Vector2(0, 220), Vector2(0, -220), Vector2(-160, 160), Vector2(160, -160)]:
		var p: Vector2 = target.global_position + off
		var q := PhysicsRayQueryParameters2D.create(p, target.global_position, 1 | 32)
		var hit := get_viewport().world_2d.direct_space_state.intersect_ray(q)
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = p
		pq.collision_mask = 1 | 32 | 64
		if not hit.is_empty() and hit.collider == target and get_viewport().world_2d.direct_space_state.intersect_point(pq).is_empty():
			return p
	return Vector2.INF


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(5)
	var arena := get_tree().current_scene
	arena.zone.is_cleared = true
	var mech := get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	for kind in ["cover_block.gd", "crate.gd", "explosive_barrel.gd"]:
		var target: Node2D = null
		for n in arena.find_children("*", "", true, false):
			var s: Script = n.get_script()
			if s and s.resource_path.ends_with(kind) and _clear_spot(n) != Vector2.INF:
				target = n
				break
		if target == null:
			print(kind, ": none found")
			continue
		# Stand where the line of fire to the target is clear (first thing the ray hits is the target).
		var spot := target.global_position + Vector2(-220, 0)
		for off in [Vector2(-220, 0), Vector2(220, 0), Vector2(0, 220), Vector2(0, -220), Vector2(-160, 160), Vector2(160, -160)]:
			var p: Vector2 = target.global_position + off
			var q := PhysicsRayQueryParameters2D.create(p, target.global_position, 1 | 32)
			var hit := get_viewport().world_2d.direct_space_state.intersect_ray(q)
			var pq := PhysicsPointQueryParameters2D.new()
			pq.position = p
			pq.collision_mask = 1 | 32 | 64
			if not hit.is_empty() and hit.collider == target and get_viewport().world_2d.direct_space_state.intersect_point(pq).is_empty():
				spot = p
				break
		mech.global_position = spot
		await _frames(3)
		Controls.touch_aim = (target.global_position - mech.global_position).normalized()
		var hp0: float = target.get("hp")
		Input.action_press(&"fire_primary")
		var t := 0
		while is_instance_valid(target) and t < 600:
			await get_tree().physics_frame
			t += 1
			if t == 30:
				var act := 0
				var nearest := 1e9
				for b in Combat.world().get_children():
					if b is Bullet and b.active:
						act += 1
						var d: float = b.global_position.distance_to(target.global_position)
						if d < nearest:
							nearest = d
							var pq := PhysicsPointQueryParameters2D.new()
							pq.position = b.global_position
							pq.collision_mask = 32
							var inside := get_viewport().world_2d.direct_space_state.intersect_point(pq)
							var cs: CollisionShape2D = b.get_node("CollisionShape2D")
							print("  bullet at %s mon=%s mask=%d layer=%d overlaps=%d point_in_cover=%d shape_disabled=%s shape=%s scale=%s areas=%d proc=%s" % [
								b.global_position, b.monitoring, b.collision_mask, b.collision_layer, b.get_overlapping_bodies().size(),
								inside.size(), cs.disabled, cs.shape, b.scale, b.get_overlapping_areas().size(), b.is_physics_processing()])
				print("  debug: mech at %s target at %s aim %s active bullets %d nearest %.0f monitoring? layer %d mask %d" % [
					mech.global_position, target.global_position, mech.aim_dir, act, nearest,
					target.get("collision_layer"), target.get("collision_mask")])
		Input.action_release(&"fire_primary")
		print("%s: hp %.0f -> %s after %.1f s" % [kind, hp0, "DESTROYED" if not is_instance_valid(target) else str(target.get("hp")), t / 60.0])
	get_tree().quit()
