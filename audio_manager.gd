# audio_manager.gd
class_name AudioManager
extends Node

# Audio players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var ui_sound_player: AudioStreamPlayer
var event_sound_player: AudioStreamPlayer
var dialogue_sound_player: AudioStreamPlayer

# Audio bus indices
var master_bus_idx: int
var music_bus_idx: int
var sfx_bus_idx: int
var ambient_bus_idx: int
var dialogue_bus_idx: int

# Audio resources
var music_tracks: Dictionary = {}
var ambient_tracks: Dictionary = {}
var ui_sounds: Dictionary = {}
var event_sounds: Dictionary = {}
var dialogue_sounds: Dictionary = {}

# Playback state
var current_music_id: String = ""
var current_ambient_id: String = ""
var music_transition_tween: Tween
var ambient_transition_tween: Tween
var last_event_type: String = ""

# References to other systems
var game_manager: GameManager
var event_manager: EventManager

# Settings
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.7
var dialogue_volume: float = 1.0
var mute_all: bool = false

# Signals
signal music_changed(track_id)
signal ambient_changed(track_id)
signal sound_played(sound_id, sound_type)

func _ready():
    # Get references to other systems
    game_manager = get_node("/root/GameManager")
    event_manager = get_node("/root/GameManager/EventManager")
    
    # Setup audio players
    _setup_audio_players()
    
    # Get audio bus indices
    _get_audio_bus_indices()
    
    # Load audio resources
    _load_audio_resources()
    
    # Connect signals from other systems
    _connect_signals()
    
    # Start with default music
    play_music("menu")

# Setup audio system
func _setup_audio_players():
    # Create music player
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.bus = "Music"
    add_child(music_player)
    
    # Create ambient player
    ambient_player = AudioStreamPlayer.new()
    ambient_player.name = "AmbientPlayer"
    ambient_player.bus = "Ambient"
    add_child(ambient_player)
    
    # Create UI sound player
    ui_sound_player = AudioStreamPlayer.new()
    ui_sound_player.name = "UISoundPlayer"
    ui_sound_player.bus = "SFX"
    add_child(ui_sound_player)
    
    # Create event sound player
    event_sound_player = AudioStreamPlayer.new()
    event_sound_player.name = "EventSoundPlayer"
    event_sound_player.bus = "SFX"
    add_child(event_sound_player)
    
    # Create dialogue sound player
    dialogue_sound_player = AudioStreamPlayer.new()
    dialogue_sound_player.name = "DialogueSoundPlayer"
    dialogue_sound_player.bus = "Dialogue"
    add_child(dialogue_sound_player)
    
    # Create tweens for smooth transitions
    music_transition_tween = create_tween()
    ambient_transition_tween = create_tween()

func _get_audio_bus_indices():
    master_bus_idx = AudioServer.get_bus_index("Master")
    music_bus_idx = AudioServer.get_bus_index("Music")
    sfx_bus_idx = AudioServer.get_bus_index("SFX")
    ambient_bus_idx = AudioServer.get_bus_index("Ambient")
    dialogue_bus_idx = AudioServer.get_bus_index("Dialogue")

func _load_audio_resources():
    # Load music tracks
    music_tracks = {
        "menu": preload("res://audio/music/menu_theme.ogg"),
        "gameplay_calm": preload("res://audio/music/gameplay_calm.ogg"),
        "gameplay_tense": preload("res://audio/music/gameplay_tense.ogg"),
        "negotiation": preload("res://audio/music/negotiation.ogg"),
        "crisis": preload("res://audio/music/crisis.ogg"),
        "success": preload("res://audio/music/success.ogg")
    }
    
    # Load ambient tracks
    ambient_tracks = {
        "office": preload("res://audio/ambient/office_ambience.ogg"),
        "city": preload("res://audio/ambient/city_traffic.ogg"),
        "warehouse": preload("res://audio/ambient/warehouse.ogg"),
        "rural": preload("res://audio/ambient/rural.ogg"),
        "storm": preload("res://audio/ambient/storm.ogg")
    }
    
    # Load UI sounds
    ui_sounds = {
        "click": preload("res://audio/ui/click.ogg"),
        "hover": preload("res://audio/ui/hover.ogg"),
        "accept": preload("res://audio/ui/accept.ogg"),
        "reject": preload("res://audio/ui/reject.ogg"),
        "notification": preload("res://audio/ui/notification.ogg"),
        "money": preload("res://audio/ui/money.ogg"),
        "error": preload("res://audio/ui/error.ogg")
    }
    
    # Load event sounds
    event_sounds = {
        "economic": preload("res://audio/events/economic_event.ogg"),
        "weather": preload("res://audio/events/weather_event.ogg"),
        "carrier": preload("res://audio/events/carrier_event.ogg"),
        "regulatory": preload("res://audio/events/regulatory_event.ogg"),
        "customer": preload("res://audio/events/customer_event.ogg"),
        "criminal": preload("res://audio/events/criminal_event.ogg")
    }
    
    # Load dialogue sounds
    dialogue_sounds = {
        "talk_default": preload("res://audio/dialogue/talk_default.ogg"),
        "talk_carrier": preload("res://audio/dialogue/talk_carrier.ogg"),
        "talk_customer": preload("res://audio/dialogue/talk_customer.ogg"),
        "talk_official": preload("res://audio/dialogue/talk_official.ogg")
    }

func _connect_signals():
    # Connect to event system for event-based audio cues
    event_manager.connect("event_triggered", self, "_on_event_triggered")
    event_manager.connect("event_resolved", self, "_on_event_resolved")

# Music control
func play_music(track_id: String, transition_time: float = 2.0):
    if !music_tracks.has(track_id) || track_id == current_music_id:
        return
    
    var new_track = music_tracks[track_id]
    
    # Handle transition
    if music_player.playing:
        # Cancel any existing transition
        if music_transition_tween.is_running():
            music_transition_tween.kill()
        
        # Create transition effect
        music_transition_tween = create_tween()
        music_transition_tween.tween_property(music_player, "volume_db", -40.0, transition_time)
        
        # After fade out, change track and fade in
        music_transition_tween.tween_callback(self, "_change_music_track", [new_track])
        music_transition_tween.tween_property(music_player, "volume_db", 0.0, transition_time)
    else:
        # No transition needed, just start the track
        music_player.stream = new_track
        music_player.play()
    
    current_music_id = track_id
    emit_signal("music_changed", track_id)

func _change_music_track(new_track):
    music_player.stream = new_track
    music_player.play()

# Ambient sound control
func play_ambient(ambient_id: String, transition_time: float = 3.0):
    if !ambient_tracks.has(ambient_id) || ambient_id == current_ambient_id:
        return
    
    var new_ambient = ambient_tracks[ambient_id]
    
    # Handle transition
    if ambient_player.playing:
        # Cancel any existing transition
        if ambient_transition_tween.is_running():
            ambient_transition_tween.kill()
        
        # Create transition effect
        ambient_transition_tween = create_tween()
        ambient_transition_tween.tween_property(ambient_player, "volume_db", -40.0, transition_time)
        
        # After fade out, change track and fade in
        ambient_transition_tween.tween_callback(self, "_change_ambient_track", [new_ambient])
        ambient_transition_tween.tween_property(ambient_player, "volume_db", 0.0, transition_time)
    else:
        # No transition needed, just start the track
        ambient_player.stream = new_ambient
        ambient_player.play()
    
    current_ambient_id = ambient_id
    emit_signal("ambient_changed", ambient_id)

func _change_ambient_track(new_ambient):
    ambient_player.stream = new_ambient
    ambient_player.play()

# Sound effect playback
func play_ui_sound(sound_id: String):
    if !ui_sounds.has(sound_id) || mute_all:
        return
    
    # Play the UI sound
    ui_sound_player.stream = ui_sounds[sound_id]
    ui_sound_player.play()
    
    emit_signal("sound_played", sound_id, "ui")

func play_event_sound(sound_id: String):
    if !event_sounds.has(sound_id) || mute_all:
        return
    
    # Play the event sound
    event_sound_player.stream = event_sounds[sound_id]
    event_sound_player.play()
    
    emit_signal("sound_played", sound_id, "event")

func play_dialogue_sound(sound_id: String):
    if !dialogue_sounds.has(sound_id) || mute_all:
        return
    
    # Play the dialogue sound
    dialogue_sound_player.stream = dialogue_sounds[sound_id]
    dialogue_sound_player.play()
    
    emit_signal("sound_played", sound_id, "dialogue")

# Volume control
func set_master_volume(volume: float):
    master_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_volume))

func set_music_volume(volume: float):
    music_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume))

func set_sfx_volume(volume: float):
    sfx_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(sfx_volume))

func set_ambient_volume(volume: float):
    ambient_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(ambient_bus_idx, linear_to_db(ambient_volume))

func set_dialogue_volume(volume: float):
    dialogue_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(dialogue_bus_idx, linear_to_db(dialogue_volume))

func set_mute(mute: bool):
    mute_all = mute
    
    if mute_all:
        AudioServer.set_bus_mute(master_bus_idx, true)
    else:
        AudioServer.set_bus_mute(master_bus_idx, false)

# Adaptive audio based on game state
func update_audio_for_game_state(game_state: String):
    match game_state:
        "menu":
            play_music("menu")
            play_ambient("office")
        "gameplay":
            play_music("gameplay_calm")
            # Ambient would depend on the current map view
        "negotiation":
            play_music("negotiation")
        "crisis":
            play_music("crisis")
            # Ambient might change based on crisis type
        "success":
            play_music("success", 1.0)  # Shorter transition for success jingle

func update_ambient_for_location(location_type: String):
    match location_type:
        "city":
            play_ambient("city")
        "warehouse":
            play_ambient("warehouse")
        "rural":
            play_ambient("rural")
        "office":
            play_ambient("office")
        # Weather conditions could override these
        "storm":
            play_ambient("storm")

# Signal handlers from other systems
func _on_event_triggered(event_id, event_type, affected_ids):
    # Play appropriate sound for event type
    play_event_sound(event_type)
    
    # Possibly adjust music based on event severity
    var event = event_manager.active_events[event_id]
    if event.severity > 0.7:
        play_music("crisis")
    
    # Remember the event type for potential future reference
    last_event_type = event_type

func _on_event_resolved(event_id, outcome):
    # Play resolution sound
    if outcome == "resolved" || outcome == "mitigated":
        play_ui_sound("accept")
    else:
        play_ui_sound("reject")
    
    # If this was a crisis and it's resolved, go back to normal music
    var event = event_manager.active_events[event_id]
    if event.severity > 0.7 && (outcome == "resolved" || outcome == "mitigated"):
        play_music("gameplay_calm")
