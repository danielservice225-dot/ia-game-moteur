extends SceneTree

const API_URL := "http://127.0.0.1:8000"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var request := HTTPRequest.new()
    request.timeout = 15.0
    root.add_child(request)

    var error := request.request(API_URL + "/health")
    if error != OK:
        _fail("Impossible d'appeler /health : " + error_string(error))
        return
    var health_response: Array = await request.request_completed
    if int(health_response[0]) != HTTPRequest.RESULT_SUCCESS or int(health_response[1]) != 200:
        _fail("Le serveur Python ne répond pas correctement à /health.")
        return
    var health = JSON.parse_string((health_response[3] as PackedByteArray).get_string_from_utf8())
    if typeof(health) != TYPE_DICTIONARY or not bool(health.get("model_available", false)):
        _fail("L'API répond, mais aucun modèle entraîné n'est disponible.")
        return

    var headers := PackedStringArray(["Content-Type: application/json"])
    var payload := JSON.stringify({
        "rows": [{
            "temperature_c": 92.0,
            "vibration_mm_s": 3.4,
            "pressure_bar": 4.1
        }]
    })
    error = request.request(API_URL + "/models/predict", headers, HTTPClient.METHOD_POST, payload)
    if error != OK:
        _fail("Impossible d'envoyer la prédiction : " + error_string(error))
        return
    var prediction_response: Array = await request.request_completed
    if int(prediction_response[0]) != HTTPRequest.RESULT_SUCCESS or int(prediction_response[1]) != 200:
        _fail("La prédiction HTTP a échoué : " + (prediction_response[3] as PackedByteArray).get_string_from_utf8())
        return
    var prediction = JSON.parse_string((prediction_response[3] as PackedByteArray).get_string_from_utf8())
    if typeof(prediction) != TYPE_DICTIONARY:
        _fail("La réponse de prédiction n'est pas un objet JSON.")
        return
    var predictions: Array = prediction.get("predictions", [])
    if predictions.size() != 1:
        _fail("L'API n'a pas renvoyé exactement une prédiction.")
        return

    print("PASS: Godot a appelé l'API Python et reçu une prédiction ML.")
    request.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("FAIL: " + message)
    quit(1)
