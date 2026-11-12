extends CharacterBody3D

var player_id := 1
var speed := 13.0
var turn_speed := 2.8
var gravity := 22.0
var body_mesh: MeshInstance3D

var touches: Dictionary = {}
var touch_buttons: Dictionary = {}

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
        if DisplayServer.is_touchscreen_available():
            _build_touch_ui()

func _build_touch_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var names := {"left": "يسار", "right": "يمين", "gas": "بنزين", "brake": "فرامل"}
    for key in names.keys():
        var rect := ColorRect.new()
        rect.color = Color(1, 1, 1, 0.18)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var label := Label.new()
        label.text = names[key]
        label.set_anchors_preset(Control.PRESET_FULL_RECT)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rect.add_child(label)
        layer.add_child(rect)
        touch_buttons[key] = rect

func _touch_rects() -> Dictionary:
    var size := get_viewport().get_visible_rect().size
    var btn := clampf(size.y * 0.22, 90.0, 180.0)
    var margin := 24.0
    var gap := 20.0
    var bottom := size.y - margin - btn
    return {
        "left": Rect2(margin, bottom, btn, btn),
        "right": Rect2(margin + btn + gap, bottom, btn, btn),
        "gas": Rect2(size.x - margin - btn, bottom - btn - gap, btn, btn),
        "brake": Rect2(size.x - margin - btn, bottom, btn, btn),
    }

func _touch_down(rect: Rect2) -> bool:
    for p in touches.values():
        if rect.has_point(p):
            return true
    return false

func _input(event: InputEvent) -> void:
    if not is_multiplayer_authority():
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
        else:
            touches.erase(event.index)
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position

func _process(_delta: float) -> void:
    if touch_buttons.is_empty():
        return
    var rects := _touch_rects()
    for key in touch_buttons.keys():
        var rect: ColorRect = touch_buttons[key]
        var area: Rect2 = rects[key]
        rect.position = area.position
        rect.size = area.size
        rect.color = Color(1, 1, 1, 0.4) if _touch_down(area) else Color(1, 1, 1, 0.18)

func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var steer := Input.get_axis("ui_right", "ui_left")
    var throttle := Input.get_axis("ui_down", "ui_up")
    if Input.is_physical_key_pressed(KEY_A):
        steer += 1.0
    if Input.is_physical_key_pressed(KEY_D):
        steer -= 1.0
    if Input.is_physical_key_pressed(KEY_W):
        throttle += 1.0
    if Input.is_physical_key_pressed(KEY_S):
        throttle -= 1.0
    if not touch_buttons.is_empty():
        var rects := _touch_rects()
        if _touch_down(rects["left"]):
            steer += 1.0
        if _touch_down(rects["right"]):
            steer -= 1.0
        if _touch_down(rects["gas"]):
            throttle += 1.0
        if _touch_down(rects["brake"]):
            throttle -= 1.0
    steer = clampf(steer, -1.0, 1.0)
    throttle = clampf(throttle, -1.0, 1.0)

    rotate_y(steer * turn_speed * delta)
    var forward := -global_transform.basis.z
    velocity.x = lerp(velocity.x, forward.x * throttle * speed, 5.0 * delta)
    velocity.z = lerp(velocity.z, forward.z * throttle * speed, 5.0 * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0
    move_and_slide()
