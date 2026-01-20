extends Node2D

@onready var capa_1: Parallax2D = $capa_1
@onready var capa_2: Parallax2D = $capa_2
@onready var capa_3: Parallax2D = $capa_3
@onready var capa_4: Parallax2D = $capa_4

var repeat_size: Vector2 = Vector2(576.0, 0.0)
const SCROLL_SPEED: float = 60.0

func _ready() -> void:
	capa_1.repeat_size = self.repeat_size
	capa_1.autoscroll = Vector2((-SCROLL_SPEED)/12, 0.0)
	capa_1.follow_viewport = false
	
	capa_2.repeat_size = self.repeat_size
	capa_2.autoscroll = Vector2((-SCROLL_SPEED)/9, 0.0)
	capa_2.follow_viewport = false
	
	capa_3.repeat_size = self.repeat_size
	capa_3.autoscroll = Vector2((-SCROLL_SPEED)/6, 0.0)
	capa_3.follow_viewport = false
	
	capa_4.repeat_size = self.repeat_size
	capa_4.autoscroll = Vector2(-SCROLL_SPEED, 0.0)
	capa_4.follow_viewport = false
	
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
