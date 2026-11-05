extends Node

var player: Node3D
var game_camera: Camera3D
var yaw := 0.0
var pitch := 12.0
var distance := 7.0
var min_pitch := -20.0
var max_pitch := 30.0

func _ready() -> void:
    process_priority = 10
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x * 0.005
        pitch = clamp(pitch - event.relative.y * 0.005, min_pitch, max_pitch)

func _process(_delta: float) -> void:
    if player == null:
        player = get_parent().get_node_or_null("Player") as Node3D
    if game_camera == null:
        game_camera = get_parent().get_node_or_null("GameCamera") as Camera3D
    if player == null or game_camera == null:
        return

    var target := player.global_position + Vector3(0.0, 1.3, 0.0)
    var offset := Vector3(0.0, 0.0, distance)
    offset = offset.rotated(Vector3.UP, yaw)
    offset.y = 3.0 + pitch * 0.15
    game_camera.global_position = target + offset
    game_camera.look_at(target, Vector3.UP)
