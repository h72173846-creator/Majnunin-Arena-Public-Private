extends Node3D

const PORT := 24567
const MAX_PLAYERS := 6
const CarScript = preload("res://scripts/car.gd")

var cars: Dictionary = {}
var players: Array = [1]
var selected_map := "الساحة الأساسية"
var status_label: Label
var ip_input: LineEdit
var map_select: OptionButton
var lobby_panel: VBoxContainer
var arena_root: Node3D

func _ready() -> void:
    _build_ui()
    _create_arena(selected_map)
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(func(): _set_status("اتصلت بالمضيف!"))
    multiplayer.connection_failed.connect(func(): _set_status("فشل الاتصال. تأكد من عنوان IP ونفس شبكة Hotspot."))
    multiplayer.server_disconnected.connect(func(): _set_status("انقطع اتصال المضيف."))

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(300, 0)
    layer.add_child(panel)
    lobby_panel = VBoxContainer.new()
    panel.add_child(lobby_panel)

    var title := Label.new()
    title.text = "مجنونين الساحة — نسخة 0.1"
    title.add_theme_font_size_override("font_size", 22)
    lobby_panel.add_child(title)

    var maps_label := Label.new()
    maps_label.text = "اختار الماب (يدوي فقط):"
    lobby_panel.add_child(maps_label)
    map_select = OptionButton.new()
    for map_name in ["الساحة الأساسية", "الصحراء", "المصنع"]:
        map_select.add_item(map_name)
    map_select.item_selected.connect(_on_map_selected)
    lobby_panel.add_child(map_select)

    var host_btn := Button.new()
    host_btn.text = "إنشاء غرفة (مضيف)"
    host_btn.pressed.connect(_host_game)
    lobby_panel.add_child(host_btn)

    ip_input = LineEdit.new()
    ip_input.placeholder_text = "IP جهاز المضيف"
    lobby_panel.add_child(ip_input)

    var join_btn := Button.new()
    join_btn.text = "انضمام للغرفة"
    join_btn.pressed.connect(_join_game)
    lobby_panel.add_child(join_btn)

    status_label = Label.new()
    status_label.text = "استضيف من جهاز واحد، والباقي يدخلون IP المضيف."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lobby_panel.add_child(status_label)

    var help := Label.new()
    help.text = "نسخة أولية: قيادة + غرفة LAN + اختيار ماب يدوي. شغّلوا الأجهزة على نفس Hotspot."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lobby_panel.add_child(help)

func _set_status(value: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = value

func _is_client() -> bool:
    return multiplayer.multiplayer_peer != null and not multiplayer.is_server()

func _on_map_selected(index: int) -> void:
    if _is_client():
        return
    selected_map = map_select.get_item_text(index)
    _create_arena(selected_map)
    if multiplayer.multiplayer_peer != null:
        _rpc_set_map.rpc(selected_map)

@rpc("authority", "call_remote", "reliable")
func _rpc_set_map(map_name: String) -> void:
    selected_map = map_name
    for i in range(map_select.item_count):
        if map_select.get_item_text(i) == map_name:
            map_select.select(i)
    _create_arena(map_name)

func _create_arena(map_name: String) -> void:
    cars.clear()
    if is_instance_valid(arena_root):
        remove_child(arena_root)
        arena_root.queue_free()
    arena_root = Node3D.new()
    arena_root.name = "Arena"
    add_child(arena_root)

    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.10, 0.15, 0.22)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.7, 0.75, 0.85)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    arena_root.add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.2
    arena_root.add_child(sun)

    var ground := StaticBody3D.new()
    arena_root.add_child(ground)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(34, 1, 34)
    mesh.mesh = box
    mesh.position.y = -0.5
    ground.add_child(mesh)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = box.size
    shape.shape = box_shape
    shape.position.y = -0.5
    ground.add_child(shape)

    var material := StandardMaterial3D.new()
    material.albedo_color = _map_color(map_name)
    mesh.material_override = material

    for i in range(4):
        var wall := StaticBody3D.new()
        arena_root.add_child(wall)
        var wall_mesh := MeshInstance3D.new()
        var wall_box := BoxMesh.new()
        wall_box.size = Vector3(34, 2, 0.6) if i < 2 else Vector3(0.6, 2, 34)
        wall_mesh.mesh = wall_box
        wall_mesh.position = Vector3(0, 1, -17 if i == 0 else 17) if i < 2 else Vector3(-17 if i == 2 else 17, 1, 0)
        wall.add_child(wall_mesh)
        var wall_shape := CollisionShape3D.new()
        var collision := BoxShape3D.new()
        collision.size = wall_box.size
        wall_shape.shape = collision
        wall_shape.position = wall_mesh.position
        wall.add_child(wall_shape)

    for id in players:
        _spawn_player(id)

func _map_color(map_name: String) -> Color:
    match map_name:
        "الصحراء": return Color(0.65, 0.43, 0.20)
        "المصنع": return Color(0.25, 0.38, 0.42)
        _: return Color(0.20, 0.42, 0.30)

func _host_game() -> void:
    if multiplayer.multiplayer_peer != null:
        _set_status("أنت داخل غرفة بالفعل.")
        return
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, MAX_PLAYERS - 1)
    if error != OK:
        _set_status("تعذر إنشاء الغرفة: %s" % error)
        return
    multiplayer.multiplayer_peer = peer
    players = [1]
    _create_arena(selected_map)
    _set_status("أنت المضيف. أعطِ اللاعبين IP جهازك.")

func _join_game() -> void:
    if multiplayer.multiplayer_peer != null:
        _set_status("أنت داخل غرفة بالفعل.")
        return
    var address := ip_input.text.strip_edges()
    if address.is_empty():
        _set_status("اكتب IP جهاز المضيف أولًا.")
        return
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, PORT)
    if error != OK:
        _set_status("تعذر بدء الاتصال: %s" % error)
        return
    multiplayer.multiplayer_peer = peer
    players.clear()
    map_select.disabled = true
    _create_arena(selected_map)
    _set_status("جارٍ الاتصال بالمضيف...")

func _on_peer_connected(id: int) -> void:
    if not multiplayer.is_server():
        return
    # عرّف اللاعب الجديد بكل اللاعبين الموجودين + نفسه
    for existing in players:
        _rpc_spawn_player.rpc_id(id, existing)
    _rpc_spawn_player.rpc_id(id, id)
    _rpc_set_map.rpc_id(id, selected_map)
    _add_player(id)
    # عرّف باقي اللاعبين بالجديد
    for p in multiplayer.get_peers():
        if p != id:
            _rpc_spawn_player.rpc_id(p, id)

func _on_peer_disconnected(id: int) -> void:
    players.erase(id)
    if cars.has(id):
        cars[id].queue_free()
        cars.erase(id)

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(id: int) -> void:
    _add_player(id)

func _add_player(id: int) -> void:
    if not players.has(id):
        players.append(id)
    _spawn_player(id)

func _spawn_player(id: int) -> void:
    if cars.has(id) or not is_instance_valid(arena_root):
        return
    var idx := players.find(id)
    if idx < 0:
        idx = 0
    var car := CharacterBody3D.new()
    car.name = "Player_%s" % id
    car.set_script(CarScript)
    car.set_multiplayer_authority(id)
    arena_root.add_child(car)
    car.position = Vector3(float(idx % 4) * 4.0 - 6.0, 0.7, floorf(idx / 4.0) * 5.0 - 5.0)
    car.setup(id)
    cars[id] = car

func _process(_delta: float) -> void:
    if multiplayer.multiplayer_peer == null:
        return
    var my_id := multiplayer.get_unique_id()
    if cars.has(my_id):
        _rpc_car_state.rpc(my_id, cars[my_id].global_position, cars[my_id].rotation.y)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_car_state(id: int, pos: Vector3, rot_y: float) -> void:
    if multiplayer.get_remote_sender_id() != id:
        return
    if cars.has(id) and not cars[id].is_multiplayer_authority():
        cars[id].global_position = cars[id].global_position.lerp(pos, 0.5)
        cars[id].rotation.y = rot_y
