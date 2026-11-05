extends Node3D

const WORLD_LIMIT := 24.0
const PLAYER_START := Vector3(0.0, 0.0, 0.0)
const EXIT_POSITION := Vector3(18.0, 0.0, 17.0)
const EXIT_RADIUS := 2.5

var player: CharacterBody3D
var camera: Camera3D
var enemies: Array[Dictionary] = []
var loot_spots: Array[Dictionary] = []
var player_health := 100
var ammo := 12
var loot := 0
var secured_loot := 0
var elapsed := 0.0
var extract_open := false
var game_over := false
var extracted := false
var god_mode := false
var noise_position := Vector3.ZERO
var noise_radius := 0.0
var noise_time := 0.0
var attack_cooldown := 0.0
var shot_cooldown := 0.0
var interaction_cooldown := 0.0
var extract_progress := 0.0
var toast := "Skradaj się. Potwory słyszą hałas."
var toast_time := 5.0
var hud_label: Label
var message_label: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    _create_world()
    _create_player()
    _create_camera()
    _create_hud()
    for position in [Vector3(-12, 0, -8), Vector3(-7, 0, 12), Vector3(4, 0, -13), Vector3(11, 0, 5), Vector3(-16, 0, 3)]:
        _spawn_loot(position)
    _spawn_enemy(Vector3(-17, 0, -13))
    _spawn_enemy(Vector3(15, 0, -13))
    _spawn_enemy(Vector3(11, 0, 14))
    _update_hud()

func _create_world() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    add_child(ground)
    var ground_mesh := MeshInstance3D.new()
    var plane := BoxMesh.new()
    plane.size = Vector3(52, 0.4, 52)
    ground_mesh.mesh = plane
    ground_mesh.position.y = -0.2
    ground_mesh.material_override = _material(Color("202a28"))
    ground.add_child(ground_mesh)
    var ground_collision := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = plane.size
    ground_collision.shape = ground_shape
    ground_collision.position.y = -0.2
    ground.add_child(ground_collision)

    for data in [
        {"position": Vector3(-13, 1, -12), "size": Vector3(7, 2, 5)},
        {"position": Vector3(-3, 1.5, -15), "size": Vector3(6, 3, 5)},
        {"position": Vector3(9, 1, -12), "size": Vector3(8, 2, 5)},
        {"position": Vector3(-14, 1, 13), "size": Vector3(6, 2, 7)},
        {"position": Vector3(1, 1.5, 13), "size": Vector3(8, 3, 5)},
        {"position": Vector3(13, 1, 7), "size": Vector3(5, 2, 7)}
    ]:
        _create_building(data["position"], data["size"])

    var exit_zone := MeshInstance3D.new()
    exit_zone.name = "ExtractionZone"
    var disc := CylinderMesh.new()
    disc.top_radius = EXIT_RADIUS
    disc.bottom_radius = EXIT_RADIUS
    disc.height = 0.12
    exit_zone.mesh = disc
    exit_zone.position = EXIT_POSITION + Vector3(0, 0.06, 0)
    exit_zone.material_override = _material(Color(0.2, 0.65, 0.3, 0.8), true)
    add_child(exit_zone)
    _create_box(self, "ExitBeacon", Vector3(0.35, 2.5, 0.35), EXIT_POSITION + Vector3(0, 1.25, 0), Color("e4c45c"), false)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -25, 0)
    light.light_energy = 1.2
    add_child(light)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("9ba9a5")
    env.ambient_light_energy = 0.55
    environment.environment = env
    add_child(environment)

func _create_building(position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = position
    add_child(body)
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.material_override = _material(Color("39413f"))
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

func _create_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, with_collision: bool) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var box := BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = position
    instance.material_override = _material(color)
    parent.add_child(instance)
    if with_collision:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        parent.add_child(collision)
    return instance

func _material(color: Color, transparent := false) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.9
    if transparent:
        result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return result

func _create_actor(color: Color, actor_name: String) -> CharacterBody3D:
    var actor := CharacterBody3D.new()
    actor.name = actor_name
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    actor.add_child(collision)
    var mesh_instance := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.45
    mesh.height = 1.8
    mesh_instance.mesh = mesh
    mesh_instance.position.y = 0.9
    mesh_instance.material_override = _material(color)
    actor.add_child(mesh_instance)
    add_child(actor)
    return actor

func _create_player() -> void:
    player = _create_actor(Color("55b9d1"), "Player")
    player.position = PLAYER_START

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "GameCamera"
    camera.current = true
    camera.fov = 55.0
    add_child(camera)
    _update_camera()

func _update_camera() -> void:
    if player == null or camera == null:
        return
    camera.position = player.position + Vector3(0, 22, 18)
    camera.look_at(player.position + Vector3(0, 0.4, 0), Vector3.UP)

func _create_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    hud_label = Label.new()
    hud_label.position = Vector2(20, 16)
    hud_label.add_theme_font_size_override("font_size", 18)
    hud_label.add_theme_color_override("font_color", Color("f1f3eb"))
    canvas.add_child(hud_label)
    message_label = Label.new()
    message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    message_label.position = Vector2(-380, 20)
    message_label.size = Vector2(760, 40)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 20)
    message_label.add_theme_color_override("font_color", Color("ffd37a"))
    canvas.add_child(message_label)

func _physics_process(delta: float) -> void:
    if game_over or extracted:
        _update_camera()
        return
    elapsed += delta
    if elapsed >= 35.0:
        extract_open = true
    noise_time = maxf(0.0, noise_time - delta)
    toast_time = maxf(0.0, toast_time - delta)
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    shot_cooldown = maxf(0.0, shot_cooldown - delta)
    interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
    _move_player(delta)
    _update_enemies(delta)
    _handle_actions(delta)
    _update_camera()
    _update_hud()

func _move_player(delta: float) -> void:
    var input := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
    var direction := Vector3(input.x, 0, input.y)
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    var crouching := Input.is_key_pressed(KEY_CTRL)
    var running := Input.is_key_pressed(KEY_SHIFT) and not crouching
    var speed := 2.0 if crouching else (6.0 if running else 3.8)
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    player.velocity.y = 0.0
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)
    if direction.length_squared() > 0.0:
        if running:
            _make_noise(player.position, 12.0, 0.3)
        elif not crouching:
            _make_noise(player.position, 6.0, 0.2)

func _spawn_enemy(position: Vector3) -> void:
    var actor := _create_actor(Color("a93e45"), "Monster")
    actor.position = position
    enemies.append({"node": actor, "alert": false, "speed": rng.randf_range(2.0, 2.7)})

func _update_enemies(delta: float) -> void:
    for enemy in enemies:
        var actor: CharacterBody3D = enemy["node"]
        if not is_instance_valid(actor):
            continue
        var offset := player.position - actor.position
        offset.y = 0.0
        var distance := offset.length()
        var hears_player := noise_time > 0.0 and actor.position.distance_to(noise_position) < noise_radius
        if distance < 8.0 or hears_player:
            enemy["alert"] = true
        var direction := Vector3.ZERO
        if enemy["alert"] and distance > 0.1:
            direction = offset.normalized()
        actor.velocity = direction * float(enemy["speed"])
        actor.velocity.y = 0.0
        actor.move_and_slide()
        if distance < 1.25 and attack_cooldown <= 0.0:
            _damage_player(12)
            attack_cooldown = 1.0
            _show_toast("Potwór cię dopadł!")

func _spawn_loot(position: Vector3) -> void:
    var box := _create_box(self, "Supplies", Vector3(0.8, 0.65, 0.8), position + Vector3(0, 0.33, 0), Color("d2ad54"), false)
    loot_spots.append({"node": box, "position": position, "taken": false})

func _handle_actions(delta: float) -> void:
    if Input.is_key_pressed(KEY_E) and interaction_cooldown <= 0.0:
        var nearest_index := -1
        var nearest_distance := 2.0
        for i in range(loot_spots.size()):
            if loot_spots[i]["taken"]:
                continue
            var distance: float = player.position.distance_to(loot_spots[i]["position"])
            if distance < nearest_distance:
                nearest_index = i
                nearest_distance = distance
        if nearest_index >= 0:
            loot_spots[nearest_index]["taken"] = true
            loot_spots[nearest_index]["node"].queue_free()
            loot += 1
            interaction_cooldown = 0.5
            _make_noise(player.position, 7.0, 0.5)
            _show_toast("Zebrano zapasy. Hałas może przyciągnąć potwory!")
        elif _flat_distance(player.position, EXIT_POSITION) < EXIT_RADIUS + 1.0:
            if extract_open:
                extract_progress += delta
                if extract_progress >= 2.0:
                    secured_loot += loot
                    loot = 0
                    extracted = true
                    _show_toast("Udało się uciec! Zabezpieczony łup: %d" % secured_loot)
            else:
                _show_toast("Wyjście otworzy się po 35 sekundach.")
    else:
        extract_progress = 0.0

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shot_cooldown <= 0.0 and ammo > 0:
        ammo -= 1
        shot_cooldown = 0.35
        _make_noise(player.position, 22.0, 0.8)
        _fire_at_mouse()
    _update_hud()

func _fire_at_mouse() -> void:
    var ray_origin := camera.project_ray_origin(get_viewport().get_mouse_position())
    var ray_direction := camera.project_ray_normal(get_viewport().get_mouse_position())
    var target = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
    if target == null:
        return
    var direction: Vector3 = target - player.position
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        return
    direction = direction.normalized()
    var best_index := -1
    var best_distance := 9999.0
    for i in range(enemies.size()):
        var actor: CharacterBody3D = enemies[i]["node"]
        if not is_instance_valid(actor):
            continue
        var offset: Vector3 = actor.position - player.position
        offset.y = 0.0
        var along := offset.dot(direction)
        var side := absf(offset.cross(direction).length())
        if along > 0.0 and side < 0.8 and along < best_distance:
            best_index = i
            best_distance = along
    if best_index >= 0 and best_distance < 16.0:
        var enemy_node: CharacterBody3D = enemies[best_index]["node"]
        enemy_node.queue_free()
        enemies.remove_at(best_index)
        _show_toast("Potwór pokonany! Strzał było słychać z daleka.")

func _flat_distance(a: Vector3, b: Vector3) -> float:
    var flat_a := Vector2(a.x, a.z)
    var flat_b := Vector2(b.x, b.z)
    return flat_a.distance_to(flat_b)

func _make_noise(position: Vector3, radius: float, duration: float) -> void:
    if duration >= noise_time or radius > noise_radius:
        noise_position = position
        noise_radius = radius
    noise_time = maxf(noise_time, duration)

func _damage_player(amount: int) -> void:
    if god_mode:
        return
    player_health = maxi(0, player_health - amount)
    if player_health <= 0:
        game_over = true
        _show_toast("Koniec gry — naciśnij R, aby zacząć od nowa.")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F1:
            god_mode = not god_mode
            _show_toast("Nieśmiertelność %s." % ("włączona" if god_mode else "wyłączona"))
        elif event.keycode == KEY_R and (game_over or extracted):
            get_tree().reload_current_scene()

func _show_toast(text: String) -> void:
    toast = text
    toast_time = 3.0

func _update_hud() -> void:
    if hud_label == null:
        return
    var exit_text := "OTWARTE" if extract_open else "zamknięte za %d s" % maxi(0, int(ceil(35.0 - elapsed)))
    var admin_text := "  |  Nieśmiertelność: TAK" if god_mode else ""
    hud_label.text = "HP: %d   Amunicja: %d   Łup: %d   Zabezpieczony: %d\nWyjście: %s%s\nWASD ruch | Ctrl skradanie | Shift bieg | E zbieraj/uciekaj | LPM strzał | F1 nieśmiertelność" % [player_health, ammo, loot, secured_loot, exit_text, admin_text]
    if game_over:
        message_label.text = "KONIEC GRY — naciśnij R, aby zagrać ponownie"
    elif extracted:
        message_label.text = "UCIECZKA UDANA! — naciśnij R, aby zagrać ponownie"
    elif toast_time > 0.0:
        message_label.text = toast
    elif _flat_distance(player.position, EXIT_POSITION) < EXIT_RADIUS + 2.0 and extract_open:
        message_label.text = "Przytrzymaj E w strefie wyjścia, aby uciec."
    else:
        message_label.text = ""
