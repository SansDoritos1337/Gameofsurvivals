extends "res://scripts/GroundedMain.gd"

const EXPANDED_WORLD_LIMIT := 58.0
const EXPANDED_GROUND_SIZE := 124.0

var options_open := false
var options_panel: PanelContainer
var options_status: Label
var options_sensitivity: HSlider
var options_aim_fov: HSlider
var terrain_random := RandomNumberGenerator.new()
var shadows_enabled := true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    super._ready()
    terrain_random.randomize()
    _expand_ground()
    _build_extended_terrain()
    _create_options_menu()
    var camera_controller := get_node_or_null("ThirdPersonCameraController")
    if camera_controller != null:
        camera_controller.process_mode = Node.PROCESS_MODE_ALWAYS
    _show_toast("Nowa mapa: eksploruj okolice. O otwiera opcje.")

func _process(_delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    if options_open:
        return
    super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_O or (event.keycode == KEY_ESCAPE and options_open):
            _toggle_options()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)

func _move_player(delta: float) -> void:
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
            _make_noise(player.position, 12.0, 0.3)
        elif not crouching:
            _make_noise(player.position, 6.0, 0.2)

func _expand_ground() -> void:
    var ground := get_node_or_null("Ground") as StaticBody3D
    if ground == null:
        return
    var mesh_instance := ground.get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh is BoxMesh:
        (mesh_instance.mesh as BoxMesh).size = Vector3(EXPANDED_GROUND_SIZE, 0.4, EXPANDED_GROUND_SIZE)
    var collision := ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision != null and collision.shape is BoxShape3D:
        (collision.shape as BoxShape3D).size = Vector3(EXPANDED_GROUND_SIZE, 0.4, EXPANDED_GROUND_SIZE)

func _build_extended_terrain() -> void:
    # Sparse woods, boulders and ruined roadside structures make the larger map readable.
    var safe_spots := [Vector3.ZERO, Vector3(18, 0, 17), Vector3(-2, 0, 4), Vector3(-17, 0, -13), Vector3(15, 0, -13), Vector3(11, 0, 14)]
    var placed := 0
    var attempts := 0
    while placed < 82 and attempts < 600:
        attempts += 1
        var point := Vector3(terrain_random.randf_range(-54.0, 54.0), 0.0, terrain_random.randf_range(-54.0, 54.0))
        if absf(point.x) < 25.0 and absf(point.z) < 25.0:
            continue
        var too_close := false
        for safe_point in safe_spots:
            if _flat_distance(point, safe_point) < 8.0:
                too_close = true
                break
        if too_close:
            continue
        if terrain_random.randf() < 0.67:
            _make_map_tree(point, terrain_random.randf_range(0.8, 1.5))
        else:
            _make_map_rock(point, terrain_random.randf_range(0.7, 1.5))
        placed += 1

    _make_road(Vector3(29.0, 0.0, -38.0), Vector3(29.0, 0.0, 39.0), 4.0)
    _make_cabin(Vector3(38.0, 0.0, -31.0))
    _make_radio_site(Vector3(-39.0, 0.0, 34.0))
    _make_campfire(Vector3(35.0, 0.0, 31.0))
    _make_boundary_markers()

func _make_map_tree(point: Vector3, size: float) -> void:
    var tree := StaticBody3D.new()
    tree.name = "MapTree"
    tree.position = point
    tree.scale = Vector3.ONE * size
    add_child(tree)
    _create_box(tree, "Trunk", Vector3(0.42, 2.8, 0.42), Vector3(0, 1.4, 0), Color("514032"), true)
    var crown := _create_sphere(tree, "Crown", 1.25, Vector3(0, 3.1, 0), Color("405a3c") if terrain_random.randf() < 0.5 else Color("536c45"))
    crown.scale = Vector3(1.0, 1.25, 1.0)

func _make_map_rock(point: Vector3, size: float) -> void:
    var rock_body := StaticBody3D.new()
    rock_body.name = "MapBoulder"
    rock_body.position = point + Vector3(0, 0.35 * size, 0)
    rock_body.rotation.y = terrain_random.randf_range(0.0, TAU)
    add_child(rock_body)
    var rock := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.75
    sphere.height = 1.1
    rock.mesh = sphere
    rock.scale = Vector3(size * 1.35, size * 0.8, size)
    rock.material_override = _material(Color("59605a"))
    rock_body.add_child(rock)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.72 * size
    collision.shape = shape
    rock_body.add_child(collision)

func _make_road(start: Vector3, finish: Vector3, width: float) -> void:
    var middle := (start + finish) * 0.5
    var length := start.distance_to(finish)
    var road := _create_box(self, "DirtRoad", Vector3(width, 0.035, length), middle + Vector3(0, 0.012, 0), Color("51483a"), false)
    road.rotation.y = atan2(finish.x - start.x, finish.z - start.z)
    for index in range(19):
        var progress := float(index) / 18.0
        var point := start.lerp(finish, progress)
        var marker := _create_box(self, "RoadMarker", Vector3(0.12, 0.045, 1.25), point + Vector3(0, 0.04, 0), Color("a59870"), false)
        marker.rotation.y = road.rotation.y

func _make_cabin(point: Vector3) -> void:
    var cabin := StaticBody3D.new()
    cabin.name = "ForestCabin"
    cabin.position = point
    add_child(cabin)
    _create_box(cabin, "CabinWalls", Vector3(8, 3.4, 7), Vector3(0, 1.7, 0), Color("554638"), true)
    _create_box(cabin, "CabinRoof", Vector3(9, 0.35, 8), Vector3(0, 3.55, 0), Color("343a37"), false)
    _create_box(cabin, "Door", Vector3(1.2, 2.3, 0.16), Vector3(0, 1.15, 3.58), Color("302820"), false)
    _create_box(cabin, "WindowLeft", Vector3(1.2, 0.9, 0.12), Vector3(-2.2, 2.0, 3.57), Color("8a7952"), false)
    _create_box(cabin, "WindowRight", Vector3(1.2, 0.9, 0.12), Vector3(2.2, 2.0, 3.57), Color("8a7952"), false)
    var sign := Label3D.new()
    sign.text = "LEŚNA CHATKA"
    sign.position = Vector3(0, 4.3, 0)
    sign.font_size = 24
    sign.modulate = Color("f1d89d")
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    cabin.add_child(sign)

func _make_radio_site(point: Vector3) -> void:
    _create_box(self, "RadioBase", Vector3(5, 0.3, 5), point + Vector3(0, 0.15, 0), Color("555a54"), false)
    _create_box(self, "RadioTower", Vector3(0.22, 10, 0.22), point + Vector3(0, 5.2, 0), Color("55514a"), false)
    for y in [2.5, 5.0, 7.5]:
        _create_box(self, "RadioCrossbar", Vector3(2.5, 0.12, 0.12), point + Vector3(0, y, 0), Color("746a56"), false)
    var beacon := OmniLight3D.new()
    beacon.position = point + Vector3(0, 10.4, 0)
    beacon.light_color = Color("ff534d")
    beacon.light_energy = 1.8
    beacon.omni_range = 9.0
    add_child(beacon)
    _create_sphere(self, "RadioBeacon", 0.25, beacon.position, Color("ff514c"))
    var label := Label3D.new()
    label.text = "STACJA RADIOWA"
    label.position = point + Vector3(0, 11.0, 0)
    label.font_size = 26
    label.modulate = Color("f3d9ae")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func _make_campfire(point: Vector3) -> void:
    _create_sphere(self, "CampfireCoal", 0.65, point + Vector3(0, 0.18, 0), Color("302b27"))
    var fire := OmniLight3D.new()
    fire.position = point + Vector3(0, 0.8, 0)
    fire.light_color = Color("ff8c43")
    fire.light_energy = 1.7
    fire.omni_range = 12.0
    add_child(fire)
    for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
        var log := _create_box(self, "CampfireLog", Vector3(0.18, 0.18, 1.1), point + Vector3(0, 0.16, 0), Color("4d382a"), false)
        log.rotation.y = angle
    _create_sphere(self, "CampfireFlame", 0.38, point + Vector3(0, 0.72, 0), Color("ff8a36"))

func _make_boundary_markers() -> void:
    for point in [Vector3(-56, 0, 0), Vector3(56, 0, 0), Vector3(0, 0, -56), Vector3(0, 0, 56)]:
        _create_box(self, "BoundaryBeacon", Vector3(0.45, 3.0, 0.45), point + Vector3(0, 1.5, 0), Color("d0a65e"), false)

func _create_options_menu() -> void:
    var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
    if canvas == null:
        canvas = CanvasLayer.new()
        add_child(canvas)
    options_panel = PanelContainer.new()
    options_panel.name = "OptionsPanel"
    options_panel.set_anchors_preset(Control.PRESET_CENTER)
    options_panel.position = Vector2(-210, -160)
    options_panel.size = Vector2(420, 320)
    options_panel.visible = false
    options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    canvas.add_child(options_panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    options_panel.add_child(layout)
    var title := Label.new()
    title.text = "USTAWIENIA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    layout.add_child(title)

    var sensitivity_text := Label.new()
    sensitivity_text.text = "Czułość obracania kamery"
    layout.add_child(sensitivity_text)
    options_sensitivity = HSlider.new()
    options_sensitivity.min_value = 0.001
    options_sensitivity.max_value = 0.012
    options_sensitivity.step = 0.001
    options_sensitivity.value = 0.005
    options_sensitivity.value_changed.connect(_on_sensitivity_changed)
    layout.add_child(options_sensitivity)

    var zoom_text := Label.new()
    zoom_text.text = "Powiększenie celowania"
    layout.add_child(zoom_text)
    options_aim_fov = HSlider.new()
    options_aim_fov.min_value = 30.0
    options_aim_fov.max_value = 55.0
    options_aim_fov.step = 1.0
    options_aim_fov.value = 42.0
    options_aim_fov.value_changed.connect(_on_aim_fov_changed)
    layout.add_child(options_aim_fov)

    var shadow_button := Button.new()
    shadow_button.text = "Przełącz cienie"
    shadow_button.pressed.connect(_toggle_shadows)
    layout.add_child(shadow_button)
    options_status = Label.new()
    options_status.text = "O: zamknij opcje | PPM: obrót | kółko myszy: widok 1. osoby"
    options_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(options_status)
    var close_button := Button.new()
    close_button.text = "Wróć do gry"
    close_button.pressed.connect(_toggle_options)
    layout.add_child(close_button)

func _toggle_options() -> void:
    options_open = not options_open
    if options_panel != null:
        options_panel.visible = options_open
    get_tree().paused = options_open
    if options_open:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_sensitivity_changed(value: float) -> void:
    var camera_controller := get_node_or_null("ThirdPersonCameraController")
    if camera_controller != null:
        camera_controller.set("look_sensitivity", value)

func _on_aim_fov_changed(value: float) -> void:
    var camera_controller := get_node_or_null("ThirdPersonCameraController")
    if camera_controller != null:
        camera_controller.set("aim_fov", value)

func _toggle_shadows() -> void:
    shadows_enabled = not shadows_enabled
    for child in get_children():
        if child is DirectionalLight3D:
            (child as DirectionalLight3D).shadow_enabled = shadows_enabled
    if options_status != null:
        options_status.text = "Cienie: %s | O: zamknij | PPM: obrót | kółko myszy: 1. osoba" % ("włączone" if shadows_enabled else "wyłączone")
