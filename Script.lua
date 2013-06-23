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

	local commands = {}
	for w in iter do
		local count, len, stat, op, arg = string.find( w, "^([\192-\255])([+=]+)(%d*)" )

		local statId = statIdTable[ stat ]
		if statId then
			local toAdd = 0
			if op == "++" then
				toAdd = avatar.GetFreeStatPointsToDistribute()
			elseif op == "+" then
				toAdd = multByTalents( statId, arg )
			elseif op == "=" then
				toAdd = multByTalents( statId, arg - avatar.GetInnateStats()[ statId ].effective )
			end
			toAdd = math.min( toAdd, avatar.GetFreeStatPointsToDistribute() )

			avatar.ImproveInnateStat( statId, toAdd )
		end
	end
	avatar.DistributeStatPoints()
end

----------------------------------------------------------------------------------------------------

Global( "BuildsMenu", nil )

function onSaveBuild( params )
	local wtEdit = params.widget:GetParent():GetChildChecked( "BuildNameEdit", true )
	local text = userMods.FromWString( wtEdit:GetText() )

	if text ~= "" then
		SaveCurrentBuild( text )
		onShowList()
		onShowList()
	end
end

function onShowList( params )
	if not BuildsMenu or not BuildsMenu:IsValid() then
		local menu = {}
		for i, v in ipairs( BuildsTable ) do
			local index = i

			local subMenu = {
				{ name = "Rename", onActivate = function() onRenameBuild( index ) end },
				{ name = "Delete", onActivate = function() DeleteBuild( index ); onShowList(); onShowList() end },
				{ name = "Export" },
			}

			menu[i] = {
				name = v.name,
				onActivate = function() LoadBuild( index ) end,
				submenu = subMenu
			}
		end
		local desc = mainForm:GetChildChecked( "SaveBuildTemplate", false ):GetWidgetDesc()
		table.insert( menu, { widget = mainForm:CreateWidgetByDesc( desc ) } )

		local pos = mainForm:GetChildChecked( "ListButton", true ):GetPlacementPlain()
		BuildsMenu = ShowMenu( { x = pos.posX, y = pos.posY + pos.sizeY }, menu )
		BuildsMenu:GetChildChecked( "BuildNameEdit", true ):SetFocus( true )
	else
		DestroyMenu( BuildsMenu )
		BuildsMenu = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Renaming

Global( "RenameBuildIndex", nil )

function GetMenuItem( index )
	local children = BuildsMenu:GetNamedChildren()
	table.sort( children,
		function( a, b )
			if a:GetName() == "MenuItemEditTemplate" then return false end
			if b:GetName() == "MenuItemEditTemplate" then return true end
			return a:GetPlacementPlain().posY < b:GetPlacementPlain().posY
		end )
	return children[ index ]
end

function onRenameBuild( index )
	if RenameBuildIndex then
		onRenameCancel()
	end

	RenameBuildIndex = index

	local item = GetMenuItem( index )
	item:Show( false )

	local edit = BuildsMenu:GetChildChecked( "MenuItemEditTemplate", false )
	edit:SetText( userMods.ToWString( BuildsTable[ index ].name ) )
	edit:SetPlacementPlain( item:GetPlacementPlain() )
	edit:Show( true )
	edit:Enable( true )
	edit:SetFocus( true )
	BuildsMenu:GetChildChecked( "BuildNameEdit", true ):SetFocus( false )
end

function onRenameCancel( params )
	local item = GetMenuItem( RenameBuildIndex )
	item:Show( true )

	local edit = BuildsMenu:GetChildChecked( "MenuItemEditTemplate", false )
	edit:Show( false )
	edit:Enable( false )

	BuildsMenu:GetChildChecked( "BuildNameEdit", true ):SetFocus( true )
	RenameBuildIndex = nil
end

function onRenameAccept( params )
	local edit = BuildsMenu:GetChildChecked( "MenuItemEditTemplate", false )
	BuildsTable[ RenameBuildIndex ].name = userMods.FromWString( edit:GetText() )
	SaveBuildTable()
	RenameBuildIndex = nil

	onShowList()
	onShowList()
end

function onRenameFocus( params )
	if not params.active then
		onRenameAccept( params )
	end
end

----------------------------------------------------------------------------------------------------

function Init()
	LoadBuildTable()

	local button = mainForm:GetChildChecked( "ListButton", true )
	DnD:Init( 527, button, button, true )

	common.RegisterEventHandler( onInfoRequest, "SCRIPT_ADDON_INFO_REQUEST" )
	common.RegisterEventHandler( onMemUsageRequest, "U_EVENT_ADDON_MEM_USAGE_REQUEST" )
	common.RegisterEventHandler( onToggleDND, "SCRIPT_TOGGLE_DND" )
	common.RegisterEventHandler( onToggleVisibility, "SCRIPT_TOGGLE_VISIBILITY" )

	common.RegisterEventHandler( onSlashCommand, "EVENT_UNKNOWN_SLASH_COMMAND" );

	common.RegisterReactionHandler( onSaveBuild, "SaveBuildReaction" )
	common.RegisterReactionHandler( onShowList, "ShowBuildsReaction" )
	common.RegisterReactionHandler( onRenameCancel, "RenameCancelReaction" )
	common.RegisterReactionHandler( onRenameAccept, "RenameBuildReaction" )
	common.RegisterReactionHandler( onRenameFocus, "RenameFocusChanged" )

	InitMenu()
end

Init()

