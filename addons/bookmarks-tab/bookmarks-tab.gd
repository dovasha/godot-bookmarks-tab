@tool
extends EditorPlugin

# Constants
const BOOKMARK_ICON: Texture2D = preload("res://addons/bookmarks-tab/bookmark.svg")
const METHOD_ICON: Texture2D = preload("res://addons/bookmarks-tab/method.svg")
const BOOKMARKS_POLLING_RATE: float = 0.3

# Editor references
var script_editor: ScriptEditor
var side_panel: VSplitContainer
var methods_panel: VBoxContainer
var code_editor: CodeEdit

# Custom layout
var final_layout := VSplitContainer.new()
var bookmarks_panel := VBoxContainer.new()
var bookmarks_list := ItemList.new()

var prev_bookmarks: Array = []


# Built-ins
func _enter_tree() -> void:
	script_editor = EditorInterface.get_script_editor()
	script_editor.connect(&"editor_script_changed", _on_script_changed)
	await script_editor.visible

	_setup_side_panel()
	_setup_bookmarks_panel()
	_on_script_changed()


func _exit_tree() -> void:
	script_editor.disconnect(&"editor_script_changed", _on_script_changed)
	
	# Restore original layout
	methods_panel.get_parent().remove_child(methods_panel)
	final_layout.queue_free()
	side_panel.add_child(methods_panel)


# Bookmarks logic
func _refresh_bookmarks() -> void:
	if not is_instance_valid(code_editor):
		return

	var bookmarks: Array = code_editor.get_bookmarked_lines()

	if (bookmarks.size() == prev_bookmarks.size()
	and bookmarks.all(func(ix): return ix in prev_bookmarks)):
		return # Skip if identical to current list
	
	# Change found, refresh list
	prev_bookmarks = bookmarks.duplicate()
	bookmarks_list.clear()

	for index in bookmarks.size():
		var line_number: int = bookmarks[index]
		var text: String = code_editor.get_line(line_number)

		bookmarks_list.add_item("%d - %s" % [line_number + 1, text])
		bookmarks_list.set_item_tooltip(index, text)
		bookmarks_list.set_item_metadata(index, line_number)


# Events
func _on_script_changed(_script: Script = null) -> void:
	var editor := script_editor.get_current_editor()
	code_editor = editor.get_base_editor() if editor else null
	_refresh_bookmarks()


func _on_bookmark_selected(index: int) -> void:
	var line_number: int = bookmarks_list.get_item_metadata(index)
	script_editor.goto_line(line_number)


# Setup
func _setup_side_panel() -> void:
	# Find ScriptEditor's side panel, which is the first 'VSplitContainer'
	side_panel = script_editor.find_children("", "VSplitContainer", true, false)[0]

	# Keep a reference to the built-in Methods list
	methods_panel = side_panel.get_child(1)
	side_panel.remove_child(methods_panel)


func _setup_bookmarks_panel() -> void:
	# Prepare Methods tab
	var methods_tab_bar := TabBar.new()
	methods_tab_bar.add_tab("Methods", METHOD_ICON)
	methods_tab_bar.set_tab_icon_max_width(0, 13)

	var methods_container := VBoxContainer.new()
	methods_container.add_child(methods_tab_bar)
	methods_container.add_child(methods_panel)

	# Prepare Bookmarks tab
	var bookmarks_tab_bar := TabBar.new()
	bookmarks_tab_bar.add_tab("Bookmarks", BOOKMARK_ICON)
	bookmarks_tab_bar.set_tab_icon_max_width(0, 10)

	bookmarks_panel.add_child(bookmarks_tab_bar)
	bookmarks_panel.add_child(bookmarks_list)

	bookmarks_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bookmarks_list.connect(&"item_selected", _on_bookmark_selected)

	# Add to custom layout & Attach to ScriptEditor
	final_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	final_layout.add_child(methods_container)
	final_layout.add_child(bookmarks_panel)
	
	side_panel.add_child(final_layout)

	# Update timer for bookmark changes
	var update_timer := Timer.new()
	bookmarks_list.add_child(update_timer)
	update_timer.connect(&"timeout", _refresh_bookmarks)
	update_timer.start(BOOKMARKS_POLLING_RATE)
