
local ListButton = mainForm:GetChildChecked( "ListButton", true )

----------------------------------------------------------------------------------------------------
-- AddonManager support

function onMemUsageRequest( params )
	userMods.SendEvent( "U_EVENT_ADDON_MEM_USAGE_RESPONSE",
		{ sender = common.GetAddonName(), memUsage = gcinfo() } )
end

function onToggleDND( params )
	if params.target == common.GetAddonName() then
		DnD:Enable( ListButton, params.state )
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
-- AOPanel support

local IsAOPanelEnabled = GetConfig( "EnableAOPanel" ) or GetConfig( "EnableAOPanel" ) == nil

function onAOPanelStart( params )
	if IsAOPanelEnabled then
		local SetVal = { val = userMods.ToWString( "B" ) }
		local params = { header = SetVal, ptype = "button", size = 32 }
		userMods.SendEvent( "AOPANEL_SEND_ADDON",
			{ name = common.GetAddonName(), sysName = common.GetAddonName(), param = params } )

		ListButton:Show( false )
	end
end

function onAOPanelLeftClick( params )
	if params.sender == common.GetAddonName() then
		onShowList();
	end
end

function onAOPanelChange( params )
	if params.unloading and params.name == "UserAddon/AOPanelMod" then
		ListButton:Show( true )
	end
end

function enableAOPanelIntegration( enable )
	IsAOPanelEnabled = enable
	SetConfig( "EnableAOPanel", enable )

	if enable then
		onAOPanelStart()
	else
		ListButton:Show( true )
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

-- first letter -> corresponding stat
local statIdTable = {}
if avatar.GetSpellInfo then -- AO 4.0
	statIdTable = {
		[ "\243" ] = INNATE_STAT_PRECISION, -- удача о_О
		[ "\241" ] = INNATE_STAT_STRENGTH, -- сила
		[ "\242" ] = INNATE_STAT_MIGHT, -- точность -_-
		[ "\235" ] = INNATE_STAT_DEXTERITY, -- ловкость
		[ "\240" ] = INNATE_STAT_INTELLECT, -- разум
		[ "\232" ] = INNATE_STAT_INTUITION, -- интуиция
		[ "\228" ] = INNATE_STAT_SPIRIT -- дух
	}
else
	statIdTable = {
		[ "\236" ] = ENUM_InnateStats_Plain, -- мастерство
		[ "\240" ] = ENUM_InnateStats_Rage, -- решимость
		[ "\225" ] = ENUM_InnateStats_Finisher, -- беспощадность
		[ "\255" ] = ENUM_InnateStats_Lethality, -- ярость
		[ "\241" ] = ENUM_InnateStats_Vitality, -- стойкость
		[ "\226" ] = ENUM_InnateStats_Will, -- воля
		[ "\234" ] = ENUM_InnateStats_Lifesteal, -- кровожадность
		[ "\251" ] = ENUM_InnateStats_Endurance, -- выдержка
	}
end

function multByTalents( statId, arg )
	if not avatar.GetSpellInfo then -- AO 5.0
		return math.ceil(arg)
	end

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
	if cmd == "/buildmanager" or cmd == "\\buildmanager" then
		local _, _, option, value = string.find( iter(), "(%w*)=(%w*)" )
		if option == "aopanel" then
			enableAOPanelIntegration( value == "true" )
		end
		return
	elseif cmd ~= "/\241\242\224\242" and cmd ~= "\\\241\242\224\242" then
		return
	end

	local commands = {}
	for w in iter do
		local _, _, stat, op, arg = string.find( w, "^([\192-\255])([+=]+)(%d*)" )

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

function GetLocalizedText()
	local localization = options.GetOptionsByCustomType( "interface_option_localization" )
	local text = nil
	if localization then
		for _, id in localization do
			local info = options.GetOptionInfo( id )
			if info.values and info.baseIndex then
				local locName = userMods.FromWString( info.values[info.baseIndex].name )
				text = common.GetAddonRelatedTextGroup( locName )
			end
		end
	end
	return text or common.GetAddonRelatedTextGroup( "eng" )
end

local BuildsMenu = nil
local Localization = GetLocalizedText()

function onSaveBuild( params )
	local wtEdit = params.widget:GetParent():GetChildChecked( "BuildNameEdit", true )
	local text = userMods.FromWString( wtEdit:GetText() )

	if text ~= "" then
		if string.find( text, "allodswiki.ru/" ) then
			local build = ImportBuild( text )
			if build then
				LoadBuild( build )
			end
			onShowList()
		else
			SaveCurrentBuild( text )
			onShowList()
			onShowList()
		end
	end
end

function createLinkEdit( buildIndex )
	local desc = mainForm:GetChildChecked( "WikiLinkEdit", false ):GetWidgetDesc()
	local linkEdit = mainForm:CreateWidgetByDesc( desc )
	linkEdit:SetText( userMods.ToWString( ExportBuild( BuildsTable[ buildIndex ] ) ) )
	return linkEdit
end

function onShowList( params )
	if not BuildsMenu or not BuildsMenu:IsValid() then
		local menu = {}
		for i, v in ipairs( BuildsTable ) do
			local index = i
			menu[i] = {
				name = userMods.ToWString( v.name ),
				onActivate = function() LoadBuild( BuildsTable[ index ] ) end,
				submenu = {
					{ name = Localization:GetText( "rename" ),
						onActivate = function() onRenameBuild( index ) end },
					{ name = Localization:GetText( "delete" ),
						onActivate = function() DeleteBuild( index ); onShowList(); onShowList() end },
					{ name = Localization:GetText( "update" ),
						onActivate = function() UpdateBuild( index ) end },
					{ name = Localization:GetText( "link" ),
						submenu = { { createWidget = function() return createLinkEdit( index ) end } } },
				}
			}
		end
		local desc = mainForm:GetChildChecked( "SaveBuildTemplate", false ):GetWidgetDesc()
		table.insert( menu, { createWidget = function() return mainForm:CreateWidgetByDesc( desc ) end } )

		if ListButton:IsVisible() then
			local pos = ListButton:GetPlacementPlain()
			BuildsMenu = ShowMenu( { x = pos.posX, y = pos.posY + pos.sizeY }, menu )
		else
			BuildsMenu = ShowMenu( { x = 0, y = 32 }, menu )
		end
		BuildsMenu:GetChildChecked( "BuildNameEdit", true ):SetFocus( true )
	else
		DestroyMenu( BuildsMenu )
		BuildsMenu = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Renaming

local RenameBuildIndex = nil

function GetMenuItem( index )
	local children = BuildsMenu:GetNamedChildren()
	table.sort( children,
		function( a, b )
			if a:GetName() == "ItemEditTemplate" then return false end
			if b:GetName() == "ItemEditTemplate" then return true end
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

	local edit = BuildsMenu:GetChildChecked( "ItemEditTemplate", false )
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

	local edit = BuildsMenu:GetChildChecked( "ItemEditTemplate", false )
	edit:Show( false )
	edit:Enable( false )

	BuildsMenu:GetChildChecked( "BuildNameEdit", true ):SetFocus( true )
	RenameBuildIndex = nil
end

function onRenameAccept( params )
	local edit = BuildsMenu:GetChildChecked( "ItemEditTemplate", false )
	BuildsTable[ RenameBuildIndex ].name = userMods.FromWString( edit:GetText() )
	SaveBuildsTable()
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
	LoadBuildsTable()

	DnD:Init( 527, ListButton, ListButton, true )

	common.RegisterEventHandler( onInfoRequest, "SCRIPT_ADDON_INFO_REQUEST" )
	common.RegisterEventHandler( onMemUsageRequest, "U_EVENT_ADDON_MEM_USAGE_REQUEST" )
	common.RegisterEventHandler( onToggleDND, "SCRIPT_TOGGLE_DND" )
	common.RegisterEventHandler( onToggleVisibility, "SCRIPT_TOGGLE_VISIBILITY" )

	common.RegisterEventHandler( onSlashCommand, "EVENT_UNKNOWN_SLASH_COMMAND" )

	common.RegisterEventHandler( onAOPanelStart, "AOPANEL_START" )
	common.RegisterEventHandler( onAOPanelLeftClick, "AOPANEL_BUTTON_LEFT_CLICK" )
	common.RegisterEventHandler( onAOPanelChange, "EVENT_ADDON_LOAD_STATE_CHANGED" )

	common.RegisterReactionHandler( onSaveBuild, "SaveBuildReaction" )
	common.RegisterReactionHandler( onShowList, "ShowBuildsReaction" )
	common.RegisterReactionHandler( onRenameCancel, "RenameCancelReaction" )
	common.RegisterReactionHandler( onRenameAccept, "RenameBuildReaction" )
	common.RegisterReactionHandler( onRenameFocus, "RenameFocusChanged" )
	common.RegisterReactionHandler( onShowList, "WikiEscReaction" )

	InitMenu()
end

Init()

