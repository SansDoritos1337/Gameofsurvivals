extends "res://scripts/VisualMain.gd"

const HEARING_WALK_RADIUS := 9.0
const HEARING_RUN_RADIUS := 20.0
const HEARING_CROUCH_RADIUS := 2.5
const CHASE_MEMORY_SECONDS := 8.0
const HIT_DISTANCE := 1.35
const RECOVERY_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]
const RECOVERY_LABELS := {KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D"}

var player_downed := false
var recovery_sequence: Array[int] = []
var recovery_index := 0
var recovery_time_left := 0.0
var recovery_panel: PanelContainer
var recovery_label: Label
var ragdoll_root: Node3D
var ragdoll_tween: Tween
var hit_lockout := 0.0
var monster_retreat_time := 5.0

func _ready() -> void:
    super._ready()
    _create_recovery_ui()
    _show_toast("Potwory są ślepe — usłyszą bieganie i strzały.")

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if hit_lockout > 0.0:
        hit_lockout = maxf(0.0, hit_lockout - delta)
    if player_downed and not game_over:
        _update_recovery_minigame(delta)

func _move_player(delta: float) -> void:
    if player == null:
        return
    if player_downed:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 3.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 3.0 * delta)
        if player.is_on_floor():
            player.velocity.y = -0.5
        else:
            player.velocity.y -= GROUND_GRAVITY * delta
        player.move_and_slide()
        player.position.x = clampf(player.position.x, -EXPANDED_WORLD_LIMIT, EXPANDED_WORLD_LIMIT)
        player.position.z = clampf(player.position.z, -EXPANDED_WORLD_LIMIT, EXPANDED_WORLD_LIMIT)
        return

    var input := Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
    )
    var move_direction := Vector3.ZERO
    if input.length_squared() > 0.0:
        var basis := camera.global_transform.basis
        var forward := -basis.z
        forward.y = 0.0
        forward = forward.normalized()
        var right := basis.x
        right.y = 0.0
        right = right.normalized()
        move_direction = right * input.x + forward * input.y
        if move_direction.length_squared() > 0.0:
            move_direction = move_direction.normalized()

    var crouching := Input.is_key_pressed(KEY_CTRL)
    var running := Input.is_key_pressed(KEY_SHIFT) and not crouching
    var speed := 2.0 if crouching else (6.0 if running else 3.8)
    player.velocity.x = move_direction.x * speed
    player.velocity.z = move_direction.z * speed
    if player.is_on_floor():
        if player.velocity.y < 0.0:
            player.velocity.y = -0.5
    else:
        player.velocity.y -= GROUND_GRAVITY * delta
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -EXPANDED_WORLD_LIMIT, EXPANDED_WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -EXPANDED_WORLD_LIMIT, EXPANDED_WORLD_LIMIT)

    if move_direction.length_squared() > 0.0:
        player.rotation.y = atan2(move_direction.x, move_direction.z)
        if running:
            _make_noise(player.position, HEARING_RUN_RADIUS, 0.45)
        elif crouching:
            _make_noise(player.position, HEARING_CROUCH_RADIUS, 0.2)
        else:
            _make_noise(player.position, HEARING_WALK_RADIUS, 0.3)

func _handle_actions(delta: float) -> void:
    if player_downed:
        _update_hud()
        return
    super._handle_actions(delta)

func _spawn_enemy(position: Vector3) -> void:
    var actor := _create_actor(Color("a93e45"), "Monster")
    actor.position = position
    enemies.append({
        "node": actor,
        "state": "idle",
        "target": position,
        "timer": 0.0,
        "speed": rng.randf_range(2.0, 2.7),
        "attack_cooldown": 0.0,
        "retreat_target": position
    })

func _update_enemies(delta: float) -> void:
    for index in range(enemies.size()):
        var enemy: Dictionary = enemies[index]
        var actor := enemy["node"] as CharacterBody3D
        if not is_instance_valid(actor):
            continue

        enemy["timer"] = maxf(0.0, float(enemy["timer"]) - delta)
        enemy["attack_cooldown"] = maxf(0.0, float(enemy["attack_cooldown"]) - delta)
        var to_player := player.global_position - actor.global_position
        to_player.y = 0.0
        var player_distance := to_player.length()
        var hears_player := noise_time > 0.0 and actor.global_position.distance_to(noise_position) <= noise_radius

        # No vision check: the monster only acquires the player when it hears a sound.
        if enemy["state"] != "retreat" and hears_player:
            enemy["state"] = "chase"
            enemy["target"] = noise_position
            enemy["timer"] = CHASE_MEMORY_SECONDS

        var direction := Vector3.ZERO
        match String(enemy["state"]):
            "chase":
                direction = Vector3(enemy["target"]) - actor.global_position
                direction.y = 0.0
                if player_distance < 1.1:
                    direction = to_player
                if float(enemy["timer"]) <= 0.0 and not hears_player:
                    enemy["state"] = "search"
                    enemy["timer"] = 2.5
            "search":
                direction = Vector3(enemy["target"]) - actor.global_position
                direction.y = 0.0
                if direction.length() < 1.0 or float(enemy["timer"]) <= 0.0:
                    enemy["state"] = "idle"
            "retreat":
                direction = Vector3(enemy["retreat_target"]) - actor.global_position
                direction.y = 0.0
                if direction.length() < 1.0 or float(enemy["timer"]) <= 0.0:
                    enemy["state"] = "idle"
            "idle":
                pass

        if direction.length_squared() > 0.01:
            direction = direction.normalized()
            actor.rotation.y = atan2(direction.x, direction.z)
            actor.velocity.x = direction.x * float(enemy["speed"])
            actor.velocity.z = direction.z * float(enemy["speed"])
        else:
            actor.velocity.x = move_toward(actor.velocity.x, 0.0, 5.0 * delta)
            actor.velocity.z = move_toward(actor.velocity.z, 0.0, 5.0 * delta)
        actor.velocity.y = 0.0
        actor.move_and_slide()
        _animate_character(actor, direction.length_squared() > 0.01)

        if player_distance < HIT_DISTANCE and String(enemy["state"]) == "chase" and float(enemy["attack_cooldown"]) <= 0.0 and not player_downed and hit_lockout <= 0.0:
            enemy["attack_cooldown"] = 2.0
            _start_monster_hit(actor, enemy)
        enemies[index] = enemy

func _start_monster_hit(attacker: CharacterBody3D, enemy: Dictionary) -> void:
    if player_downed or game_over:
        return
    player_downed = true
    player_health = maxi(0, player_health - 18)
    hit_lockout = 2.0

    var away := player.global_position - attacker.global_position
    away.y = 0.0
    if away.length_squared() < 0.01:
        away = Vector3.BACK
    away = away.normalized()
    player.velocity = away * 8.0 + Vector3.UP * 4.5

    # The attacker breaks off and runs away while the player completes the recovery challenge.
    enemy["state"] = "retreat"
    enemy["retreat_target"] = attacker.global_position + away * 15.0
    enemy["timer"] = monster_retreat_time
    var enemy_index := _enemy_index_for(attacker)
    if enemy_index >= 0:
        enemies[enemy_index] = enemy

    _set_ragdoll_pose(true)
    _begin_recovery_minigame()
    if player_health <= 0:
        game_over = true
        _show_toast("Koniec gry — naciśnij R, aby zagrać ponownie.")

func _enemy_index_for(actor: CharacterBody3D) -> int:
    for index in range(enemies.size()):
        if enemies[index]["node"] == actor:
            return index
    return -1

func _begin_recovery_minigame() -> void:
    recovery_sequence.clear()
    recovery_index = 0
    recovery_time_left = 12.0
    for index in range(5):
        recovery_sequence.append(RECOVERY_KEYS[rng.randi_range(0, RECOVERY_KEYS.size() - 1)])
    if recovery_panel != null:
        recovery_panel.visible = true
    _refresh_recovery_text()

func _update_recovery_minigame(delta: float) -> void:
    recovery_time_left -= delta
    if recovery_time_left <= 0.0:
        recovery_time_left = 12.0
        recovery_index = 0
        player_health = maxi(0, player_health - 6)
        _show_toast("Nie udało się odzyskać kontroli — spróbuj ponownie!")
        _refresh_recovery_text()
        if player_health <= 0:
            game_over = true
            _show_toast("Koniec gry — naciśnij R, aby zagrać ponownie.")

func _unhandled_input(event: InputEvent) -> void:
    if player_downed and event is InputEventKey and event.pressed and not event.echo:
        var pressed_key := (event as InputEventKey).keycode
        if pressed_key in RECOVERY_KEYS:
            if pressed_key == recovery_sequence[recovery_index]:
                recovery_index += 1
                if recovery_index >= recovery_sequence.size():
                    _finish_recovery()
                else:
                    _refresh_recovery_text()
            else:
                recovery_index = 0
                _show_toast("Zły klawisz — zacznij sekwencję od początku.")
                _refresh_recovery_text()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)

func _finish_recovery() -> void:
    player_downed = false
    hit_lockout = 1.5
    player.velocity = Vector3.ZERO
    player_health = mini(100, player_health + 8)
    _set_ragdoll_pose(false)
    if recovery_panel != null:
        recovery_panel.visible = false
    _show_toast("Udało się! Odzyskujesz kontrolę nad postacią.")

func _set_ragdoll_pose(enabled: bool) -> void:
    if player == null:
        return
    var parts := ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
    if enabled:
        for part_name in parts:
            var part := player.get_node_or_null(part_name) as Node3D
            if part == null:
                continue
            var target_rotation := Vector3(
                rng.randf_range(-0.45, 0.45),
                rng.randf_range(-0.35, 0.35),
                rng.randf_range(-1.1, 1.1)
            )
            part.rotation = target_rotation
    else:
        for part_name in parts:
            var part := player.get_node_or_null(part_name) as Node3D
            if part != null:
                part.rotation = Vector3.ZERO

func _create_recovery_ui() -> void:
    var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
    if canvas == null:
        canvas = CanvasLayer.new()
        add_child(canvas)
    recovery_panel = PanelContainer.new()
    recovery_panel.name = "RecoveryChallenge"
    recovery_panel.set_anchors_preset(Control.PRESET_CENTER)
    recovery_panel.position = Vector2(-250, -90)
    recovery_panel.size = Vector2(500, 180)
    recovery_panel.visible = false
    recovery_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    canvas.add_child(recovery_panel)
    recovery_label = Label.new()
    recovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    recovery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    recovery_label.add_theme_font_size_override("font_size", 22)
    recovery_label.add_theme_color_override("font_color", Color("fff0c4"))
    recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    recovery_panel.add_child(recovery_label)

func _refresh_recovery_text() -> void:
    if recovery_label == null:
        return
    var sequence_text := ""
    for index in range(recovery_sequence.size()):
        var key_label := String(RECOVERY_LABELS[recovery_sequence[index]])
        sequence_text += ("[%s] " if index == recovery_index else "%s ") % key_label
    recovery_label.text = "POTWÓR CIĘ POWALIŁ!\nNaciśnij sekwencję, by odzyskać kontrolę:\n%s\nPozostało: %.1f s" % [sequence_text, maxf(0.0, recovery_time_left)]
