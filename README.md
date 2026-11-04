extends Node3D

const ARENA_HALF := 22.0
const PLAYER_HEIGHT := 1.4

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera_rig: Node3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.28

var health := 100
var ammo := 24
var score := 0
var difficulty := "Normal"
var current_state := "menu"
var god_mode := false
var shot_cooldown := 0.0
var spawn_timer := 0.0
var attack_cooldown := 0.0
var notice_timer: SceneTreeTimer

var enemies: Array[CharacterBody3D] = []
var hud: Label
var notice: Label
var admin_panel: PanelContainer
var health_bar: ProgressBar
var menu_overlay: Control

func _ready() -> void:
    rng.randomize()
    _build_world()
    _create_player()
    _create_camera()
    _create_ui()
    _show_main_menu()

func _build_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("101d1d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("dfe6f0")
    env.ambient_light_energy = 0.75
    environment.environment = env
    add_child(environment)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50, -35, 0)
    light.light_energy = 1.0
    light.shadow_enabled = true
    add_child(light)

    var wall_material := StandardMaterial3D.new()
    wall_material.albedo_color = Color("4d4c49")
    wall_material.roughness = 0.9

    var bounds := [
        [Vector3(0, 1.5, -ARENA_HALF), Vector3(44, 3, 1.2)],
        [Vector3(0, 1.5, ARENA_HALF), Vector3(44, 3, 1.2)],
        [Vector3(-ARENA_HALF, 1.5, 0), Vector3(1.2, 3, 44)],
        [Vector3(ARENA_HALF, 1.5, 0), Vector3(1.2, 3, 44)]
    ]

    for i in range(bounds.size()):
        var pos: Vector3 = bounds[i][0]
        var size: Vector3 = bounds[i][1]
        var body := StaticBody3D.new()
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
        var mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mesh.mesh = box
        mesh.material_override = wall_material
        body.add_child(mesh)
        body.position = pos
        add_child(body)

    var crate_positions := [
        Vector3(-12, 0.8, -10), Vector3(9, 0.8, -13), Vector3(-15, 0.8, 8),
        Vector3(12, 0.8, 8), Vector3(-1, 0.7, -16), Vector3(2, 0.7, 12),
        Vector3(-7, 0.7, 3), Vector3(8, 0.7, -3)
    ]
    for i in range(crate_positions.size()):
        var pos := crate_positions[i]
        var body := StaticBody3D.new()
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(3, 1.4, 3)
        collision.shape = shape
        body.add_child(collision)
        var mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(3, 1.4, 3)
        mesh.mesh = box
        var mat := StandardMaterial3D.new(); mat.albedo_color = Color("6a6559"); mat.roughness = 0.9
        mesh.material_override = mat
        body.add_child(mesh)
        body.position = pos
        add_child(body)

    var exit_pad := StaticBody3D.new()
    exit_pad.position = Vector3(16, 0.02, 16)
    var exit_mesh := MeshInstance3D.new(); var exit_box := BoxMesh.new(); exit_box.size = Vector3(4, 0.04, 4)
    exit_mesh.mesh = exit_box; var exit_mat := StandardMaterial3D.new(); exit_mat.albedo_color = Color("1f8e7a"); exit_mat.emission_enabled = true; exit_mat.emission = Color("1f8e7a"); exit_mat.emission_energy_multiplier = 1.0; exit_mesh.material_override = exit_mat; exit_pad.add_child(exit_mesh)
    add_child(exit_pad)

    var beacon := OmniLight3D.new(); beacon.position = Vector3(16, 2.0, 16); beacon.light_energy = 2.2; beacon.omni_range = 8.0; beacon.light_color = Color("69f0d3"); add_child(beacon)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, PLAYER_HEIGHT * 0.5, 0)

    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new(); capsule.radius = 0.45; capsule.height = PLAYER_HEIGHT
    shape.shape = capsule
    player.add_child(shape)

    var mesh := MeshInstance3D.new(); var capsule_mesh := CapsuleMesh.new(); capsule_mesh.radius = 0.45; capsule_mesh.height = PLAYER_HEIGHT; mesh.mesh = capsule_mesh; mesh.material_override = _material(Color("4cb5d9")); player.add_child(mesh)

    var head := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.28; sphere.height = 0.56; head.mesh = sphere; head.position = Vector3(0, 0.76, 0.08); head.material_override = _material(Color("dfe8e2")); player.add_child(head)
    add_child(player)

func _create_camera() -> void:
    camera_rig = Node3D.new(); camera_rig.name = "CameraRig"; add_child(camera_rig)
    camera = Camera3D.new(); camera.name = "Camera3D"; camera.position = Vector3(0, 3.2, 7.4); camera.rotation_degrees.x = -20; camera.current = true; camera_rig.add_child(camera)

func _create_ui() -> void:
    var canvas := CanvasLayer.new(); canvas.name = "UI"; add_child(canvas)

    hud = Label.new(); hud.position = Vector2(20, 18); hud.add_theme_font_size_override("font_size", 20); hud.add_theme_color_override("font_color", Color("f2f5f0")); canvas.add_child(hud)

    health_bar = ProgressBar.new(); health_bar.position = Vector2(20, 100); health_bar.size = Vector2(240, 18); health_bar.max_value = 100; health_bar.value = 100; health_bar.show_percentage = false; canvas.add_child(health_bar)

    notice = Label.new(); notice.set_anchors_preset(Control.PRESET_CENTER_TOP); notice.position = Vector2(-325, 22); notice.size = Vector2(650, 40); notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; notice.add_theme_font_size_override("font_size", 20); notice.add_theme_color_override("font_color", Color("ffe27a")); canvas.add_child(notice)

    admin_panel = PanelContainer.new(); admin_panel.position = Vector2(920, 120); admin_panel.custom_minimum_size = Vector2(300, 340); admin_panel.visible = false; canvas.add_child(admin_panel)
    var box := VBoxContainer.new(); admin_panel.add_child(box)
    var title := Label.new(); title.text = "ADMIN / DEBUG  [F1]"; title.add_theme_font_size_override("font_size", 20); box.add_child(title)
    var status := Label.new(); status.name = "Status"; box.add_child(status)
    _add_admin_button(box, "Spawn potwora", _admin_spawn_enemy)
    _add_admin_button(box, "Uzupełnij HP + ammo", _admin_refill)
    _add_admin_button(box, "God mode", _admin_toggle_god)
    _add_admin_button(box, "Wyczyść wrogów", _admin_clear_enemies)
    _add_admin_button(box, "Zakończ grę", _admin_end_game)

    menu_overlay = Control.new(); menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP; canvas.add_child(menu_overlay)

func _add_admin_button(box: VBoxContainer, text: String, callback: Callable) -> void:
    var button := Button.new(); button.text = text; button.custom_minimum_size.y = 38; button.pressed.connect(callback); box.add_child(button)

func _show_main_menu() -> void:
    current_state = "menu"
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _clear_overlay()
    var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.02, 0.03, 0.04, 0.82); menu_overlay.add_child(shade)
    var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_overlay.add_child(center)
    var panel := VBoxContainer.new(); panel.custom_minimum_size = Vector2(420, 0); panel.add_theme_constant_override("separation", 12); center.add_child(panel)
    var title := Label.new(); title.text = "HUSH 3D"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 48); panel.add_child(title)
    var subtitle := Label.new(); subtitle.text = "CISZA MA ZNACZENIE"; subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(subtitle)
    var select := OptionButton.new(); select.add_item("Łatwy", 0); select.add_item("Normalny", 1); select.add_item("Trudny", 2); select.select(1); panel.add_child(select)
    var start := Button.new(); start.text = "ROZPOCZNIJ"; start.custom_minimum_size.y = 42; start.pressed.connect(_start_game.bind(select)); panel.add_child(start)
    var info := Label.new(); info.text = "WASD ruch • LPM strzał • Shift bieg • F1 admin • Esc pauza"; info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; info.add_theme_font_size_override("font_size", 15); panel.add_child(info)

func _clear_overlay() -> void:
    for child in menu_overlay.get_children():
        child.queue_free()
    menu_overlay.visible = true

func _hide_overlay() -> void:
    menu_overlay.visible = false

func _start_game(option: OptionButton) -> void:
    difficulty = ["Easy", "Normal", "Hard"][option.selected]
    health = 100
    ammo = 24
    score = 0
    god_mode = false
    current_state = "playing"
    _clear_enemies()
    _spawn_enemy(); _spawn_enemy(); _spawn_enemy()
    spawn_timer = _spawn_interval()
    player.position = Vector3(0, 0.7, 0)
    player.velocity = Vector3.ZERO
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _hide_overlay()
    admin_panel.visible = false
    _show_notice("Rozpoczynamy operację. Słuchaj hałasu.")
    _update_hud()

func _show_pause_overlay() -> void:
    _clear_overlay()
    var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.02, 0.03, 0.04, 0.74); menu_overlay.add_child(shade)
    var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_overlay.add_child(center)
    var panel := VBoxContainer.new(); panel.custom_minimum_size = Vector2(500, 0); center.add_child(panel)
    var title := Label.new(); title.text = "PAUZA"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 42); panel.add_child(title)
    var text := Label.new(); text.text = "Naciśnij Esc, aby wrócić do gry."; text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(text)
    var resume := Button.new(); resume.text = "WZNÓW"; resume.custom_minimum_size.y = 44; resume.pressed.connect(func():
        current_state = "playing"
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        _hide_overlay()
    ); panel.add_child(resume)

func _show_game_over() -> void:
    current_state = "game_over"
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _clear_overlay()
    var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.03, 0.02, 0.02, 0.82); menu_overlay.add_child(shade)
    var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_overlay.add_child(center)
    var panel := VBoxContainer.new(); panel.custom_minimum_size = Vector2(500, 0); center.add_child(panel)
    var title := Label.new(); title.text = "KONIEC GRY"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 42); panel.add_child(title)
    var score_text := Label.new(); score_text.text = "Wynik: %d" % score; score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(score_text)
    var menu_btn := Button.new(); menu_btn.text = "MENU GŁÓWNE"; menu_btn.custom_minimum_size.y = 44; menu_btn.pressed.connect(_show_main_menu); panel.add_child(menu_btn)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and current_state == "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * 0.003
        camera_pitch = clamp(camera_pitch - event.relative.y * 0.002, -0.55, 0.25)
        camera_rig.rotation.y = camera_yaw
        camera.rotation.x = camera_pitch

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if current_state == "playing":
                current_state = "paused"
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                _show_pause_overlay()
            elif current_state == "paused":
                current_state = "playing"
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                _hide_overlay()
            elif current_state == "game_over":
                _show_main_menu()
        elif event.keycode == KEY_F1 and current_state == "playing":
            admin_panel.visible = not admin_panel.visible
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if admin_panel.visible else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    if current_state != "playing":
        return

    if shot_cooldown > 0.0:
        shot_cooldown -= delta
    if attack_cooldown > 0.0:
        attack_cooldown -= delta
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_timer = _spawn_interval()
        if enemies.size() < _enemy_cap():
            _spawn_enemy()

    _update_hud()

func _physics_process(delta: float) -> void:
    if current_state != "playing":
        return

    _move_player(delta)
    _update_enemies(delta)
    _update_camera_follow(delta)

func _update_camera_follow(_delta: float) -> void:
    camera_rig.position = player.position + Vector3(0.0, 1.2, 0.0)
    camera.position = Vector3(0.0, 3.0, 7.0)
    camera.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw

func _move_player(delta: float) -> void:
    var input := Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    )

    var movement := Vector3.ZERO
    if input.length_squared() > 0.0:
        input = input.normalized()
        var forward := Vector3(sin(camera_yaw), 0.0, cos(camera_yaw))
        var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
        movement = (forward * input.y + right * input.x).normalized()
        var sprinting := Input.is_key_pressed(KEY_SHIFT)
        var speed := 8.5 if sprinting else 5.4
        player.velocity.x = movement.x * speed
        player.velocity.z = movement.z * speed
        if sprinting:
            _show_notice("Bieg! Słyszysz to?", 0.8)
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 16.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 16.0 * delta)

    player.velocity.y = 0.0
    player.move_and_slide()
    player.position.x = clamp(player.position.x, -ARENA_HALF + 1.0, ARENA_HALF - 1.0)
    player.position.z = clamp(player.position.z, -ARENA_HALF + 1.0, ARENA_HALF - 1.0)

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shot_cooldown <= 0.0:
        _shoot()

func _shoot() -> void:
    if ammo <= 0:
        _show_notice("Brak amunicji.", 1.2)
        return

    shot_cooldown = 0.18
    ammo -= 1

    var from := camera.global_position
    var look_dir := -camera.global_transform.basis.z.normalized()
    var best_enemy: CharacterBody3D = null
    var best_score := INF

    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var to_enemy := enemy.global_position - from
        var dist := to_enemy.length()
        if dist > 55.0:
            continue
        var angle := look_dir.dot(to_enemy.normalized())
        if angle > 0.18:
            var score_candidate := dist * (1.0 - angle)
            if score_candidate < best_score:
                best_score = score_candidate
                best_enemy = enemy

    if best_enemy != null:
        _kill_enemy(best_enemy)
        _show_notice("Celny strzał!", 0.8)
    else:
        _show_notice("Pudło.", 0.7)

func _spawn_enemy() -> void:
    var angle := rng.randf_range(0.0, TAU)
    var dist := rng.randf_range(14.0, 21.0)
    var pos := Vector3(cos(angle) * dist, 0.7, sin(angle) * dist)

    var enemy := CharacterBody3D.new(); enemy.name = "Enemy"; enemy.position = pos
    var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = 0.5; capsule.height = 1.6; shape.shape = capsule; enemy.add_child(shape)
    var mesh := MeshInstance3D.new(); var cmesh := CapsuleMesh.new(); cmesh.radius = 0.5; cmesh.height = 1.6; mesh.mesh = cmesh; mesh.material_override = _material(Color("ad3a3a")); enemy.add_child(mesh)
    var glow := OmniLight3D.new(); glow.position = Vector3(0.0, 0.6, 0.1); glow.light_color = Color("ff5a5a"); glow.light_energy = 0.6; glow.omni_range = 4.5; enemy.add_child(glow)
    add_child(enemy)
    enemies.append(enemy)

func _update_enemies(delta: float) -> void:
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var offset := player.global_position - enemy.global_position
        offset.y = 0.0
        var dist := offset.length()
        if dist > 0.1:
            var dir := offset.normalized()
            var speed := _enemy_speed()
            enemy.velocity.x = dir.x * speed
            enemy.velocity.z = dir.z * speed
            enemy.move_and_slide()
            enemy.rotation.y = atan2(-dir.x, -dir.z)
        else:
            enemy.velocity.x = 0.0
            enemy.velocity.z = 0.0

        if dist < 1.45 and attack_cooldown <= 0.0:
            _damage_player(_enemy_damage())
            attack_cooldown = 0.95 if difficulty == "Hard" else 1.2

func _kill_enemy(enemy: CharacterBody3D) -> void:
    if not is_instance_valid(enemy):
        return
    enemies.erase(enemy)
    enemy.queue_free()
    score += 1

func _damage_player(amount: int) -> void:
    if god_mode:
        return
    health = max(0, health - amount)
    if health <= 0:
        _show_game_over()

func _clear_enemies() -> void:
    for enemy in enemies:
        if is_instance_valid(enemy):
            enemy.queue_free()
    enemies.clear()

func _admin_spawn_enemy() -> void:
    _spawn_enemy()
    _show_notice("DEBUG: dodano wroga.", 1.2)

func _admin_refill() -> void:
    health = 100
    ammo = 24
    _show_notice("DEBUG: odnowiono HP i amunicję.", 1.2)
    _update_hud()

func _admin_toggle_god() -> void:
    god_mode = not god_mode
    _show_notice("God mode: %s" % ("ON" if god_mode else "OFF"), 1.0)

func _admin_clear_enemies() -> void:
    _clear_enemies()
    _show_notice("DEBUG: wszystkie wrogowie usunięte.", 1.2)

func _admin_end_game() -> void:
    _show_game_over()

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.8; return mat

func _spawn_interval() -> float:
    return 2.6 if difficulty == "Hard" else 3.7 if difficulty == "Normal" else 5.0

func _enemy_cap() -> int:
    return 14 if difficulty == "Hard" else 9 if difficulty == "Normal" else 6

func _enemy_speed() -> float:
    return 3.8 if difficulty == "Hard" else 3.0 if difficulty == "Normal" else 2.2

func _enemy_damage() -> int:
    return 18 if difficulty == "Hard" else 12 if difficulty == "Normal" else 8

func _update_hud() -> void:
    if hud == null:
        return
    hud.text = "HUSH 3D  |  %s\nHP: %d\nAmmo: %d\nScore: %d\nEnemies: %d" % [difficulty, health, ammo, score, enemies.size()]
    health_bar.value = health
    if admin_panel != null:
        var status := admin_panel.get_child(0).get_child(1)
        status.text = "Tryb: %s | HP: %d | Ammo: %d | Wrogowie: %d | God: %s" % [difficulty, health, ammo, enemies.size(), str(god_mode)]

func _show_notice(message: String, duration: float) -> void:
    notice.text = message
    if notice_timer != null:
        notice_timer = null
    notice_timer = get_tree().create_timer(duration)
    notice_timer.timeout.connect(func() -> void:
        if notice.text == message:
            notice.text = ""
    )
