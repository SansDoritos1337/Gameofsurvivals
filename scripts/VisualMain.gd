extends "res://scripts/MegaMain.gd"

var graphics_random := RandomNumberGenerator.new()

func _ready() -> void:
    super._ready()
    graphics_random.randomize()
    _apply_visual_settings()
    _improve_ground_material()
    _add_forest_understory()
    _add_landmark_lighting()

func _apply_visual_settings() -> void:
    var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
    if world == null or world.environment == null:
        return
    var env := world.environment
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("9ba89b")
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.08
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 0.92
    env.fog_enabled = true
    env.fog_light_color = Color("a1aa9c")
    env.fog_density = 0.0045
    env.fog_sky_affect = 0.25
    env.glow_enabled = true
    env.glow_intensity = 0.35
    env.glow_strength = 0.55

    for child in get_children():
        if child is DirectionalLight3D:
            var sun := child as DirectionalLight3D
            sun.shadow_enabled = true
            sun.light_color = Color("fff0d6")
            sun.light_energy = 1.15
            sun.directional_shadow_max_distance = 90.0

func _improve_ground_material() -> void:
    var ground := get_node_or_null("Ground") as StaticBody3D
    if ground == null:
        return
    var ground_mesh := ground.get_node_or_null("MeshInstance3D") as MeshInstance3D
    if ground_mesh == null:
        return

    # Procedural noise adds mottled earth/grass variation without external asset files.
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = 0.055
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.52
    var noise_texture := NoiseTexture2D.new()
    noise_texture.noise = noise
    noise_texture.width = 512
    noise_texture.height = 512
    noise_texture.seamless = true

    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color("78806a")
    ground_material.albedo_texture = noise_texture
    ground_material.uv1_scale = Vector3(20.0, 20.0, 20.0)
    ground_material.roughness = 1.0
    ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    ground_mesh.material_override = ground_material

func _add_forest_understory() -> void:
    var foliage_colors := [Color("465b3c"), Color("596c45"), Color("69724a"), Color("52634a")]
    var placed := 0
    var attempts := 0
    while placed < 70 and attempts < 450:
        attempts += 1
        var point := Vector3(graphics_random.randf_range(-53.0, 53.0), 0.0, graphics_random.randf_range(-53.0, 53.0))
        # Leave the central play area, important objectives and paths readable.
        if absf(point.x) < 24.0 and absf(point.z) < 24.0:
            continue
        if _flat_distance(point, Vector3(29.0, 0.0, 0.0)) < 6.0:
            continue
        var shrub := Node3D.new()
        shrub.name = "ForestShrub"
        shrub.position = point
        shrub.rotation.y = graphics_random.randf_range(0.0, TAU)
        add_child(shrub)
        for leaf_index in range(3):
            var leaf := MeshInstance3D.new()
            var leaf_mesh := SphereMesh.new()
            leaf_mesh.radius = graphics_random.randf_range(0.35, 0.62)
            leaf_mesh.height = leaf_mesh.radius * 1.5
            leaf.mesh = leaf_mesh
            leaf.position = Vector3(graphics_random.randf_range(-0.45, 0.45), graphics_random.randf_range(0.3, 0.62), graphics_random.randf_range(-0.4, 0.4))
            leaf.scale = Vector3(1.0, 0.72, 1.0)
            leaf.material_override = _material(foliage_colors[graphics_random.randi_range(0, foliage_colors.size() - 1)])
            shrub.add_child(leaf)
        placed += 1

func _add_landmark_lighting() -> void:
    _add_warm_light(Vector3(38.0, 2.8, -31.0), Color("ffd18a"), 1.1, 13.0)
    _add_warm_light(Vector3(35.0, 1.0, 31.0), Color("ff8c43"), 1.5, 15.0)
    _add_warm_light(Vector3(-39.0, 4.0, 34.0), Color("ff5d52"), 0.9, 10.0)

func _add_warm_light(point: Vector3, color: Color, energy: float, light_range: float) -> void:
    var light := OmniLight3D.new()
    light.position = point
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = false
    add_child(light)
