class_name CharacterLoadRow
extends Button


@onready var no_icon = "res://addons/Configura/icons/missing_icon.svg"

@export var state : CharacterState

func init(name:String,preview:Image,char_state:CharacterState)-> void:
	if name != null:
		self.text = name
	if preview != null:
		self.icon =  ImageTexture.create_from_image(preview)
	else:
		self.icon = load(no_icon)
	state = char_state


func _on_pressed() -> void:
	pass
