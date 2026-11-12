extends Node
class_name ShotUtil

var audit_notes: Array[String] = []


static func enabled() -> bool:
	return OS.get_cmdline_user_args().has("--shots")


static func directory() -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--shots")
	if index >= 0 and index + 1 < args.size():
		return str(args[index + 1])
	return "/tmp/srdld-shots"


func capture(host: Node, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	var dir := directory()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("%s.png" % shot_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func find_button(root: Node, ui_id: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and str(node.get_meta("ui_id", "")) == ui_id and node.is_visible_in_tree() and not node.disabled:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func find_any(root: Node, ui_id: String) -> Control:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control and str(node.get_meta("ui_id", "")) == ui_id:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func click(host: Node, ui_id: String) -> bool:
	var button := find_button(get_tree().root, ui_id)
	if button == null:
		button = find_button(host, ui_id)
	if button == null:
		print("CLICK missing %s" % ui_id)
		return false
	var rect := button.get_global_rect()
	var point := rect.position + rect.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	host.get_viewport().push_input(press)
	await get_tree().process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	host.get_viewport().push_input(release)
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func audit(root: Node) -> bool:
	audit_notes.clear()
	var viewport := root.get_viewport().get_visible_rect()
	var ok := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree():
			var button := node as Button
			var rect := button.get_global_rect()
			var in_scroll := _inside_scroll(button)
			if not in_scroll:
				if rect.size.y < 44.0 or rect.size.x < 72.0:
					ok = false
					audit_notes.append("small %s %s" % [button.text, rect.size])
				if not viewport.encloses(rect.grow(-1)):
					ok = false
					audit_notes.append("outside %s %s viewport %s" % [button.text, rect, viewport])
			elif not viewport.intersects(rect) and rect.size.y > 0.0:
				pass
		for child in node.get_children():
			stack.append(child)
	if audit_notes.is_empty():
		audit_notes.append("layout ok")
	var path := directory().path_join("layout_audit.txt")
	DirAccess.make_dir_recursive_absolute(directory())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(audit_notes))
	print("AUDIT %s" % ("ok" if ok else "fail"))
	for note in audit_notes:
		print("AUDIT ", note)
	return ok


func _inside_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false
