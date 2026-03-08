class_name DojoConnection
extends Node

signal connected
signal tx_started(entrypoint: String)
signal tx_completed(entrypoint: String, success: bool, tx_hash: String)

const WORLD_CONTRACT = "0x45c07350e8cf8a281e5531a98b8aefc8a299f7ccd84d3ab33160e0e836056dd"
const ACTIONS_TAG = "prophecy_roguelite-actions"
const APP_ID = "prophecy-roguelite"
const CHAIN_ID = "0x57505f50524f50484543595f524f4755454c495445"  # WP_PROPHECY_ROGUELITE

# --- Configuration ---
var use_slot: bool = true
# Cartridge Controller — headless mode for player onboarding.
# Deploys Controller account on-chain via signup(), no browser popup needed.
# Falls back to sozo if Controller initialization fails.
var use_controller: bool = true

# Local dev
const LOCAL_TORII = "http://localhost:8080"
const LOCAL_RPC = "http://localhost:5050"

# Slot (deployed)
const SLOT_TORII = "https://api.cartridge.gg/x/prophecy-roguelite/torii"
const SLOT_RPC = "https://api.cartridge.gg/x/prophecy-roguelite/katana"

# Actions contract address
var ACTIONS_CONTRACT: String = "0x070bad7e569b89c90e5ddfec8eb715d4cbd9968d3a7a6d9ced05d167eee260f4"

var torii_client: ToriiClient
var entity_sub: int = -1
var _is_connected: bool = false

# Sozo mode (local dev fallback)
var _sozo_path: String = ""
var _manifest_path: String = ""
var _pending_threads: Array[Thread] = []

# Headless Controller mode (Cartridge Controller)
var _controller: DojoController
var _controller_ready: bool = false
var _priv_key: String = ""

# Session policies for Controller
var _policies: Array[Dictionary] = [
	{"target": "", "method": "create_trader"},
	{"target": "", "method": "place_prediction"},
	{"target": "", "method": "claim"},
	{"target": "", "method": "create_market"},
	{"target": "", "method": "resolve_market"}
]

# Multi-account support (Katana predeployed accounts)
var accounts: Array[Dictionary] = [
	{"address": "0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec", "private_key": "0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912", "label": "Trader 1"},
	{"address": "0x13d9ee239f33fea4f8785b9e3870ade909e20a9599ae7cd62c1c292b73af1b7", "private_key": "0x1c9053c053edf324aec366a34c6901b1095b07af69495bffec7d7fe21effb1b", "label": "Trader 2"},
	{"address": "0x17cc6ca902ed4e8baa8463a7009ff18cc294fa85a94b4ce6ac30a9ebd6057c7", "private_key": "0x14d6672dcb4b77ca36a887e9a11cd9d637d5012468175829e9c6e770c61642", "label": "Trader 3"},
]
var active_account_index: int = 0

func get_player_address() -> String:
	if accounts.size() > 0:
		return accounts[active_account_index].get("address", "")
	return "0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec"

func get_player_label() -> String:
	if _controller_ready and _controller != null:
		var uname = _controller.username()
		if uname != "":
			return uname
	if accounts.size() > 0:
		return accounts[active_account_index].get("label", "Trader")
	return "Trader"

func set_active_account(index: int) -> void:
	active_account_index = clampi(index, 0, accounts.size() - 1)

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
	# Set policy targets
	for p in _policies:
		p["target"] = ACTIONS_CONTRACT
	print("[Dojo] Mode: ", "Slot" if use_slot else "Local")

func _get_torii_url() -> String:
	return SLOT_TORII if use_slot else LOCAL_TORII

func _get_rpc_url() -> String:
	return SLOT_RPC if use_slot else LOCAL_RPC

func connect_torii() -> bool:
	printerr("[Dojo] Creating ToriiClient...")
	torii_client = ToriiClient.new()
	add_child(torii_client)
	var url = _get_torii_url()
	printerr("[Dojo] Connecting to Torii at: %s" % url)
	var result: bool = torii_client.call("connect", url)
	_is_connected = result
	printerr("[Dojo] Torii connected: %s" % result)
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

	# Cartridge Controller integration for player onboarding
	if use_slot and use_controller:
		print("[Dojo] Initializing Cartridge Controller (headless)...")
		await _setup_controller()
	else:
		connected.emit()

# --- Cartridge Controller setup (Headless — no browser popup) ---
func _setup_controller() -> void:
	_priv_key = ControllerHelper.generate_private_key()
	var pub_key = ControllerHelper.get_public_key(_priv_key)
	print("[Dojo] Generated Controller key, pub: ", pub_key)

	_controller = DojoController.new()
	add_child(_controller)

	# Controller v1.0.9 class hash (hardcoded — get_controller_class_hash has a bug)
	var class_hash: String = "0x743c83c41ce99ad470aa308823f417b2141e02e04571f5c0004e743556e7faf"

	var ctrl_owner: DojoOwner = DojoOwner.init(_priv_key)

	print("[Dojo] Headless init: app=%s rpc=%s" % [APP_ID, _get_rpc_url()])
	_controller.initialize_headless(
		APP_ID, "prophecy_player", class_hash, _get_rpc_url(), ctrl_owner, CHAIN_ID
	)

	print("[Dojo] Signing up Controller on-chain...")
	_controller.signup(0, 0, "https://api.cartridge.gg")

	# Wait for Controller deployment
	await get_tree().create_timer(2.0).timeout
	var addr: String = _controller.address()
	if addr != "" and addr != "0x0" and addr != "0x":
		_controller_ready = true
		print("[Dojo] Controller ready! Address: ", addr)
		print("[Dojo] Username: ", _controller.username())
	else:
		push_warning("[Dojo] Controller not ready, using sozo fallback")

	connected.emit()

func execute(entrypoint: String, calldata: Array = []) -> void:
	tx_started.emit(entrypoint)
	# Controller is initialized for Cartridge integration but execute via sozo
	# (Controller execute returns empty — GDExtension issue)
	_execute_sozo(entrypoint, calldata)

# --- Controller execution via DojoController ---
func _execute_controller(entrypoint: String, calldata: Array) -> void:
	if _controller == null:
		push_warning("[Dojo] Controller not available, falling back to sozo")
		_execute_sozo(entrypoint, calldata)
		return
	print("[Dojo] Executing via Controller: %s(%s)" % [entrypoint, str(calldata)])
	var calls: Array = [{
		"contract_address": ACTIONS_CONTRACT,
		"entrypoint": entrypoint,
		"calldata": calldata
	}]
	var tx_result = _controller.execute(calls)
	var result_str = str(tx_result) if tx_result != null else ""
	print("[Dojo] Controller TX result: ", result_str)
	if result_str == "" or result_str == "null":
		# Execution failed, try sozo fallback
		push_warning("[Dojo] Controller execute returned empty, falling back to sozo")
		_execute_sozo(entrypoint, calldata)
		return
	tx_completed.emit(entrypoint, true, result_str)

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

	# Use active account's credentials if not default
	if active_account_index > 0 and active_account_index < accounts.size():
		args.append("--account-address")
		args.append(accounts[active_account_index]["address"])
		args.append("--private-key")
		args.append(accounts[active_account_index]["private_key"])

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
