@tool
extends Node3D

@export
var character_base: Node3D
@export
var character_config: CharacterConfig
@export
var character_state: CharacterState
@export_tool_button("do the thing","Debug")
var do_action = make_model

func make_model() -> void:
	CharacterStateApplier.apply(character_state,character_config,character_base)
