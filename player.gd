extends CharacterBody2D

const TILE_SIZE = 200
var moving = false
var input_dir

func _physics_process(delta: float) -> void:
	input_dir = Vector2.ZERO
	if Input.is_action_just_pressed("ui_up") and !$up.is_colliding():
		input_dir = Vector2(0,-1)
		move()
	elif Input.is_action_just_pressed("ui_down") and !$down.is_colliding():
		input_dir = Vector2(0,1)
		move()
	elif Input.is_action_just_pressed("ui_left") and !$left.is_colliding():
		input_dir = Vector2(-1,0)
		move()
	elif Input.is_action_just_pressed("ui_right") and !$right.is_colliding():
		input_dir = Vector2(1, 0)
		move()
	velocity = input_dir*10000*delta
	move_and_slide()	
	
func move():
	if input_dir:
		if moving == false:
			moving = true
			var tween = create_tween()
			tween.tween_property(self, "position", position + input_dir * TILE_SIZE, 0.35)
			tween.tween_callback(move_false)
	
func move_false():
	moving = false
		
