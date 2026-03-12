# arcana_resolver.gd
class_name ArcanaResolver extends RefCounted

var host: SimHost
var catalog: ArcanaCatalog

func _init(_host: SimHost, _catalog: ArcanaCatalog) -> void:
	host = _host
	catalog = _catalog

func run_proc(proc: int) -> void:
	if host == null or host.main.state == null or host.main.api == null:
		return
	if catalog == null:
		push_warning("ArcanaResolverSim: catalog is null")
		return
	
	var arcanum_type := _proc_to_arcanum_type(proc)
	if arcanum_type < 0:
		return
	var ran := 0
	var writer : BattleEventWriter = host.main.api.writer
	for entry: ArcanaState.ArcanumEntry in host.main.state.arcana.list:
		if entry == null:
			continue
		if int(entry.type) != arcanum_type:
			continue
		
		var id := entry.id
		if id == &"":
			continue
		
		var proto: Arcanum = catalog.get_proto(id)
		if proto == null:
			push_warning("ArcanaResolverSim: missing proto for id=%s" % String(id))
			continue
		#print("[SIM][ARCANA] -> id=%s type=%s" % [String(entry.id), Arcanum.Type.keys()[int(entry.type)]])
		ran += 1
		
		# if ("writer" in host.main.api) else null
		#var scope_id := 0
		var player_id := int(host.main.state.groups[0].player_id)
		if writer != null:# and writer.has_method("begin_scope"):
			# actor_id: usually player_id for friendly-owned arcana; keep consistent with your earlier ctx params
			
			writer.scope_begin(
				Scope.Kind.ARCANUM,
				"id=%s" % String(id),
				player_id,
				{}
			)
		
		var ctx := ArcanumContext.new()
		ctx.api = host.main.api
		
		# Headless context params
		ctx.params[Keys.MODE] = Keys.MODE_SIM
		ctx.params[Keys.PLAYER_ID] = host.main.state.groups[0].player_id
		ctx.params[Keys.SOURCE_ID] = host.main.state.groups[0].player_id
		ctx.params[Keys.GROUP_INDEX] = 0
		
		if ctx.api.writer != null:
			ctx.api.writer.emit_arcanum_proc(ctx.params[Keys.SOURCE_ID], id, proc)
		#if writer != null and proto.wants_in_beat():
			#writer.emit_arcanum_prep(player_id, id, proc)
		#if writer != null and proto.wants_out_beat():
			#writer.emit_arcanum_wrapup(player_id, id, proc)
		var r = proto.activate_arcanum(ctx)
		
		# policy: headless arcana must be sync
		if r is Signal and !(r as Signal).is_null():
			push_warning("ArcanaResolverSim: arcana %s returned Signal; ignored" % String(id))
		elif typeof(r) == TYPE_OBJECT and r != null and r.get_class() == "GDScriptFunctionState":
			push_warning("ArcanaResolverSim: arcana %s returned FunctionState; ignored" % String(id))
		if writer != null:# and writer.has_method("end_scope") and scope_id != 0:
			writer.scope_end()


func _proc_to_arcanum_type(proc: int) -> int:
	match proc:
		TurnEngineCore.ArcanaProc.START_OF_COMBAT:
			return int(Arcanum.Type.START_OF_COMBAT)
		TurnEngineCore.ArcanaProc.START_OF_TURN:
			return int(Arcanum.Type.START_OF_TURN)
		TurnEngineCore.ArcanaProc.END_OF_TURN:
			return int(Arcanum.Type.END_OF_TURN)
		_:
			return -1
