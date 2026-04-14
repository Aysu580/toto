extends Control

@onready var center_cards = $CenterCards
@onready var player_top = $PlayerTop
@onready var player_right = $PlayerRight
@onready var player_bottom = $PlayerBottom
@onready var player_left = $PlayerLeft
@onready var status_label = $StatusLabel

const CARDS_FOLDER := "res://cards/"
const CARD_BACK_FILE := "back.png"

var deck: Array[String] = []

var player_hands := {
	"top": [],
	"right": [],
	"bottom": [],
	"left": []
}

var koz_card: String = ""

var guess_inputs := {}
var guess_summary_label: Label
var prediction_panel: PanelContainer
var confirm_button: Button

var round_locked := false

func get_card_info(card_path: String) -> Dictionary:
	var file_name := card_path.get_file().get_basename() # örn: hearts_10
	var parts := file_name.split("_")

	if parts.size() < 2:
		return {"suit": "", "rank": ""}

	return {
		"suit": parts[0],
		"rank": parts[1]
	}


func get_rank_value(rank: String) -> int:
	match rank:
		"02":
			return 2
		"03":
			return 3
		"04":
			return 4
		"05":
			return 5
		"06":
			return 6
		"07":
			return 7
		"08":
			return 8
		"09":
			return 9
		"10":
			return 10
		"jack":
			return 11
		"queen":
			return 12
		"king":
			return 13
		"ace":
			return 14
		_:
			return -1


func get_suit_display_name(suit: String) -> String:
	match suit:
		"clubs":
			return "Sinek"
		"diamonds":
			return "Karo"
		"hearts":
			return "Kupa"
		"spades":
			return "Maça"
		_:
			return suit
func determine_winner() -> String:
	if koz_card == "":
		return "Kazanan belirlenemedi"

	var koz_info := get_card_info(koz_card)
	var koz_suit: String = koz_info["suit"]

	var reveal_order = [
		{"key": "top", "label": "Player1"},
		{"key": "right", "label": "Player2"},
		{"key": "bottom", "label": "Player3"},
		{"key": "left", "label": "Player4"}
	]

	var winner_name := ""
	var highest_value := -1
	var matched_suit := koz_suit

	# 1) Önce koz türüne göre kazanan ara
	for player in reveal_order:
		var key: String = player["key"]
		var label: String = player["label"]

		if player_hands[key].is_empty():
			continue

		var card_path: String = player_hands[key][0]
		var card_info := get_card_info(card_path)
		var suit: String = card_info["suit"]
		var rank: String = card_info["rank"]

		if suit == koz_suit:
			var rank_value := get_rank_value(rank)
			if rank_value > highest_value:
				highest_value = rank_value
				winner_name = label

	# 2) Hiç kimseye koz gelmediyse, Player1'in türünü baz al
	if winner_name == "":
		if player_hands["top"].is_empty():
			return "Kazanan belirlenemedi"

		var first_player_card :String = player_hands["top"][0]
		var first_card_info := get_card_info(first_player_card)
		var first_suit: String = first_card_info["suit"]

		matched_suit = first_suit
		highest_value = -1

		for player in reveal_order:
			var key: String = player["key"]
			var label: String = player["label"]

			if player_hands[key].is_empty():
				continue

			var card_path: String = player_hands[key][0]
			var card_info := get_card_info(card_path)
			var suit: String = card_info["suit"]
			var rank: String = card_info["rank"]

			if suit == first_suit:
				var rank_value := get_rank_value(rank)
				if rank_value > highest_value:
					highest_value = rank_value
					winner_name = label

		return "%s kazandı! Koz gelmedi, Player1 türü baz alındı: %s" % [winner_name, get_suit_display_name(matched_suit)]

	return "%s kazandı! Koz türü: %s" % [winner_name, get_suit_display_name(matched_suit)]

	

func _ready() -> void:
	create_prediction_panel()
	start_one_round()
	
	# Yazıyı yukarı al
	status_label.position.y = 20

# Font büyüt
	status_label.add_theme_font_size_override("font_size", 26)

# Bold efekti (outline ile daha net görünür)
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)


func start_one_round() -> void:
	clear_old_round()
	build_deck()
	shuffle_deck()
	await deal_one_card_to_each_player()
	reveal_koz_card()
	enable_guess_inputs(true)
	confirm_button.disabled = false
	status_label.text = "Kartlar dağıtıldı, koz açıldı. Tahminleri girin."


func clear_old_round() -> void:
	clear_children(player_top)
	clear_children(player_right)
	clear_children(player_bottom)
	clear_children(player_left)
	clear_children(center_cards)

	player_hands = {
		"top": [],
		"right": [],
		"bottom": [],
		"left": []
	}

	koz_card = ""
	round_locked = false

	reset_guess_inputs()
	enable_guess_inputs(false)

	if is_instance_valid(confirm_button):
		confirm_button.disabled = true

	status_label.text = "Yeni tur başladı"


func build_deck() -> void:
	deck.clear()

	var dir := DirAccess.open(CARDS_FOLDER)
	if dir == null:
		push_error("Cards klasörü bulunamadı: " + CARDS_FOLDER)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				if file_name != CARD_BACK_FILE:
					deck.append(CARDS_FOLDER + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func shuffle_deck() -> void:
	deck.shuffle()


func deal_one_card_to_each_player() -> void:
	var order = [
		{"key": "top", "node": player_top, "face_up": false, "label": "Player1"},
		{"key": "right", "node": player_right, "face_up": false, "label": "Player2"},
		{"key": "bottom", "node": player_bottom, "face_up": true, "label": "Player3"},
		{"key": "left", "node": player_left, "face_up": false, "label": "Player4"}
	]

	for player in order:
		if deck.is_empty():
			return

		var dealt_card: String = deck.pop_back()
		player_hands[player["key"]].append(dealt_card)

		var shown_texture_path := CARDS_FOLDER + CARD_BACK_FILE
		if player["face_up"]:
			shown_texture_path = dealt_card

		var card := create_card_texture_rect(shown_texture_path)
		player["node"].add_child(card)

		status_label.text = str(player["label"]) + " kartını aldı"
		await get_tree().create_timer(0.45).timeout

	status_label.text = "4 oyuncuya da 1 kart dağıtıldı"


func reveal_koz_card() -> void:
	if deck.is_empty():
		return

	koz_card = deck.pop_back()

	var koz_texture := create_card_texture_rect(koz_card)
	koz_texture.position = Vector2(300, 120)
	center_cards.add_child(koz_texture)

	status_label.text = "Koz kartı açıldı"


func create_card_texture_rect(texture_path: String) -> TextureRect:
	var card := TextureRect.new()
	card.texture = load(texture_path)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.custom_minimum_size = Vector2(110, 165)
	card.size = Vector2(110, 165)
	return card


func create_player_card_block(player_name: String, card_path: String, pos: Vector2) -> Control:
	var block := Control.new()
	block.position = pos
	block.custom_minimum_size = Vector2(130, 220)
	block.size = Vector2(130, 220)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.position = Vector2(0, 0)
	name_label.size = Vector2(130, 35)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	block.add_child(name_label)

	var card := create_card_texture_rect(card_path)
	card.position = Vector2(10, 42)
	block.add_child(card)

	return block


func create_koz_display() -> void:
	if koz_card == "":
		return

	var koz_title := Label.new()
	koz_title.text = "KOZ"
	koz_title.position = Vector2(40, 30)
	koz_title.size = Vector2(140, 40)
	koz_title.add_theme_font_size_override("font_size", 28)
	koz_title.add_theme_color_override("font_color", Color.WHITE)
	koz_title.add_theme_constant_override("outline_size", 3)
	koz_title.add_theme_color_override("font_outline_color", Color.BLACK)
	center_cards.add_child(koz_title)

	var koz_texture := create_card_texture_rect(koz_card)
	koz_texture.position = Vector2(40, 75)
	center_cards.add_child(koz_texture)


func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func create_prediction_panel() -> void:
	prediction_panel = PanelContainer.new()
	prediction_panel.name = "PredictionPanel"
	prediction_panel.anchor_left = 1.0
	prediction_panel.anchor_top = 1.0
	prediction_panel.anchor_right = 1.0
	prediction_panel.anchor_bottom = 1.0
	prediction_panel.offset_left = -370
	prediction_panel.offset_top = -210
	prediction_panel.offset_right = -20
	prediction_panel.offset_bottom = -20
	add_child(prediction_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	prediction_panel.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Tahmin Tablosu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	var info := Label.new()
	info.text = "Koz açıldıktan sonra tahminleri girin"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(info)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	outer_vbox.add_child(grid)

	var player_names = ["Player1", "Player2", "Player3", "Player4"]

	for player_name in player_names:
		var name_label := Label.new()
		name_label.text = player_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(name_label)

	for player_name in player_names:
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 13
		spin.step = 1
		spin.value = 0
		spin.custom_minimum_size = Vector2(55, 0)
		spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
		spin.value_changed.connect(_on_guess_changed.bind(player_name))
		grid.add_child(spin)
		guess_inputs[player_name] = spin

	guess_summary_label = Label.new()
	guess_summary_label.text = "Tahminler: Player1=0 | Player2=0 | Player3=0 | Player4=0"
	guess_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer_vbox.add_child(guess_summary_label)

	confirm_button = Button.new()
	confirm_button.text = "Tahminleri Onayla"
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_guesses_pressed)
	outer_vbox.add_child(confirm_button)


func reset_guess_inputs() -> void:
	for player_name in guess_inputs.keys():
		var spin: SpinBox = guess_inputs[player_name]
		spin.value = 0
	update_guess_summary()


func enable_guess_inputs(enabled: bool) -> void:
	for player_name in guess_inputs.keys():
		var spin: SpinBox = guess_inputs[player_name]
		spin.editable = enabled


func _on_guess_changed(value: float, player_name: String) -> void:
	update_guess_summary()


func update_guess_summary() -> void:
	var p1: int = int(guess_inputs["Player1"].value)
	var p2: int = int(guess_inputs["Player2"].value)
	var p3: int = int(guess_inputs["Player3"].value)
	var p4: int = int(guess_inputs["Player4"].value)

	guess_summary_label.text = "Tahminler: Player1=%d | Player2=%d | Player3=%d | Player4=%d" % [p1, p2, p3, p4]


func _on_confirm_guesses_pressed() -> void:
	if round_locked:
		return

	round_locked = true
	enable_guess_inputs(false)
	confirm_button.disabled = true
	status_label.text = "Tahminler onaylandı. Oyuncular kartlarını sırayla açıyor."
	await reveal_players_cards_in_order()


func reveal_players_cards_in_order() -> void:
	# Önce ekran temizleniyor
	clear_children(center_cards)

	clear_children(player_top)
	clear_children(player_right)
	clear_children(player_bottom)
	clear_children(player_left)

	# Sol üstte KOZ başlığı ve altında koz kartı tekrar gösteriliyor
	create_koz_display()

	var reveal_order = [
		{"key": "top", "label": "Player1"},
		{"key": "right", "label": "Player2"},
		{"key": "bottom", "label": "Player3"},
		{"key": "left", "label": "Player4"}
	]

	# Kartlar daha yukarı alındı, böylece tahmin tablosuyla çakışmayacak
	var start_x := 190.0
	var y := 25.0
	var gap := 150.0

	for i in range(reveal_order.size()):
		var player = reveal_order[i]
		var key: String = player["key"]
		var label: String = player["label"]

		if player_hands[key].is_empty():
			continue

		var card_path: String = player_hands[key][0]
		var card_block := create_player_card_block(label, card_path, Vector2(start_x + i * gap, y))
		center_cards.add_child(card_block)

		status_label.text = label + " kartını açtı"
		await get_tree().create_timer(1.8).timeout

	var winner_text := determine_winner()
	status_label.text = "Tüm oyuncular kartlarını açtı. " + winner_text
