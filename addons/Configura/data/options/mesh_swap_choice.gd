## A single selectable choice owned by a [MeshSwapOption].
@tool
class_name MeshSwapChoice
extends Resource

## Whether this Option should be included as a selectable parameter or not in the UI
@export var include: bool = true

## Label shown on the generated button.
@export var label: String = ""

## Icon to display on mesh swap choice button
@export var icon: Texture2D = null

## NodePath to the MeshInstance3D for this choice.
## The node is shown when this choice is selected; all siblings are hidden.
@export var mesh_path: NodePath

## Stores the string path for this mesh swap's file. Loaded in at runtime when selected.
@export var file_path: String = ""

## Returns a string with the choice options settings
func _to_string() -> String:
	return "Choice(%s | mesh path: %s | file path: %s | include: %s)" % [
		label, mesh_path, file_path, include
	]
