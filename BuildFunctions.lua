
-- BuildsTable - table: index (int) -> build
-- 	build - table of:
-- 		name - build name, string
-- 		talents - table: TalentKey( row, line ) -> talent_rank
-- 		fieldTalents - table: FieldTalentKey( field, row, line ) -> true if the talent is learned
-- 		binding - table: action_index -> { action_type (enum), bound_object_name (string) }
Global( "BuildsTable", {} )

----------------------------------------------------------------------------------------------------
-- Save/Load

function SaveBuildsTable()
	userMods.SetAvatarConfigSection( "ZBuilds", BuildsTable )
end

function LoadBuildsTable()
	BuildsTable = userMods.GetAvatarConfigSection( "ZBuilds" )
	if not BuildsTable then
		BuildsTable = {}
	end
end

----------------------------------------------------------------------------------------------------

function AddPanelCompatibility( params )
	if BuildsTable[ params.index ] then
		if not BuildsTable[ params.index ].binding then
			BuildsTable[ params.index ].binding = {}
		end
		for i = 1, params.size do
			if params.binding[ i ] then
				BuildsTable[ params.index ].binding[ i + 100 ] =
					{ type = params.binding[ i ].type, name = params.binding[ i ].name }
			else
				BuildsTable[ params.index ].binding[ i + 100 ] = nil
			end
		end
		SaveBuildsTable()
	end
end
common.RegisterEventHandler( AddPanelCompatibility, "ADD_PANEL_ANSWER_BUILD" )

function SaveCurrentBuild( name )
	local build = {}
	build.name = name
	SaveBaseTalents( build )
	SaveFieldTalents( build )
	SaveKeyBinding( build )

	table.insert( BuildsTable, build )
	SaveBuildsTable()
	userMods.SendEvent( "BUILD_MANAGER_REQUEST_BILD", { index = table.getn(BuildsTable) } )
end

function UpdateBuild( index )
	SaveBaseTalents( BuildsTable[ index ] )
	SaveFieldTalents( BuildsTable[ index ] )
	SaveKeyBinding( BuildsTable[ index ] )
	SaveBuildsTable()
	userMods.SendEvent( "BUILD_MANAGER_REQUEST_BILD", { index = index } )
end

function LoadBuild( build )
	local freeRubies = avatar.GetViewedBuildFreeRubyPoints()
	local freeTalents = avatar.GetViewedBuildFreeTalentPoints()
	local learnedTalentsCount = LoadBaseTalents( build )
	local learnedFieldsCount = LoadFieldTalents( build )

	if learnedTalentsCount <= freeTalents and learnedFieldsCount <= freeRubies and
		(learnedTalentsCount > 0 or learnedFieldsCount > 0) then
		-- Wait until skills get learned, then bind the keys.
		function OnTalentsLoaded()
			LoadKeyBinding( build )
			common.UnRegisterEventHandler( OnTalentsLoaded, "EVENT_TALENTS_CHANGED" )
			userMods.SendEvent( "BUILD_MANAGER_LOAD_BUILD", { binding = build.binding } )
		end

		common.RegisterEventHandler( OnTalentsLoaded, "EVENT_TALENTS_CHANGED" ) 
		avatar.ApplyStoredTalents()
	else
		if learnedTalentsCount > 0 or learnedFieldsCount > 0 then
			avatar.ApplyStoredTalents() -- as a way of cancelling changes
		end
		LoadKeyBinding( build )
		userMods.SendEvent( "BUILD_MANAGER_LOAD_BUILD", { binding = build.binding } )
	end
end

function DeleteBuild( index )
	table.remove( BuildsTable, index )
	SaveBuildsTable()
end

----------------------------------------------------------------------------------------------------
-- Base talents save/load

function TalentKey( layer, line )
	return layer * 100 + line
end

function SaveBaseTalents( build )
	build.talents = {}

	local size = avatar.GetBaseTalentTableSize()
	for layer = 0, size.layersCount - 1 do
		for line = 0, size.linesCount - 1 do
			local talent = avatar.GetBaseTalentInfo( layer, line )
			if talent and talent.currentRank then
				build.talents[ TalentKey( layer, line ) ] = talent.currentRank
			end
		end
	end
end

function LoadBaseTalents( build )
	local learnedTalentsCount = 0

	local size = avatar.GetBaseTalentTableSize()
	for layer = 0, size.layersCount - 1 do
		for line = 0, size.linesCount - 1 do
			local rank = build.talents[ TalentKey( layer, line ) ]
			if rank then
				local curRank = avatar.GetBaseTalentInfo( layer, line ).currentRank
				if not curRank then
					curRank = -1
				end

				for i = curRank, rank - 1 do
					avatar.StoreBaseTalent( layer, line )
					learnedTalentsCount = learnedTalentsCount + i + 2
				end
			end
		end
	end

	return learnedTalentsCount
end

----------------------------------------------------------------------------------------------------
-- Field talents save/load

function FieldTalentKey( field, row, col )
	return field * 10000 + row * 100 + col
end

function SaveFieldTalents( build )
	build.fieldTalents = {}

	local size = avatar.GetFieldTalentTableSize()
	for field = 0, size.fieldsCount - 1 do
		for row = 0, size.rowsCount - 1 do
			for col = 0, size.columnsCount - 1 do
				local talent = avatar.GetFieldTalentInfo( field, row, col )
				if talent and talent.isLearned then
					build.fieldTalents[ FieldTalentKey( field, row, col ) ] = true
				end
			end
		end
	end
end

function FloodFillTalents( build, field )
	-- Flood-filling field talents starting from center of the field
	local size = avatar.GetFieldTalentTableSize()

	local center = { x = 0, y = 0 }
	-- 5.0: first talent is no longer necessarily in the center, so search for it
	for row = 0, size.rowsCount - 1 do
		for col = 0, size.columnsCount - 1 do
			local talent = avatar.GetFieldTalentInfo( field, row, col )
			if talent and talent.isLearned then
				center = { x = row, y = col }
				break;
			end
		end
	end

	local learnedTalents = { [ FieldTalentKey( field, center.x, center.y ) ] = true }
	local learnedFieldsCount = 0

	function ApplyAdjacentTalents( x, y )
		ApplyAdjacentTalent( x + 1, y )
		ApplyAdjacentTalent( x - 1, y )
		ApplyAdjacentTalent( x, y + 1 )
		ApplyAdjacentTalent( x, y - 1 )
	end

	function ApplyAdjacentTalent( x, y )
		local isInBuild = build.fieldTalents[ FieldTalentKey( field, x, y ) ]
		local isLearned = learnedTalents[ FieldTalentKey( field, x, y ) ]

		if isInBuild and not isLearned then
			local talent = avatar.GetFieldTalentInfo( field, x, y )
			if talent and not talent.isLearned then
				avatar.StoreFieldTalent( field, x, y )
				learnedFieldsCount = learnedFieldsCount + 1
			end
			learnedTalents[ FieldTalentKey( field, x, y ) ] = true

			ApplyAdjacentTalents( x, y )
		end
	end

	ApplyAdjacentTalents( center.x, center.y )
	return learnedFieldsCount
end

function LoadFieldTalents( build )
	local learnedFieldsCount = 0
	for field = 0, avatar.GetFieldTalentTableSize().fieldsCount - 1 do
		learnedFieldsCount = FloodFillTalents( build, field ) + learnedFieldsCount
	end
	return learnedFieldsCount
end


----------------------------------------------------------------------------------------------------
-- Key binding save/load

function MountSkinKey( skinId )
	local skinInfo = mount.GetSkinInfo( skinId )
	if skinInfo then
		local mountInfo = mount.GetInfo( skinInfo.mountId )
		if mountInfo then
			return userMods.FromWString( mountInfo.name ) .. "_" .. userMods.FromWString( skinInfo.name ) 
		end
	end
	return ""
end

function GetItemInfo( id )
	if avatar.GetItemInfo then -- pre 5.0.1
		return avatar.GetItemInfo( id )
	else
		return itemLib.GetItemInfo( id )
	end
end

function SaveKeyBinding( build )
	-- SpellId changes from session to session, sysName is empty for a lot of spells, so the only
	-- choice left for a permanent object identifier is objectInfo.name
	build.binding = {} -- table: action_index -> { action_type, action_name }

	local actionsCount = avatar.GetMaxActionCount()
	for i = 0, actionsCount - 1 do
		local action = avatar.GetActionInfo( i )
		if action then
			local actionName = ""
			if action.type == ACTION_TYPE_SPELL then
				local name;
				if avatar.GetSpellObjectInfo then
					name = avatar.GetSpellObjectInfo( action.id ).name
				else -- AO 5.0
					name = spellLib.GetDescription( spellLib.GetObjectSpell( action.id ) ).name
				end
				actionName = userMods.FromWString( name or "" )
			elseif action.type == ACTION_TYPE_ITEM then
				actionName = userMods.FromWString( GetItemInfo( action.id ).name or "" )
			elseif action.type == ACTION_TYPE_MOUNT then
				actionName = MountSkinKey( action.id )
			elseif action.type == ACTION_TYPE_EMOTE then
				actionName = userMods.FromWString( avatar.GetEmoteInfo( action.id ).name or "" )
			end
			build.binding[ i ] = { type = action.type, name = actionName }
		end
	end
end

function CollectObjectIds( objects, GetInfoFunc )
	local objectIds = {}

	for i, id in objects do
		local objectInfo = GetInfoFunc( id )
		if objectInfo then
			objectIds[ userMods.FromWString( objectInfo.name ) ] = id
		end
	end
	return objectIds
end

function CollectTrinketId( items, equipType )
	local trinkId = unit.GetEquipmentItemId( avatar.GetId(), DRESS_SLOT_TRINKET, equipType )
	if trinkId then
		local trinkInfo = GetItemInfo( trinkId )
		if trinkInfo then
			items[ userMods.FromWString( trinkInfo.name ) ] = trinkId
		end
	end
end

function CollectItemIds()
	local items = CollectObjectIds( avatar.GetInventoryItemIds(), GetItemInfo )
	CollectTrinketId( items, ITEM_CONT_EQUIPMENT )
	CollectTrinketId( items, ITEM_CONT_EQUIPMENT_RITUAL )
	return items
end

function CollectMountSkinIds()
	local skins = {}

	for i, mountId in mount.GetMounts() do
		for j, skinId in mount.GetMountSkins( mountId ) do
			local key = MountSkinKey( skinId )
			if key then
				skins[ key ] = skinId
			end

			-- previous version used only skin name as a key
			local skinInfo = mount.GetSkinInfo( skinId )
			if skinInfo then
				skins[ userMods.FromWString( skinInfo.name ) ] = skinId
			end
		end
	end
	return skins
end

function LoadKeyBinding( build )
	-- Collect objects that can be bound to the action panel. If an item isn't in the player's
	-- inventory anymore it won't get bound, but there seems to be no way of locating it.
	local spells = CollectObjectIds(
		avatar.GetSpellBook(), avatar.GetSpellInfo or spellLib.GetDescription)  -- AO 5.0
	local items = CollectItemIds()
	local emotes = CollectObjectIds( avatar.GetEmotes(), avatar.GetEmoteInfo )
	local mountSkins = CollectMountSkinIds()

	local actionsCount = avatar.GetMaxActionCount()
	for i = 0, actionsCount - 1 do
		local action = build.binding[ i ]
		if not build.binding[ i ] then
			avatar.UnBindFromActionPanel( i )
		elseif action.type == ACTION_TYPE_SPELL then
			if spells[ action.name ] then
				avatar.BindSpellToActionPanel( spells[ action.name ], i )
			else
				avatar.UnBindFromActionPanel( i )
			end
		elseif action.type == ACTION_TYPE_ITEM then
			if items[ action.name ] then
				avatar.BindItemToActionPanel( items[ action.name ], i )
			else
				avatar.UnBindFromActionPanel( i )
			end
		elseif action.type == ACTION_TYPE_EMOTE then
			if emotes[ action.name ] then
				avatar.BindEmoteToActionPanel( emotes[ action.name ], i )
			else
				avatar.UnBindFromActionPanel( i )
			end
		elseif action.type == ACTION_TYPE_MOUNT then
			if mountSkins[ action.name ] then
				avatar.BindMountSkinToActionPanel( mountSkins[ action.name ], i )
			else
				avatar.UnBindFromActionPanel( i )
			end
		end
	end
end

