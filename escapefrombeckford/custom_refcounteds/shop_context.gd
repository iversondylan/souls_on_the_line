# shop_context.gd
class_name ShopContext extends RefCounted

var run: Run
var run_account: RunAccount
var player_data: PlayerData
var arcana_system: ArcanaSystem
var arcana_catalog: ArcanaCatalog
var arcana_reward_pool: ArcanaRewardPool

var card_offers: Array[CardData] = []
var arcanum_offers: Array[Arcanum] = []
