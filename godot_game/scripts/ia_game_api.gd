extends Node

signal prediction_received(result: Dictionary)
signal request_failed(message: String)

@export var api_base_url := "http://127.0.0.1:8000"
var http: HTTPRequest

func _ready() -> void:
    http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_request_completed)

func request_prediction(machine_values: Dictionary) -> void:
    var payload := JSON.stringify({"rows": [machine_values]})
    var headers := PackedStringArray(["Content-Type: application/json"])
    var error := http.request(
        api_base_url + "/models/predict",
        headers,
        HTTPClient.METHOD_POST,
        payload
    )
    if error != OK:
        request_failed.emit("Impossible d'envoyer la requête HTTP : %s" % error_string(error))

func _on_request_completed(
    result: int,
    response_code: int,
    _headers: PackedStringArray,
    body: PackedByteArray
) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        request_failed.emit("Erreur réseau : %s" % result)
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if response_code != 200:
        request_failed.emit(str(parsed))
        return
    if typeof(parsed) != TYPE_DICTIONARY:
        request_failed.emit("Réponse API invalide")
        return
    prediction_received.emit(parsed)
