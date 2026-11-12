extends CharacterBody3D

var player_id := 1
var speed := 13.0
var turn_speed := 2.8
var gravity := 22.0
var body_mesh: MeshInstance3D

func setup(id: int) -> void:
    player_id = id
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.5, 0.65, 2.3)
    mesh_instance.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.from_hsv(fposmod(float(id) * 0.15, 1.0), 0.75, 0.95)
    mesh_instance.material_override = material
    mesh_instance.position.y = 0.35
    add_child(mesh_instance)
    body_mesh = mesh_instance

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.5, 0.65, 2.3)
    collision.shape = shape
    collision.position.y = 0.35
    add_child(collision)

    if is_multiplayer_authority():
        var camera := Camera3D.new()
        camera.position = Vector3(0, 6, 9)
        camera.rotation_degrees = Vector3(-25, 0, 0)
        camera.current = true
        add_child(camera)

func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var steer := Input.get_axis("ui_right", "ui_left")
    var throttle := Input.get_axis("ui_down", "ui_up")
    rotate_y(steer * turn_speed * delta)
    var forward := -global_transform.basis.z
    velocity.x = lerp(velocity.x, forward.x * throttle * speed, 5.0 * delta)
    velocity.z = lerp(velocity.z, forward.z * throttle * speed, 5.0 * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0
    move_and_slide()
