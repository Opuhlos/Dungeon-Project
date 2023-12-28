extends CharacterBody3D

var character_name : String = "Capsule"
var lvl : int = 1

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		print("Hello")


func _on_hitbox_area_entered(area):
	if area.is_in_group("player"):
		event_handler.emit_signal("battle_started", character_name, lvl)
	pass
