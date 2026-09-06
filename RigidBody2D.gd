extends RigidBody2D  # Mude de Area2D para RigidBody2D

@onready var target = $"../Player"
@onready var anim = $anim
var speed = 200

#func _physics_process(delta):
##	var velocity = direction * speed * delta
#	position += velocity  # Move o objeto manualmente

func _ready():
	anim.play("Active")

func _on_body_entered(body):
	if body.name == "Player":
		anim.play("Vanished")
		player_data.frag += 1
		#print("Quantidade de fragmentos:", player_data.frag)
		await anim.animation_finished
		queue_free()
