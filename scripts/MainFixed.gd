extends "res://scripts/Main.gd"

# The original script accidentally ran its physics update a second time from _process.
# Leave movement and game updates to Godot's normal physics tick.
func _process(_delta: float) -> void:
    pass

func _move_player(delta: float) -> void:
    # W moves forward relative to the camera; S moves backward.
    var input := Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
    )
    var move_direction := Vector3.ZERO
    if input.length_squared() > 0.0:
        var camera_basis := camera.global_transform.basis
        var forward := -camera_basis.z
        forward.y = 0.0
        forward = forward.normalized()
        var right := camera_basis.x
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
    player.velocity.y = 0.0
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)

    if move_direction.length_squared() > 0.0:
        player.rotation.y = atan2(move_direction.x, move_direction.z)
        if running:
            _make_noise(player.position, 12.0, 0.3)
        elif not crouching:
            _make_noise(player.position, 6.0, 0.2)
