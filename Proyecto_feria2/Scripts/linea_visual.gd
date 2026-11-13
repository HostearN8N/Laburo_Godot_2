extends MeshInstance3D

@export var ancho: float = 15.0   # igual que el Size X de tu BoxShape3D
@export var largo: float = 2.0    # igual que el Size Z
@export var columnas: int = 16
@export var filas: int = 2

func _ready() -> void:
	# Textura de cuadros blanco y negro
	var img := Image.create(columnas, filas, false, Image.FORMAT_RGB8)
	for x in columnas:
		for y in filas:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # bordes nítidos
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var quad := QuadMesh.new()
	quad.size = Vector2(ancho, largo)
	mesh = quad
	material_override = mat

	rotation_degrees = Vector3(-90, 0, 0)  # acostado sobre el suelo
