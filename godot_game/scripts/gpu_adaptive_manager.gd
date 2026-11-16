extends Node

const TELEMETRY_PATH := "user://ia_game_hardware_benchmark.csv"
const SAMPLE_INTERVAL := 1.0
const LOW_FPS_LIMIT := 24.0
const RECOVER_FPS_LIMIT := 48.0

var gpu_name := "Inconnu"
var gpu_vendor := "Inconnu"
var renderer_name := "Inconnu"
var profile_name := "Équilibré"
var profile_reason := "Profil de sécurité par défaut"
var elapsed := 0.0
var sample_accumulator := 0.0
var recovery_seconds := 0
var adaptive_lights: Array[Light3D] = []
var lights_reduced := false
var telemetry: FileAccess

func _ready() -> void:
    gpu_name = RenderingServer.get_video_adapter_name()
    gpu_vendor = RenderingServer.get_video_adapter_vendor()
    renderer_name = RenderingServer.get_current_rendering_method()
    _choose_initial_profile()

func configure(lights: Array) -> void:
    adaptive_lights.clear()
    for item in lights:
        if item is Light3D:
            adaptive_lights.append(item)
    _apply_initial_profile()
    _open_telemetry()

func _process(delta: float) -> void:
    elapsed += delta
    sample_accumulator += delta
    if sample_accumulator < SAMPLE_INTERVAL:
        return
    sample_accumulator = 0.0
    var fps := float(Engine.get_frames_per_second())
    _adapt_to_performance(fps)
    _write_sample(fps)

func _choose_initial_profile() -> void:
    var gpu := (gpu_name + " " + gpu_vendor).to_lower()
    if gpu.contains("llvmpipe") or gpu.contains("software") or gpu.contains("basic render") or gpu.contains("hd graphics 2000") or gpu.contains("hd graphics 3000") or gpu.contains("hd graphics 4000"):
        profile_name = "Économique"
        profile_reason = "GPU ancien ou rendu logiciel détecté"
    elif gpu.contains("geforce") or gpu.contains("nvidia") or gpu.contains("radeon") or gpu.contains("rx "):
        profile_name = "Élevé"
        profile_reason = "GPU dédié détecté ; adaptation dynamique activée"
    elif gpu.contains("intel"):
        profile_name = "Équilibré"
        profile_reason = "GPU intégré détecté ; effets coûteux limités"
    else:
        profile_name = "Équilibré"
        profile_reason = "GPU non classé ; profil prudent et adaptation dynamique"

func _apply_initial_profile() -> void:
    if profile_name == "Économique":
        _set_lights_enabled(false)
        lights_reduced = true
    elif profile_name == "Équilibré":
        for index in range(adaptive_lights.size()):
            adaptive_lights[index].visible = index % 2 == 0

func _adapt_to_performance(fps: float) -> void:
    if fps > 0.0 and fps < LOW_FPS_LIMIT and not lights_reduced:
        _set_lights_enabled(false)
        lights_reduced = true
        recovery_seconds = 0
    elif fps >= RECOVER_FPS_LIMIT and lights_reduced and profile_name != "Économique":
        recovery_seconds += 1
        if recovery_seconds >= 10:
            _set_lights_enabled(true)
            lights_reduced = false
            recovery_seconds = 0
    elif fps < RECOVER_FPS_LIMIT:
        recovery_seconds = 0

func _set_lights_enabled(enabled: bool) -> void:
    for light in adaptive_lights:
        light.visible = enabled

func get_profile_label() -> String:
    return "%s | %s" % [profile_name, gpu_name]

func _open_telemetry() -> void:
    telemetry = FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
    if telemetry == null:
        push_warning("IA GAME : impossible de créer le CSV de télémétrie.")
        return
    telemetry.store_line("record_type,elapsed_s,gpu_name,gpu_vendor,renderer,os,cpu_threads,screen_width,screen_height,fps,godot_static_memory_mb,graphics_profile,lights_reduced")
    telemetry.store_line("hardware,0,\"%s\",\"%s\",\"%s\",\"%s\",%d,%d,%d,0,%.2f,\"%s\",%s" % [
        _csv_escape(gpu_name), _csv_escape(gpu_vendor), _csv_escape(renderer_name),
        _csv_escape(OS.get_name()), OS.get_processor_count(),
        DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y,
        float(OS.get_static_memory_usage()) / (1024.0 * 1024.0),
        profile_name, str(lights_reduced).to_lower()
    ])
    telemetry.flush()

func _write_sample(fps: float) -> void:
    if telemetry == null:
        return
    var memory_mb := float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
    telemetry.store_line("sample,%.1f,\"%s\",\"%s\",\"%s\",\"%s\",%d,%d,%d,%.1f,%.2f,\"%s\",%s" % [
        elapsed, _csv_escape(gpu_name), _csv_escape(gpu_vendor),
        _csv_escape(renderer_name), _csv_escape(OS.get_name()),
        OS.get_processor_count(), DisplayServer.screen_get_size().x,
        DisplayServer.screen_get_size().y, fps, memory_mb,
        profile_name, str(lights_reduced).to_lower()
    ])
    telemetry.flush()

func _csv_escape(value: String) -> String:
    return value.replace("\"", "\"\"")
    
func _exit_tree() -> void:
    if telemetry != null:
        telemetry.close()
        telemetry = null
