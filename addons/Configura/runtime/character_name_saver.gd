class_name CharacterNameSaver
extends PanelContainer

signal confirm_pressed(name:String)

var input:LineEdit
var btn: Button
var tooltip: RichTextLabel
  
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	input = get_node("LayoutContainer/ControlContainter/Input")
	btn = get_node("LayoutContainer/ControlContainter/SaveButton")
	tooltip = get_node("LayoutContainer/Tooltip")
	print(tooltip)
	btn.pressed.connect(on_btn_pressed)
	
func on_btn_pressed() -> void:
	var text = input.text
	text.strip_edges(true,true)
	if text == "" or null:
		tooltip.clear()
		tooltip.push_color(Color("red"))
		tooltip.add_text("ERROR: Invaild Name please enter a vaild name!!")
		tooltip.pop()
	else:
		print("a")
		tooltip.push_color(Color("white"))
		tooltip.text = "Please enter a name for the character:"
		tooltip.pop()
		print(input.text)
		confirm_pressed.emit(input.text)
		input.clear()
		
