----------------------------------------------------------------------------------------------------
-- AddonManager support

function onMemUsageRequest( params )
    userMods.SendEvent( "U_EVENT_ADDON_MEM_USAGE_RESPONSE", { sender = common.GetAddonName(), memUsage = gcinfo() } )
end

function onToggleDND( params )
    if params.target == common.GetAddonName() then
        DnD:Enable( mainForm:GetChildChecked( "ListButton", true ), params.state )
    end
end

function onToggleVisibility( params )
	if params.target == common.GetAddonName() then
		mainForm:Show( params.state == true )
	end
end

function onInfoRequest( params )
	if params.target == common.GetAddonName() then
		userMods.SendEvent( "SCRIPT_ADDON_INFO_RESPONSE", {
			sender = params.target,
			desc = "",
			showDNDButton = true,
			showHideButton = true,
			showSettingsButton = false,
		} )
	end
end

----------------------------------------------------------------------------------------------------
-- Stats distribution
-- Adds a slash command "/стат" with 1 or more parameters of the form:
-- <letter>=<number> (make a stat equal to <number>)
-- <letter>+<number> (add <number> points to stat)
-- <letter>++ (put all remaining points into stat)
-- where <letter> is the first letter of the stat name
-- Example:
-- /стат и=720 у+40 р++
-- this makes intuition equal to 720, adds 40 points to precision and puts all the rest into intelligence

local statIdTable = {
	-- first letter -> corresponding stat
	[ "\243" ] = INNATE_STAT_PRECISION, -- удача о_О
	[ "\241" ] = INNATE_STAT_STRENGTH, -- сила
	[ "\242" ] = INNATE_STAT_MIGHT, -- точность -_-
	[ "\235" ] = INNATE_STAT_DEXTERITY, -- ловкость
	[ "\240" ] = INNATE_STAT_INTELLECT, -- разум
	[ "\232" ] = INNATE_STAT_INTUITION, -- интуиция
	[ "\228" ] = INNATE_STAT_SPIRIT -- дух
}

function multByTalents( statId, arg )
	-- calculate stat multiplier from talents
	-- x points put into stat add x*statMultiplier points
	local equipBonus = avatar.GetInnateStats()[ statId ].base + avatar.GetInnateStats()[ statId ].equipment
	local talentBonus = avatar.GetInnateStats()[ statId ].talents

	local fairyInfo = unit.GetFairyInfo( avatar.GetId() )
	if fairyInfo ~= nil and fairyInfo.bonusStat == statId then
		talentBonus = talentBonus - fairyInfo.bonusStatValue
		equipBonus = equipBonus + fairyInfo.bonusStatValue
	end

	if avatar.GetContainerItem( DRESS_SLOT_TRINKET, ITEM_CONT_EQUIPMENT ) ~= nil then
		talentBonus = talentBonus - guild.GetTabardBonus().characteristicPercent
	end

	local statMultiplier = ( equipBonus + talentBonus ) / equipBonus
	return math.floor( arg / statMultiplier + 0.5 )
end

-- Parse a slash command
function onSlashCommand( params )
	local iter = string.gfind( userMods.FromWString( params.text ), "[^%s]+")

	local cmd = iter()
	if cmd ~= "/\241\242\224\242" and cmd ~= "\\\241\242\224\242" then
		return
	end

	local statsCount = avatar.GetCurrencyInfo( avatar.GetCurrencyId( "stat_point" ) ).value
	local commands = {}
	for w in iter do
		local count, len, stat, op, arg = string.find( w, "^([\192-\255])([+=]+)(%d*)" )

		local statId = statIdTable[ stat ]
		local toAdd = 0
		if op == "++" then
			toAdd = statsCount
		elseif op == "+" then
			toAdd = multByTalents( statId, arg )
		elseif op == "=" then
			toAdd = multByTalents( statId, arg - avatar.GetInnateStats()[ statId ].effective )
		end
		toAdd = math.min( statsCount, toAdd )
		statsCount = statsCount - toAdd

		commands[ statId ] = toAdd
	end
	avatar.ImproveInnateStats( commands )
end

----------------------------------------------------------------------------------------------------

function Init()
	LoadBuildTable()

	InitList()
	ActivateItemHandler = LoadBuild
	DeleteItemHandler = DeleteBuild
	AddItemHandler = SaveCurrentBuild

	for i, build in ipairs( BuildsTable ) do
		AddListItem( build.name )
	end

	DnD:Init( 527, mainForm:GetChildChecked( "ListButton", true ), mainForm:GetChildChecked( "ListControl", true ), true )

	common.RegisterEventHandler( onInfoRequest, "SCRIPT_ADDON_INFO_REQUEST" )
	common.RegisterEventHandler( onMemUsageRequest, "U_EVENT_ADDON_MEM_USAGE_REQUEST" )
	common.RegisterEventHandler( onToggleDND, "SCRIPT_TOGGLE_DND" )
	common.RegisterEventHandler( onToggleVisibility, "SCRIPT_TOGGLE_VISIBILITY" )

	common.RegisterEventHandler( onSlashCommand, "EVENT_UNKNOWN_SLASH_COMMAND" );
end

Init()

