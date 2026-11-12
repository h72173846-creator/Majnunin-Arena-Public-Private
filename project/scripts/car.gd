extends CharacterBody3D

const TYPES := [
    {"name": "الصاروخ", "speed": 16.0, "turn": 3.0, "size": Vector3(1.3, 0.55, 2.0), "ability": "boost", "ability_name": "نيترو", "cd": 6.0},
    {"name": "القفّاز", "speed": 13.0, "turn": 2.8, "size": Vector3(1.5, 0.65, 2.3), "ability": "jump", "ability_name": "قفزة", "cd": 3.0},
    {"name": "الدبابة", "speed": 9.5, "turn": 2.2, "size": Vector3(2.0, 0.9, 2.8), "ability": "dash", "ability_name": "اندفاع", "cd": 8.0},
    {"name": "المنزلق", "speed": 14.0, "turn": 3.4, "size": Vector3(1.4, 0.6, 2.2), "ability": "drift", "ability_name": "انزلاق", "cd": 5.0},
]

var player_id := 1
var type_index := 0
var gravity := 22.0
var body_mesh: MeshInstance3D

var speed := 13.0
var turn_speed := 2.8
var ability := "jump"
var ability_name := ""
var ability_cooldown := 5.0
var jump_force := 11.0
var car_name := ""

var ability_active := 0.0
var cooldown_left := 0.0
var speed_mult := 1.0
var turn_mult := 1.0
var ability_was_pressed := false

var touches: Dictionary = {}
var touch_buttons: Dictionary = {}
var hud_label: Label

func setup(id: int, type_idx: int = -1) -> void:
    player_id = id
    if type_idx < 0:
        type_idx = abs(id) % TYPES.size()
    type_index = type_idx
    var t: Dictionary = TYPES[type_index]
    speed = t["speed"]
    turn_speed = t["turn"]
    ability = t["ability"]
    ability_name = t["ability_name"]
    ability_cooldown = t["cd"]
    car_name = t["name"]
    var size: Vector3 = t["size"]

    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.from_hsv(fposmod(float(id) * 0.15, 1.0), 0.75, 0.95)
    mesh_instance.material_override = material
    mesh_instance.position.y = size.y * 0.5 + 0.02
    add_child(mesh_instance)
    body_mesh = mesh_instance

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position.y = size.y * 0.5 + 0.02
    add_child(collision)

    if is_multiplayer_authority():
        var camera := Camera3D.new()
        camera.position = Vector3(0, 6, 9)
        camera.rotation_degrees = Vector3(-25, 0, 0)
        camera.current = true
        add_child(camera)
        _build_hud()
        if DisplayServer.is_touchscreen_available():
            _build_touch_ui()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud_label = Label.new()
    hud_label.position = Vector2(340, 18)
    hud_label.add_theme_font_size_override("font_size", 22)
    layer.add_child(hud_label)

func _build_touch_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var names := {"left": "يسار", "right": "يمين", "gas": "بنزين", "brake": "فرامل", "ability": "قدرة"}
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
        "ability": Rect2(size.x - margin - btn * 2.0 - gap, bottom, btn, btn),
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
    if is_instance_valid(hud_label):
        if cooldown_left > 0.0:
            hud_label.text = "%s — %s: %.1f ث" % [car_name, ability_name, cooldown_left]
        else:
            hud_label.text = "%s — %s: جاهزة" % [car_name, ability_name]
    if touch_buttons.is_empty():
        return
    var rects := _touch_rects()
    for key in touch_buttons.keys():
        var rect: ColorRect = touch_buttons[key]
        var area: Rect2 = rects[key]
        rect.position = area.position
        rect.size = area.size
        rect.color = Color(1, 1, 1, 0.4) if _touch_down(area) else Color(1, 1, 1, 0.18)

func _try_ability() -> void:
    if cooldown_left > 0.0:
        return
    match ability:
        "boost":
            ability_active = 1.5
            speed_mult = 1.8
        "dash":
            ability_active = 0.8
            speed_mult = 2.6
        "drift":
            ability_active = 2.5
            turn_mult = 1.8
        "jump":
            if not is_on_floor():
                return
            velocity.y = jump_force
    cooldown_left = ability_cooldown

func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return

    cooldown_left = maxf(cooldown_left - delta, 0.0)
    if ability_active > 0.0:
        ability_active -= delta
        if ability_active <= 0.0:
            speed_mult = 1.0
            turn_mult = 1.0

    var steer := Input.get_axis("ui_right", "ui_left")
    var throttle := Input.get_axis("ui_down", "ui_up")
    var ability_pressed := Input.is_physical_key_pressed(KEY_SPACE)
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
        if _touch_down(rects["ability"]):
            ability_pressed = true
    steer = clampf(steer, -1.0, 1.0)
    throttle = clampf(throttle, -1.0, 1.0)

    rotate_y(steer * turn_speed * turn_mult * delta)
    var forward := -global_transform.basis.z
    var target_speed := speed * speed_mult
    if ability_active > 0.0 and ability == "dash" and throttle <= 0.0:
        throttle = 1.0
    velocity.x = lerp(velocity.x, forward.x * throttle * target_speed, 5.0 * delta)
    velocity.z = lerp(velocity.z, forward.z * throttle * target_speed, 5.0 * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    if ability_pressed and not ability_was_pressed:
        _try_ability()
    ability_was_pressed = ability_pressed

    move_and_slide()
