extends Control


@export var player:Player
@onready var interact_tooltip:Label = $MarginContainer/InteractTooltip


func _ready() -> void:
	player.interaction_text_detected.connect(show_label.bind())
	player.interaction_text_ended.connect(hide_label.bind())


func show_label(verb:String, obj:String) -> void:
	interact_tooltip.show()
	interact_tooltip.text = "%s %s" % [verb, obj]


func hide_label() -> void:
	interact_tooltip.hide()
