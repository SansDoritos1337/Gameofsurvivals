extends "res://scripts/ExpandedMain.gd"

const RESPAWN_DELAY := 15.0
const FIRST_PERSON_FOV := 42.0

var respawn_timer := -1.0
var selected_weapon := "pistol"
var weapon_root: Node3D
var weapon_label: Label
var crosshair: Label
var terrain_rng := RandomNumberGenerator.new()

func _ready() -> void:
    super._ready()
    terrain_rng.randomize()
    _build_weapon_view()
    _build_terrain_details()
    _add_weapon_hud()

func _process(_delta: float) -> void:
    # Keep inherited gameplay updates in the physics callback only.
    _update_aim_visuals()

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if game_over or extracted:
        return
    _update_enemy_respawn(delta)
    _update_aim_visuals()
    _update_weapon_hud()

func _unhandled_input(event: InputEvent) -> void:
    super._unhandled_input(event)
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_1:
            selected_weapon = "pistol"
            _show_toast("Wybrano pistolet.")
        elif event.keycode == KEY_2:
            selected_weapon = "rifle"
            _show_toast("Wybrano karabin.")

func _handle_actions(delta: float) -> void:
    var ammo_before := ammo
    super._handle_actions(delta)
    if ammo < ammo_before and selected_weapon == "rifle":
        shot_cooldown = 0.14

func _fire_at_mouse() -> void:
    # Aim and fire at the centre of the screen, not at the free cursor.
    var screen_center := get_viewport().get_visible_rect().size * 0.5
    var ray_origin := camera.project_ray_origin(screen_center)
    var ray_direction := camera.project_ray_normal(screen_center)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 60.0)
    query.exclude = [player.get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var target := hit.get("collider") as Node
    if target == null or target.name != "Monster":
        return
    for index in range(enemies.size()):
        var enemy_actor: CharacterBody3D = enemies[index]["node"]
        if enemy_actor == target:
            enemy_actor.queue_free()
            enemies.remove_at(index)
            _show_toast("Trafienie! Strzał może zwabić potwory.")
            return

func _update_enemy_respawn(delta: float) -> void:
    if not enemies.is_empty():
        respawn_timer = -1.0
        return
    if respawn_timer < 0.0:
        respawn_timer = RESPAWN_DELAY
        _show_toast("Wszystkie potwory zginęły. Nowa grupa pojawi się za 15 sekund.")
        return
    respawn_timer = maxf(0.0, respawn_timer - delta)
    if respawn_timer <= 0.0:
        var spawn_points := [Vector3(-21, 0, -20), Vector3(21, 0, -18), Vector3(-20, 0, 20), Vector3(20, 0, 20)]
        for index in range(3):
            var spawn_position: Vector3 = spawn_points[(wave_number + index) % spawn_points.size()]
            _spawn_enemy(spawn_position)
        respawn_timer = -1.0
        _show_toast("Potwory wróciły!")

func _build_weapon_view() -> void:
    if camera == null:
        return
    weapon_root = Node3D.new()
    weapon_root.name = "FirstPersonWeapon"
    weapon_root.position = Vector3(0.32, -0.28, -0.62)
    camera.add_child(weapon_root)

    # Low-poly hands and a compact weapon, visible only while aiming in first person.
    _create_box(weapon_root, "Sleeve", Vector3(0.22, 0.26, 0.28), Vector3(-0.2, -0.07, 0.08), Color("405b70"), false)
    _create_box(weapon_root, "Hand", Vector3(0.16, 0.13, 0.18), Vector3(-0.07, -0.08, -0.12), Color("d0a07e"), false)
    _create_box(weapon_root, "PistolBody", Vector3(0.16, 0.16, 0.48), Vector3(0.0, 0.0, -0.18), Color("272d32"), false)
    _create_box(weapon_root, "PistolGrip", Vector3(0.12, 0.24, 0.15), Vector3(0.0, -0.17, -0.04), Color("39312a"), false)
    _create_box(weapon_root, "RifleBody", Vector3(0.14, 0.16, 0.72), Vector3(0.0, 0.02, -0.24), Color("343b38"), false)
    _create_box(weapon_root, "RifleBarrel", Vector3(0.07, 0.07, 0.48), Vector3(0.0, 0.03, -0.78), Color("202426"), false)
    _create_box(weapon_root, "RifleStock", Vector3(0.18, 0.17, 0.26), Vector3(0.0, 0.0, 0.25), Color("554537"), false)
    _create_box(weapon_root, "RifleSight", Vector3(0.07, 0.12, 0.12), Vector3(0.0, 0.14, -0.27), Color("15191b"), false)
    weapon_root.visible = false

func _add_weapon_hud() -> void:
    var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
    if canvas == null:
        canvas = CanvasLayer.new()
        add_child(canvas)
    weapon_label = Label.new()
    weapon_label.position = Vector2(20, 155)
    weapon_label.add_theme_font_size_override("font_size", 18)
    weapon_label.add_theme_color_override("font_color", Color("f1f3eb"))
    canvas.add_child(weapon_label)
    crosshair = Label.new()
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-10, -18)
    crosshair.size = Vector2(20, 36)
    crosshair.text = "+"
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair.add_theme_font_size_override("font_size", 27)
    crosshair.add_theme_color_override("font_color", Color("fff2d6"))
    canvas.add_child(crosshair)

func _update_aim_visuals() -> void:
    if weapon_root == null:
        return
    var camera_controller := get_node_or_null("ThirdPersonCameraController")
    var aiming := false
    if camera_controller != null:
        aiming = bool(camera_controller.get("aiming"))
    weapon_root.visible = aiming
    if weapon_root.has_node("PistolBody"):
        weapon_root.get_node("PistolBody").visible = selected_weapon == "pistol"
        weapon_root.get_node("PistolGrip").visible = selected_weapon == "pistol"
    for node_name in ["RifleBody", "RifleBarrel", "RifleStock", "RifleSight"]:
        if weapon_root.has_node(node_name):
            weapon_root.get_node(node_name).visible = selected_weapon == "rifle"
    if crosshair != null:
        crosshair.visible = aiming

func _update_weapon_hud() -> void:
    if weapon_label == null:
        return
    var weapon_name := "PISTOLET [1]" if selected_weapon == "pistol" else "KARABIN [2]"
    weapon_label.text = "Broń: %s   Amunicja: %d" % [weapon_name, ammo]

func _build_terrain_details() -> void:
    # Add light procedural scenery while keeping the existing paths and buildings clear.
    var building_areas := [
        Rect2(-16.5, -14.5, 7, 5), Rect2(-6, -17.5, 6, 5),
        Rect2(5, -14.5, 8, 5), Rect2(-17, 9.5, 6, 7),
        Rect2(-3, 10.5, 8, 5), Rect2(10.5, 3.5, 5, 7)
    ]
    var placed := 0
    var tries := 0
    while placed < 34 and tries < 260:
        tries += 1
        var position := Vector3(terrain_rng.randf_range(-22.0, 22.0), 0.0, terrain_rng.randf_range(-22.0, 22.0))
        if _is_in_building_area(position, building_areas):
            continue
        if _flat_distance(position, PLAYER_START) < 4.0 or _flat_distance(position, EXIT_POSITION) < 4.0:
            continue
        if terrain_rng.randf() < 0.58:
            _create_tree(position, terrain_rng.randf_range(0.8, 1.25))
        else:
            _create_rock(position, terrain_rng.randf_range(0.65, 1.4))
        placed += 1

    # A broken, low stone trail gives the open ground some shape without blocking movement.
    for index in range(15):
        var z := -5.0 + index * 0.72
        var stone := _create_box(self, "TrailStone", Vector3(1.0, 0.07, 0.55), Vector3(0.0, 0.025, z), Color("555a50"), false)
        stone.rotation.y = terrain_rng.randf_range(-0.12, 0.12)

func _is_in_building_area(position: Vector3, areas: Array) -> bool:
    for area in areas:
        if area.has_point(Vector2(position.x, position.z)):
            return true
    return false

func _create_tree(position: Vector3, scale_value: float) -> void:
    var tree := Node3D.new()
    tree.position = position
    tree.scale = Vector3.ONE * scale_value
    add_child(tree)
    _create_box(tree, "Trunk", Vector3(0.32, 2.4, 0.32), Vector3(0, 1.2, 0), Color("514032"), false)
    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.0
    crown_mesh.height = 1.8
    crown.mesh = crown_mesh
    crown.position = Vector3(0, 2.6, 0)
    crown.scale = Vector3(1.1, 1.25, 1.1)
    crown.material_override = _material(Color("405a3c") if terrain_rng.randf() < 0.5 else Color("536c45"))
    tree.add_child(crown)

func _create_rock(position: Vector3, scale_value: float) -> void:
    var rock := MeshInstance3D.new()
    rock.name = "MossyRock"
    var rock_mesh := SphereMesh.new()
    rock_mesh.radius = 0.65
    rock_mesh.height = 1.0
    rock.mesh = rock_mesh
    rock.position = position + Vector3(0, 0.34 * scale_value, 0)
    rock.scale = Vector3(scale_value * 1.25, scale_value * 0.72, scale_value)
    rock.rotation.y = terrain_rng.randf_range(0.0, TAU)
    rock.material_override = _material(Color("59605a"))
    add_child(rock)
