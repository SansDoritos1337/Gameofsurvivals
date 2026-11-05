extends "res://scripts/Main.gd"

const RESCUE_DISTANCE := 2.4
const PICKUP_DISTANCE := 2.0
const DAY_LENGTH := 180.0

var rescue_targets: Array[Node3D] = []
var rescued_followers: Array[Node3D] = []
var campaign_pickups: Array[Dictionary] = []
var rescued_count := 0
var wave_number := 0
var next_wave_time := 55.0
var interact_was_down := false
var directional_sun: DirectionalLight3D
var world_environment: WorldEnvironment
var mission_label: Label
var pickup_cooldown := 0.0

func _ready() -> void:
    super._ready()
    directional_sun = _find_sun()
    var environment_node := get_node_or_null("WorldEnvironment")
    if environment_node is WorldEnvironment:
        world_environment = environment_node
    _setup_rescue_mission()
    _setup_campaign_pickups()
    _setup_lighting()
    _create_mission_hud()

# Main.gd used to call _physics_process from both callbacks. This override makes the
# inherited survival/game update run exactly once per physics frame.
func _process(_delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if game_over or extracted:
        return

    pickup_cooldown = maxf(0.0, pickup_cooldown - delta)
    _update_rescue_followers(delta)
    _update_campaign_interaction()
    _update_campaign_waves()
    _update_day_night()
    _update_mission_hud()

func _find_sun() -> DirectionalLight3D:
    for child in get_children():
        if child is DirectionalLight3D:
            return child as DirectionalLight3D
    return null

func _setup_rescue_mission() -> void:
    # Turn the original nearby survivor into the first rescue objective.
    var first_survivor := get_node_or_null("Ocalały") as Node3D
    if first_survivor != null:
        first_survivor.set_meta("rescued", false)
        rescue_targets.append(first_survivor)
        var first_tag := first_survivor.get_node_or_null("Label3D") as Label3D
        if first_tag != null:
            first_tag.text = "OCALAŁY — E: URATUJ"

    _spawn_rescue_survivor(Vector3(7.0, 0.0, 3.0), Color("557e62"), "OCALAŁY 2")
    _spawn_rescue_survivor(Vector3(-8.0, 0.0, 2.0), Color("766b9c"), "OCALAŁY 3")

func _spawn_rescue_survivor(position: Vector3, shirt_color: Color, display_name: String) -> void:
    var survivor := Node3D.new()
    survivor.name = "RescueTarget%d" % rescue_targets.size()
    survivor.position = position
    survivor.set_meta("rescued", false)
    add_child(survivor)
    _create_human_model(survivor, shirt_color, Color("d9b08a"), Color("30221c"), Color("f5f4ee"), false)
    var tag := Label3D.new()
    tag.name = "RescueLabel"
    tag.text = display_name + " — E: URATUJ"
    tag.position = Vector3(0, 2.3, 0)
    tag.font_size = 24
    tag.modulate = Color("fff0c4")
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    survivor.add_child(tag)
    rescue_targets.append(survivor)

func _setup_campaign_pickups() -> void:
    _spawn_campaign_pickup(Vector3(8.0, 0.0, -3.0), "medkit", "APTECZKA", Color("bd554b"))
    _spawn_campaign_pickup(Vector3(-9.0, 0.0, -8.0), "ammo", "AMUNICJA", Color("d2ad54"))
    _spawn_campaign_pickup(Vector3(3.0, 0.0, 8.0), "medkit", "APTECZKA", Color("bd554b"))
    _spawn_campaign_pickup(Vector3(16.0, 0.0, -4.0), "ammo", "AMUNICJA", Color("d2ad54"))
    _spawn_campaign_pickup(Vector3(-18.0, 0.0, 5.0), "supplies", "ZAPASY", Color("718b61"))

func _spawn_campaign_pickup(position: Vector3, kind: String, title: String, color: Color) -> void:
    var pickup := Node3D.new()
    pickup.name = "Pickup_" + kind
    pickup.position = position
    add_child(pickup)
    _create_box(pickup, "Crate", Vector3(0.8, 0.65, 0.8), Vector3(0, 0.38, 0), color, false)
    var marker := _create_box(pickup, "Marker", Vector3(0.18, 0.18, 0.84), Vector3(0, 0.38, 0), Color("eee7ce"), false)
    marker.rotation.y = PI / 4.0
    var tag := Label3D.new()
    tag.text = title
    tag.position = Vector3(0, 1.15, 0)
    tag.font_size = 20
    tag.modulate = Color("fff1c8")
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    pickup.add_child(tag)
    campaign_pickups.append({"node": pickup, "kind": kind, "taken": false})

func _create_mission_hud() -> void:
    var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
    if canvas == null:
        canvas = CanvasLayer.new()
        add_child(canvas)
    mission_label = Label.new()
    mission_label.position = Vector2(20, 102)
    mission_label.add_theme_font_size_override("font_size", 18)
    mission_label.add_theme_color_override("font_color", Color("ffe7a7"))
    mission_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    mission_label.add_theme_constant_override("shadow_offset_x", 2)
    mission_label.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(mission_label)

func _update_campaign_interaction() -> void:
    var pressed := Input.is_key_pressed(KEY_E)
    if pressed and not interact_was_down:
        if not _try_rescue_nearest():
            _try_pickup_nearest()
    interact_was_down = pressed

func _try_rescue_nearest() -> bool:
    var nearest: Node3D = null
    var nearest_distance := RESCUE_DISTANCE
    for survivor in rescue_targets:
        if not is_instance_valid(survivor) or bool(survivor.get_meta("rescued", false)):
            continue
        var distance := _flat_distance(player.global_position, survivor.global_position)
        if distance < nearest_distance:
            nearest = survivor
            nearest_distance = distance
    if nearest == null:
        return false

    nearest.set_meta("rescued", true)
    rescued_count += 1
    rescued_followers.append(nearest)
    var tag := nearest.get_node_or_null("RescueLabel") as Label3D
    if tag != null:
        tag.text = "URATOWANY"
        tag.modulate = Color("a9f0b0")
    else:
        var original_tag := nearest.get_node_or_null("Label3D") as Label3D
        if original_tag != null:
            original_tag.text = "URATOWANY"
            original_tag.modulate = Color("a9f0b0")
    _show_toast("Uratowano ocalałego! (%d/3). Podąża za tobą." % rescued_count)
    return true

func _try_pickup_nearest() -> void:
    if pickup_cooldown > 0.0:
        return
    var nearest_index := -1
    var nearest_distance := PICKUP_DISTANCE
    for index in range(campaign_pickups.size()):
        var pickup: Dictionary = campaign_pickups[index]
        if bool(pickup["taken"]):
            continue
        var node := pickup["node"] as Node3D
        if not is_instance_valid(node):
            continue
        var distance := _flat_distance(player.global_position, node.global_position)
        if distance < nearest_distance:
            nearest_index = index
            nearest_distance = distance
    if nearest_index < 0:
        return

    var pickup: Dictionary = campaign_pickups[nearest_index]
    pickup["taken"] = true
    var pickup_node := pickup["node"] as Node3D
    if is_instance_valid(pickup_node):
        pickup_node.queue_free()
    match String(pickup["kind"]):
        "medkit":
            var old_health := player_health
            player_health = mini(100, player_health + 35)
            _show_toast("Apteczka: +%d HP." % (player_health - old_health))
        "ammo":
            ammo += 8
            _show_toast("Zebrano amunicję: +8 naboi.")
        "supplies":
            loot += 2
            _show_toast("Zebrano zapasy: +2 łupu.")
    pickup_cooldown = 0.45

func _update_rescue_followers(delta: float) -> void:
    for index in range(rescued_followers.size()):
        var follower := rescued_followers[index] as Node3D
        if not is_instance_valid(follower):
            continue
        var side := -1.0 if index % 2 == 0 else 1.0
        var row := float(index / 2)
        var local_offset := Vector3(side * 1.3, 0.0, 2.2 + row * 1.2)
        var target_position: Vector3 = player.global_position + player.global_transform.basis * local_offset
        target_position.y = 0.0
        follower.global_position = follower.global_position.lerp(target_position, minf(delta * 2.8, 1.0))
        var direction := player.global_position - follower.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.05:
            follower.rotation.y = atan2(direction.x, direction.z)
        _animate_character(follower, follower.global_position.distance_to(target_position) > 0.25)

func _update_campaign_waves() -> void:
    if elapsed < next_wave_time or wave_number >= 4:
        return
    wave_number += 1
    next_wave_time += 50.0
    var spawn_points := [Vector3(-21, 0, -20), Vector3(21, 0, -18), Vector3(-20, 0, 20), Vector3(20, 0, 20)]
    var count := 1 if wave_number == 4 else 2
    for index in range(count):
        var spawn_position: Vector3 = spawn_points[(wave_number + index) % spawn_points.size()]
        _spawn_enemy(spawn_position)
        if wave_number == 4 and not enemies.is_empty():
            var boss: CharacterBody3D = enemies[enemies.size() - 1]["node"]
            if is_instance_valid(boss):
                boss.scale = Vector3(1.45, 1.45, 1.45)
                enemies[enemies.size() - 1]["speed"] = 3.2
    _show_toast("Nadciąga fala potworów #%d!" % wave_number)

func _setup_lighting() -> void:
    var lamp_positions := [Vector3(-8, 0, -2), Vector3(7, 0, 1), Vector3(0, 0, 7), Vector3(16, 0, 4), Vector3(-17, 0, 8)]
    for lamp_position in lamp_positions:
        _create_lamp(lamp_position)

func _create_lamp(position: Vector3) -> void:
    _create_box(self, "StreetLampPole", Vector3(0.16, 3.0, 0.16), position + Vector3(0, 1.5, 0), Color("343b39"), false)
    _create_sphere(self, "StreetLampGlow", 0.22, position + Vector3(0, 3.05, 0), Color("f4d58b"))
    var light := OmniLight3D.new()
    light.position = position + Vector3(0, 2.9, 0)
    light.light_color = Color("ffd995")
    light.light_energy = 0.7
    light.omni_range = 7.0
    add_child(light)

func _update_day_night() -> void:
    if directional_sun == null:
        return
    var phase := fposmod(elapsed, DAY_LENGTH) / DAY_LENGTH
    var daylight := 0.5 + 0.5 * cos(phase * TAU)
    directional_sun.light_energy = 0.12 + daylight * 1.08
    if world_environment != null and world_environment.environment != null:
        world_environment.environment.ambient_light_energy = 0.12 + daylight * 0.45
        world_environment.environment.ambient_light_color = Color("667384").lerp(Color("9ba9a5"), daylight)

func _update_mission_hud() -> void:
    if mission_label == null:
        return
    var exit_status := "otwarte" if extract_open else "zablokowane"
    var time_left := maxi(0, int(ceil(next_wave_time - elapsed)))
    mission_label.text = "MISJA: uratuj ocalałych %d/3\nWyjście: %s (otwiera się po 35 s i uratowaniu wszystkich)\nFale potworów: %d/4 — następna za %d s\nE: ratuj ocalałych / zbieraj apteczki i amunicję" % [rescued_count, exit_status, wave_number, time_left]

