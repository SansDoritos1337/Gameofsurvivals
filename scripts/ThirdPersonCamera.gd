extends Node

var player: Node3D
var game_camera: Camera3D
var yaw := 0.0
var pitch := 12.0
var distance := 7.0
var min_pitch := -20.0
var max_pitch := 30.0
var rotating := false
var aiming := false
var default_fov := 55.0
var aim_fov := 42.0

func _ready() -> void:
    process_priority = 10
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        rotating = event.pressed
        aiming = event.pressed
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and rotating:
        yaw -= event.relative.x * 0.005
        pitch = clampf(pitch - event.relative.y * 0.005, min_pitch, max_pitch)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        rotating = false
        aiming = false

func _process(_delta: float) -> void:
    if player == null:
        player = get_parent().get_node_or_null("Player") as Node3D
    if game_camera == null:
        game_camera = get_parent().get_node_or_null("GameCamera") as Camera3D
    if player == null or game_camera == null:
        return

    var target := player.global_position + Vector3(0.0, 1.3, 0.0)
    if aiming:
        # Right mouse aims in first person and narrows the field of view for zoom.
        game_camera.global_position = player.global_position + Vector3(0.0, 1.58, 0.0)
        var look_direction := Vector3(-sin(yaw), sin(deg_to_rad(pitch)), -cos(yaw))
        game_camera.look_at(game_camera.global_position + look_direction, Vector3.UP)
        game_camera.fov = aim_fov
    else:
        var offset := Vector3(0.0, 0.0, distance).rotated(Vector3.UP, yaw)
        offset.y = 3.0 + pitch * 0.15
        game_camera.global_position = target + offset
        game_camera.look_at(target, Vector3.UP)
        game_camera.fov = default_fov
