extends "res://scripts/SoundHunterMain.gd"

const DODGE_DURATION := 5.0
const DODGE_PLAYER_SPEED := 250.0
const DODGE_ARENA_MIN := Vector2(18.0, 18.0)
const DODGE_ARENA_MAX := Vector2(402.0, 182.0)

var dodge_arena: Control
var dodge_heart: ColorRect
var dodge_status: Label
var dodge_bullets: Array[Dictionary] = []
var dodge_position := Vector2(210.0, 100.0)
var dodge_time := 0.0
var bullet_spawn_timer := 0.0
var dodge_hearts := 3
var dodge_rng := RandomNumberGenerator.new()

func _ready() -> void:
    super._ready()
    dodge_rng.randomize()
    _setup_dodge_minigame()

func _begin_recovery_minigame() -> void:
    # Quick Undertale-inspired dodge round: avoid the incoming projectiles for five seconds.
    player_downed = true
    dodge_time = DODGE_DURATION
    bullet_spawn_timer = 0.0
    dodge_hearts = 3
    dodge_position = Vector2(210.0, 100.0)
    _clear_dodge_bullets()
    if recovery_panel != null:
        recovery_panel.visible = true
    _update_dodge_status()
    _place_dodge_heart()

func _update_recovery_minigame(delta: float) -> void:
    if not player_downed or game_over:
        return

    dodge_time -= delta
    bullet_spawn_timer -= delta
    if bullet_spawn_timer <= 0.0:
        _spawn_dodge_bullet()
        bullet_spawn_timer = 0.42

    var move := Vector2(
        float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
        float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    )
    if move.length_squared() > 0.0:
        dodge_position += move.normalized() * DODGE_PLAYER_SPEED * delta
    dodge_position.x = clampf(dodge_position.x, DODGE_ARENA_MIN.x, DODGE_ARENA_MAX.x)
    dodge_position.y = clampf(dodge_position.y, DODGE_ARENA_MIN.y, DODGE_ARENA_MAX.y)
    _place_dodge_heart()

    for index in range(dodge_bullets.size() - 1, -1, -1):
        var bullet: Dictionary = dodge_bullets[index]
        var bullet_node := bullet["node"] as ColorRect
        if not is_instance_valid(bullet_node):
            dodge_bullets.remove_at(index)
            continue
        var position: Vector2 = bullet["position"]
        var velocity: Vector2 = bullet["velocity"]
        position += velocity * delta
        bullet["position"] = position
        bullet_node.position = position - bullet_node.size * 0.5

        if position.distance_to(dodge_position) < 17.0:
            bullet_node.queue_free()
            dodge_bullets.remove_at(index)
            dodge_hearts -= 1
            _update_dodge_status()
            if dodge_hearts <= 0:
                _fail_dodge_round()
            continue
        if position.x < -25.0 or position.y < -25.0 or position.x > dodge_arena.size.x + 25.0 or position.y > dodge_arena.size.y + 25.0:
            bullet_node.queue_free()
            dodge_bullets.remove_at(index)

    if dodge_time <= 0.0:
        _finish_recovery()
        _show_toast("Unik! Odzyskujesz kontrolę nad postacią.")
    else:
        _update_dodge_status()

func _unhandled_input(event: InputEvent) -> void:
    # Dodge controls are polled during the round; don't pass movement keys to the old sequence prompt.
    if player_downed:
        if event is InputEventKey:
            get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _setup_dodge_minigame() -> void:
    if recovery_panel == null:
        return
    recovery_panel.custom_minimum_size = Vector2(480.0, 300.0)
    for child in recovery_panel.get_children():
        child.queue_free()

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    recovery_panel.add_child(layout)

    var title := Label.new()
    title.text = "UNIKAJ!"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("fff0c4"))
    layout.add_child(title)

    dodge_status = Label.new()
    dodge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dodge_status.add_theme_font_size_override("font_size", 18)
    dodge_status.add_theme_color_override("font_color", Color("fff0c4"))
    layout.add_child(dodge_status)

    dodge_arena = Control.new()
    dodge_arena.name = "DodgeArena"
    dodge_arena.custom_minimum_size = Vector2(420.0, 205.0)
    dodge_arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dodge_arena.clip_contents = true
    layout.add_child(dodge_arena)

    var background := ColorRect.new()
    background.color = Color("171b22")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dodge_arena.add_child(background)

    var border := ReferenceRect.new()
    border.border_color = Color("d8d1bd")
    border.border_width = 3.0
    border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dodge_arena.add_child(border)

    dodge_heart = ColorRect.new()
    dodge_heart.name = "DodgeHeart"
    dodge_heart.color = Color("ff4355")
    dodge_heart.size = Vector2(15.0, 15.0)
    dodge_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dodge_arena.add_child(dodge_heart)

func _spawn_dodge_bullet() -> void:
    if dodge_arena == null:
        return
    var arena_size := dodge_arena.size
    if arena_size.x < 100.0 or arena_size.y < 100.0:
        arena_size = Vector2(420.0, 205.0)
    var edge := dodge_rng.randi_range(0, 3)
    var start := Vector2.ZERO
    match edge:
        0:
            start = Vector2(0.0, dodge_rng.randf_range(0.0, arena_size.y))
        1:
            start = Vector2(arena_size.x, dodge_rng.randf_range(0.0, arena_size.y))
        2:
            start = Vector2(dodge_rng.randf_range(0.0, arena_size.x), 0.0)
        _:
            start = Vector2(dodge_rng.randf_range(0.0, arena_size.x), arena_size.y)
    var aim := dodge_position - start
    if aim.length_squared() < 0.01:
        aim = Vector2.RIGHT
    var speed := dodge_rng.randf_range(145.0, 220.0)
    var bullet_node := ColorRect.new()
    bullet_node.name = "DodgeProjectile"
    bullet_node.color = Color("e9e3d5")
    bullet_node.size = Vector2(12.0, 12.0)
    bullet_node.position = start - bullet_node.size * 0.5
    bullet_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dodge_arena.add_child(bullet_node)
    dodge_bullets.append({"node": bullet_node, "position": start, "velocity": aim.normalized() * speed})

func _place_dodge_heart() -> void:
    if dodge_heart != null:
        dodge_heart.position = dodge_position - dodge_heart.size * 0.5

func _update_dodge_status() -> void:
    if dodge_status != null:
        dodge_status.text = "WASD / strzałki: unikaj pocisków   Życia: %d   Czas: %.1f s" % [dodge_hearts, maxf(0.0, dodge_time)]

func _fail_dodge_round() -> void:
    dodge_hearts = 3
    dodge_time = DODGE_DURATION
    dodge_position = dodge_arena.size * 0.5
    _clear_dodge_bullets()
    player_health = maxi(0, player_health - 8)
    _show_toast("Trafienie! Minigra zaczyna się ponownie.")
    _update_dodge_status()
    _place_dodge_heart()
    if player_health <= 0:
        game_over = true
        _show_toast("Koniec gry — naciśnij R, aby zagrać ponownie.")

func _clear_dodge_bullets() -> void:
    for bullet in dodge_bullets:
        var node := bullet["node"] as Node
        if is_instance_valid(node):
            node.queue_free()
    dodge_bullets.clear()
