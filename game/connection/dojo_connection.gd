class_name DojoConnection
extends Node

signal connected
signal tx_started(entrypoint: String)
signal tx_completed(entrypoint: String, success: bool, tx_hash: String)

const WORLD_CONTRACT = "0x45c07350e8cf8a281e5531a98b8aefc8a299f7ccd84d3ab33160e0e836056dd"
const ACTIONS_TAG = "prophecy_roguelite-actions"
const APP_ID = "prophecy-roguelite"

# --- Configuration ---
var use_slot: bool = true
# Controller session auth disabled — Slot Katana's Controller contract
# rejects session registration (invalid-owner-sig). Transactions still
# execute fully on-chain via sozo. Controller code kept for mainnet deploy.
var use_controller: bool = false

# Local dev
const LOCAL_TORII = "http://localhost:8080"
const LOCAL_RPC = "http://localhost:5050"

# Slot (deployed)
const SLOT_TORII = "https://api.cartridge.gg/x/prophecy-roguelite/torii"
const SLOT_RPC = "https://api.cartridge.gg/x/prophecy-roguelite/katana"

# Actions contract address
var ACTIONS_CONTRACT: String = "0x3446495be1d3c24ac1d630722fe47ce134ddb0ff29767efb3fe27a6bfa111f2"

var torii_client: ToriiClient
var entity_sub: int = -1
var _is_connected: bool = false

# Sozo mode (local dev fallback)
var _sozo_path: String = ""
var _manifest_path: String = ""
var _pending_threads: Array[Thread] = []

# Controller mode (Cartridge Controller)
var _session_account: DojoSessionAccount
var _controller_ready: bool = false
var _priv_key: String = ""

func _ready() -> void:
	OS.set_environment("RUST_LOG", "info")
	var home = OS.get_environment("HOME")
	var current_path = OS.get_environment("PATH")
	if not current_path.contains(".asdf/shims"):
		OS.set_environment("PATH", home + "/.asdf/shims:" + home + "/.dojo/bin:" + current_path)
	_sozo_path = home + "/.asdf/shims/sozo"
	var project_dir = ProjectSettings.globalize_path("res://")
	var parent = project_dir.trim_suffix("/").get_base_dir()
	_manifest_path = parent + "/contracts/Scarb.toml"
	print("[Dojo] Mode: ", "Slot" if use_slot else "Local")

func _get_torii_url() -> String:
	return SLOT_TORII if use_slot else LOCAL_TORII

func _get_rpc_url() -> String:
	return SLOT_RPC if use_slot else LOCAL_RPC

func connect_torii() -> bool:
	torii_client = ToriiClient.new()
	add_child(torii_client)
	var url = _get_torii_url()
	var result: bool = torii_client.call("connect", url)
	_is_connected = result
	print("[Dojo] Torii connected to %s: %s" % [url, result])
	return result

func subscribe_entities(callback: Callable) -> void:
	if torii_client == null:
		return
	var cb: DojoCallback = DojoCallback.new()
	cb.on_update = callback
	entity_sub = torii_client.subscribe_entity_updates(DojoClause.new(), [WORLD_CONTRACT], cb)
	print("[Dojo] Subscribed to entity updates")

func fetch_entities() -> Dictionary:
	if torii_client == null:
		return {}
	return torii_client.entities(DojoQuery.new())

func setup() -> void:
	var result = connect_torii()
	if not result:
		push_error("[Dojo] Failed to connect to Torii")
		return

	# Setup Cartridge Controller for Slot mode
	if use_slot and use_controller:
		_setup_controller()
	else:
		connected.emit()

# --- Cartridge Controller setup (DojoSessionAccount + browser auth) ---
func _setup_controller() -> void:
	_priv_key = ControllerHelper.generate_private_key()
	var pub_key = ControllerHelper.get_public_key(_priv_key)
	print("[Dojo] Generated session key, pub: ", pub_key)

	# Build policies dict matching Cartridge session format
	var policies: Dictionary = {
		"policies": [
			{"target": ACTIONS_CONTRACT, "method": "spawn"},
			{"target": ACTIONS_CONTRACT, "method": "predict_and_advance"}
		]
	}

	# Generate session registration URL and open browser
	var session_url: String = ControllerHelper.create_session_registration_url(
		_priv_key, policies, _get_rpc_url(), APP_ID
	)
	print("[Dojo] Session URL: ", session_url)

	if session_url == "":
		push_warning("[Dojo] Empty session URL, falling back to sozo")
		connected.emit()
		return

	OS.shell_open(session_url)
	print("[Dojo] Opened Cartridge Controller in browser")

	# Setup DojoSessionAccount to listen for session approval
	_session_account = DojoSessionAccount.new()
	add_child(_session_account)
	_session_account.set("max_fee", "0x100000")
	_session_account.set("full_policies", policies)
	_session_account.create_from_subscribe(
		_priv_key, _get_rpc_url(), policies, "https://api.cartridge.gg"
	)
	print("[Dojo] Session account subscribing...")

	# Poll for session readiness
	_wait_for_session()

func _wait_for_session() -> void:
	for i in range(120):  # Wait up to 2 minutes
		await get_tree().create_timer(1.0).timeout
		# Check if session account got an address
		var addr: String = _session_account.get_address()
		if addr != "" and addr != "0x0" and addr != "0x":
			_controller_ready = true
			print("[Dojo] Session ready! Address: ", addr)
			print("[Dojo] Username: ", _session_account.call("username"))
			connected.emit()
			return

	# Fallback to sozo
	if not _controller_ready:
		push_warning("[Dojo] Controller auth timed out, falling back to sozo")
		connected.emit()

func execute(entrypoint: String, calldata: Array = []) -> void:
	tx_started.emit(entrypoint)
	if _controller_ready:
		_execute_controller(entrypoint, calldata)
	else:
		_execute_sozo(entrypoint, calldata)

# --- Controller execution via DojoSessionAccount ---
func _execute_controller(entrypoint: String, calldata: Array) -> void:
	if _session_account == null:
		push_warning("[Dojo] Session not available, falling back to sozo")
		_execute_sozo(entrypoint, calldata)
		return
	print("[Dojo] Executing via Controller: %s(%s)" % [entrypoint, str(calldata)])
	var tx_result: String = _session_account.execute_from_outside_single(
		ACTIONS_CONTRACT, entrypoint, calldata
	)
	print("[Dojo] Controller TX result: ", tx_result)
	tx_completed.emit(entrypoint, true, tx_result)

# --- Sozo execution (fallback / local dev) ---
func _execute_sozo(entrypoint: String, calldata: Array) -> void:
	var thread = Thread.new()
	_pending_threads.append(thread)
	thread.start(_run_sozo.bind(entrypoint, calldata, thread))

func _run_sozo(entrypoint: String, calldata: Array, thread: Thread) -> void:
	var args: PackedStringArray = [
		"execute", ACTIONS_TAG, entrypoint
	]
	for cd in calldata:
		args.append(str(cd))
	args.append("--wait")
	args.append("--manifest-path")
	args.append(_manifest_path)
	if use_slot:
		args.append("--rpc-url")
		args.append(SLOT_RPC)

	print("[Dojo] Executing: sozo ", " ".join(args))

	var output: Array = []
	var exit_code = OS.execute(_sozo_path, args, output, true)
	var output_str = str(output[0]) if output.size() > 0 else ""
	var tx_hash = ""
	if output_str.contains("Transaction hash:"):
		tx_hash = output_str.get_slice("Transaction hash:", 1).strip_edges()

	call_deferred("_on_sozo_done", entrypoint, exit_code, output_str, tx_hash, thread)

func _on_sozo_done(entrypoint: String, exit_code: int, output: String, tx_hash: String, thread: Thread) -> void:
	thread.wait_to_finish()
	_pending_threads.erase(thread)
	var success = exit_code == 0
	if not success:
		push_error("[Dojo] sozo failed: " + output)
	else:
		print("[Dojo] TX success: ", tx_hash)
	tx_completed.emit(entrypoint, success, tx_hash)
