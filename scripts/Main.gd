extends Node2D

const WORLD_SIZE := Vector2(1280, 720)
const PLAYER_START := Vector2(620, 360)
const EXTRACT_POS := Vector2(1110, 590)
const EXTRACT_RADIUS := 58.0

var player_pos := PLAYER_START
var player_health := 100
var ammo := 12
var loot := 0
var secured_loot := 0
var elapsed := 0.0
var extract_open := false
var game_over := false
var extracted := false
var god_mode := false
var enemies: Array[Dictionary] = []
var loot_spots: Array[Dictionary] = []
var noise_pos := Vector2.ZERO
var noise_radius := 0.0
var noise_time := 0.0
var attack_cooldown := 0.0
var shot_cooldown := 0.0
var extract_progress := 0.0
var toast := "Skradaj się. Potwory słyszą hałas."
var toast_time := 5.0
var hud_label: Label
var message_label: Label
var panel: PanelContainer
var panel_status: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    for pos in [Vector2(270, 180), Vector2(500, 530), Vector2(840, 220), Vector2(940, 470), Vector2(350, 390)]:
        loot_spots.append({"pos": pos, "taken": false})
    _build_hud()
    _spawn_enemy_at(Vector2(170, 140))
    _spawn_enemy_at(Vector2(1080, 170))
    _spawn_enemy_at(Vector2(870, 560))
    _update_hud()

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    hud_label = Label.new()
    hud_label.position = Vector2(22, 18)
    hud_label.add_theme_font_size_override("font_size", 20)
    hud_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.9))
    canvas.add_child(hud_label)
    message_label = Label.new()
    message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    message_label.position = Vector2(-310, 18)
    message_label.size = Vector2(620, 40)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 19)
    message_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.48))
    canvas.add_child(message_label)

    panel = PanelContainer.new()
    panel.position = Vector2(930, 110)
    panel.custom_minimum_size = Vector2(315, 400)
    panel.visible = false
    canvas.add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    var title := Label.new()
    title.text = "ADMIN PANEL  [F1]"
    title.add_theme_font_size_override("font_size", 22)
    box.add_child(title)
    panel_status = Label.new()
    box.add_child(panel_status)
    _add_admin_button(box, "Dodaj potwora", _admin_spawn_enemy)
    _add_admin_button(box, "Dodaj łup", _admin_spawn_loot)
    _add_admin_button(box, "Otwórz / zamknij wyjście", _admin_toggle_extract)
    _add_admin_button(box, "Przywróć zdrowie i amunicję", _admin_heal)
    _add_admin_button(box, "God mode: włącz / wyłącz", _admin_toggle_god)
    _add_admin_button(box, "Wyczyść potwory", _admin_clear_enemies)
    _add_admin_button(box, "Restart gry", _restart_game)

func _add_admin_button(box: VBoxContainer, title: String, action: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 38
    button.pressed.connect(action)
    box.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F1:
            panel.visible = not panel.visible
        elif event.keycode == KEY_ESCAPE and panel.visible:
            panel.visible = false
        elif event.keycode == KEY_R and (game_over or extracted):
            _restart_game()

func _process(delta: float) -> void:
    if game_over or extracted:
        queue_redraw()
        return

    elapsed += delta
    if elapsed >= 35.0:
        extract_open = true
    if noise_time > 0.0:
        noise_time = maxf(0.0, noise_time - delta)
    if toast_time > 0.0:
        toast_time -= delta
    if attack_cooldown > 0.0:
        attack_cooldown -= delta
    if shot_cooldown > 0.0:
        shot_cooldown -= delta

    _move_player(delta)
    _update_enemies(delta)
    _handle_actions(delta)
    _update_hud()
    queue_redraw()

func _move_player(delta: float) -> void:
    var direction := Vector2.ZERO
    direction.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    direction.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    if direction.length_squared() > 0.0:
        direction = direction.normalized()
        var crouching := Input.is_key_pressed(KEY_CTRL)
        var running := Input.is_key_pressed(KEY_SHIFT) and not crouching
        var speed := 100.0 if crouching else (280.0 if running else 175.0)
        player_pos += direction * speed * delta
        if running:
            _make_noise(player_pos, 300.0, 0.16)
        elif not crouching:
            _make_noise(player_pos, 145.0, 0.10)
    player_pos.x = clampf(player_pos.x, 25.0, WORLD_SIZE.x - 25.0)
    player_pos.y = clampf(player_pos.y, 25.0, WORLD_SIZE.y - 25.0)

func _update_enemies(delta: float) -> void:
    for enemy in enemies:
        var pos: Vector2 = enemy["pos"]
        var distance := pos.distance_to(player_pos)
        var hears_player := noise_time > 0.0 and pos.distance_to(noise_pos) < noise_radius
        var sees_player := distance < 125.0
        if hears_player or sees_player:
            enemy["alert"] = true
        if enemy["alert"]:
            var direction := (player_pos - pos).normalized()
            pos += direction * float(enemy["speed"]) * delta
            enemy["pos"] = pos
            if pos.distance_to(player_pos) < 27.0 and attack_cooldown <= 0.0:
                _damage_player(12)
                attack_cooldown = 1.0
                _show_toast("Potwór cię dopadł!")

func _handle_actions(delta: float) -> void:
    if Input.is_key_pressed(KEY_E):
        var nearest := -1
        var nearest_distance := 99999.0
        for i in range(loot_spots.size()):
            if loot_spots[i]["taken"]:
                continue
            var distance: float = player_pos.distance_to(loot_spots[i]["pos"])
            if distance < nearest_distance:
                nearest = i
                nearest_distance = distance
        if nearest >= 0 and nearest_distance < 48.0:
            loot_spots[nearest]["taken"] = true
            loot += 1
            _make_noise(player_pos, 180.0, 0.25)
            _show_toast("Zebrano zapasy. Hałas może przyciągnąć potwory!")
        elif player_pos.distance_to(EXTRACT_POS) < EXTRACT_RADIUS + 12.0:
            if extract_open:
                extract_progress += delta
                if extract_progress >= 2.0:
                    secured_loot += loot
                    loot = 0
                    extracted = true
                    _show_toast("Udało się uciec! Łup zabezpieczony: %d" % secured_loot)
            else:
                _show_toast("Wyjście otworzy się po 35 sekundach.")
    else:
        extract_progress = 0.0

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shot_cooldown <= 0.0 and ammo > 0:
        ammo -= 1
        shot_cooldown = 0.35
        _make_noise(player_pos, 560.0, 0.8)
        _fire_at_mouse()

func _fire_at_mouse() -> void:
    var target := get_global_mouse_position()
    var direction := (target - player_pos).normalized()
    var best_index := -1
    var best_distance := 99999.0
    for i in range(enemies.size()):
        var enemy_pos: Vector2 = enemies[i]["pos"]
        var offset := enemy_pos - player_pos
        var along := offset.dot(direction)
        var side := absf(offset.cross(direction))
        if along > 0.0 and side < 30.0 and along < best_distance:
            best_index = i
            best_distance = along
    if best_index >= 0 and best_distance < 450.0:
        enemies.remove_at(best_index)
        _show_toast("Potwór powalony. Strzał było słychać z daleka!")

func _make_noise(pos: Vector2, radius: float, duration: float) -> void:
    if duration >= noise_time or radius > noise_radius:
        noise_pos = pos
        noise_radius = radius
    noise_time = maxf(noise_time, duration)

func _damage_player(amount: int) -> void:
    if god_mode:
        return
    player_health = maxi(0, player_health - amount)
    if player_health <= 0:
        game_over = true
        _show_toast("Koniec gry — naciśnij R, aby zacząć od nowa.")

func _spawn_enemy_at(pos: Vector2) -> void:
    enemies.append({"pos": pos, "alert": false, "speed": rng.randf_range(70.0, 95.0)})

func _admin_spawn_enemy() -> void:
    _spawn_enemy_at(Vector2(rng.randf_range(70.0, 1210.0), rng.randf_range(70.0, 650.0)))
    _show_toast("Admin: dodano potwora.")

func _admin_spawn_loot() -> void:
    loot_spots.append({"pos": Vector2(rng.randf_range(80.0, 1180.0), rng.randf_range(80.0, 640.0)), "taken": false})
    _show_toast("Admin: dodano zapasy.")

func _admin_toggle_extract() -> void:
    extract_open = not extract_open
    _show_toast("Admin: wyjście %s." % ("otwarte" if extract_open else "zamknięte"))

func _admin_heal() -> void:
    player_health = 100
    ammo = 12
    game_over = false
    _show_toast("Admin: zdrowie i amunicja uzupełnione.")

func _admin_toggle_god() -> void:
    god_mode = not god_mode
    _show_toast("God mode %s." % ("włączony" if god_mode else "wyłączony"))

func _admin_clear_enemies() -> void:
    enemies.clear()
    _show_toast("Admin: usunięto wszystkie potwory.")

func _restart_game() -> void:
    get_tree().reload_current_scene()

func _show_toast(text: String) -> void:
    toast = text
    toast_time = 3.0

func _update_hud() -> void:
    var exit_text := "OTWARTE" if extract_open else "zamknięte za %d s" % maxi(0, int(ceil(35.0 - elapsed)))
    hud_label.text = "HP: %d%s   Amunicja: %d   Łup: %d   Zabezpieczony łup: %d\nWyjście: %s   |   WASD ruch, Ctrl skradanie, Shift bieg, E interakcja, LPM strzał, F1 admin" % [player_health, " (GOD)" if god_mode else "", ammo, loot, secured_loot, exit_text]
    message_label.text = toast if toast_time > 0.0 else ("Przytrzymaj E w strefie wyjścia, aby uciec." if player_pos.distance_to(EXTRACT_POS) < EXTRACT_RADIUS + 25.0 and extract_open else "")
    if panel_status != null:
        panel_status.text = "HP %d | ammo %d | loot %d | potwory %d" % [player_health, ammo, loot, enemies.size()]

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("111719"))
    for x in range(0, 1280, 48):
        draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.18, 0.22, 0.22, 0.25), 1.0)
    for y in range(0, 720, 48):
        draw_line(Vector2(0, y), Vector2(1280, y), Color(0.18, 0.22, 0.22, 0.25), 1.0)

    # Ruined buildings and cover
    for rect in [Rect2(120, 110, 150, 100), Rect2(360, 90, 180, 130), Rect2(680, 120, 180, 95), Rect2(980, 100, 150, 130), Rect2(150, 470, 190, 120), Rect2(430, 430, 170, 150), Rect2(710, 490, 190, 110), Rect2(970, 360, 150, 120)]:
        draw_rect(rect, Color("303839"))
        draw_rect(rect, Color(0.55, 0.59, 0.54, 0.35), false, 2.0)
        draw_line(rect.position + Vector2(12, 12), rect.position + rect.size - Vector2(12, 12), Color(0.1, 0.12, 0.12), 3.0)

    # Extraction zone
    draw_circle(EXTRACT_POS, EXTRACT_RADIUS, Color(0.15, 0.48, 0.27, 0.25) if extract_open else Color(0.55, 0.16, 0.12, 0.25))
    draw_arc(EXTRACT_POS, EXTRACT_RADIUS, 0.0, TAU, 48, Color(0.35, 0.9, 0.48) if extract_open else Color(0.9, 0.36, 0.28), 3.0)
    draw_string(ThemeDB.fallback_font, EXTRACT_POS + Vector2(-38, 5), "WAY OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

    for spot in loot_spots:
        if not spot["taken"]:
            var pos: Vector2 = spot["pos"]
            draw_rect(Rect2(pos - Vector2(9, 9), Vector2(18, 18)), Color("d2ad54"))
            draw_rect(Rect2(pos - Vector2(9, 9), Vector2(18, 18)), Color("fff0a0"), false, 2.0)

    if noise_time > 0.0:
        draw_arc(noise_pos, noise_radius, 0.0, TAU, 64, Color(0.95, 0.25, 0.2, 0.35), 2.0)

    for enemy in enemies:
        var pos: Vector2 = enemy["pos"]
        draw_circle(pos, 15.0, Color("bc3939") if enemy["alert"] else Color("704046"))
        draw_circle(pos + Vector2(4, -3), 3.0, Color("fff0d0"))
        if enemy["alert"]:
            draw_string(ThemeDB.fallback_font, pos + Vector2(-5, -22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffcc55"))

    draw_circle(player_pos, 13.0, Color("61b7cf"))
    draw_circle(player_pos + Vector2(4, -3), 3.0, Color("e8ffff"))
    draw_arc(player_pos, 20.0, 0.0, TAU, 32, Color(0.6, 0.9, 1.0, 0.45), 2.0)

    if game_over or extracted:
        draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.02, 0.03, 0.04, 0.72))
        var title := "UCIECZKA UDANA" if extracted else "KONIEC GRY"
        draw_string(ThemeDB.fallback_font, Vector2(0, 320), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 48, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(0, 365), "Naciśnij R, aby zagrać ponownie", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("dddddd"))
