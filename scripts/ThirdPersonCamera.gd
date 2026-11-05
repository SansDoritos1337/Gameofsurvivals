extends Node

var player: Node3D
var game_camera: Camera3D

func _ready() -> void:
    process_priority = 10

func _process(_delta: float) -> void:
    if player == null:
        player = get_parent().get_node_or_null("Player") as Node3D
    if game_camera == null:
        game_camera = get_parent().get_node_or_null("GameCamera") as Camera3D
    if player == null or game_camera == null:
        return

    # Kamera trzecioosobowa: blisko za postacią, patrzy na jej górną część.
    game_camera.global_position = player.global_position + Vector3(0.0, 4.2, 6.0)
    game_camera.look_at(player.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
