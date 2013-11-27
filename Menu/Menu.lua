-- Functions for menu creation and manipulation
-- A menu is defined by a table of menu items, which can contain the following fields
-- (none are required):
-- {
--	 name = "item",						-- menu item text
--	 onActivate = func,					-- function to be called when the item is clicked
--	 submenu = { }						-- a submenu to be opened on click. If onActivate is also present
--	 									-- then	the arrow must be clicked to open submenu
--	 createWidget = function() CreateWidgetByDesc(desc) end	-- custom menu item, no other fields are used
-- }
--
-- Usage example:
--	local menu = {
--		{ name = "option1", onActivate = function() LogInfo( "", "option1 clicked" ) end }
--		{ name = "option2", onActivate = function() LogInfo( "", "option2 clicked" ) end }
--		{ name = "submenu",
--			submenu = {
--				{ name = "suboption1" }
--				{ name = "suboption2" }
--	} } }
--	ShowMenu( { x = 100, y = 100 }, menu )

local Actions = {} -- maps widget to action executed upon clicking it

-- templates for creating menu parts
local MenuTemplate = mainForm:GetChildChecked( "MenuTemplate", true ):GetWidgetDesc()
local ItemTemplate = mainForm:GetChildChecked( "ItemTemplate", true ):GetWidgetDesc()
local SubmenuTemplate = mainForm:GetChildChecked( "SubmenuTemplate", true ):GetWidgetDesc()
local CombinedTemplate = mainForm:GetChildChecked( "CombinedTemplate", true ):GetWidgetDesc()

function ShowMenu( screenPosition, menu, parent )
	local menuWidget = mainForm:CreateWidgetByDesc( MenuTemplate )
	mainForm:AddChild( menuWidget )

	local menuPlacement = menuWidget:GetPlacementPlain()
	local margin = menuPlacement.sizeY / 2
	local width = 0
	local height = margin

	for _, item in ipairs( menu ) do
		local itemWidget
		if item.createWidget then
			itemWidget = item.createWidget()
		else
			itemWidget = CreateItemWidget( item )
		end

		local placement = itemWidget:GetPlacementPlain()
		placement.posY = height
		itemWidget:SetPlacementPlain( placement )
		height = height + placement.sizeY
		width = math.max( width, placement.sizeX );

		menuWidget:AddChild( itemWidget )
		itemWidget:Show( true )
	end

	local menuPlacement = menuWidget:GetPlacementPlain()
	menuPlacement.posX = screenPosition.x
	menuPlacement.posY = screenPosition.y
	menuPlacement.sizeX = width + margin * 2
	menuPlacement.sizeY = height + margin
	MakeVisible( menuPlacement )
	menuWidget:SetPlacementPlain( menuPlacement )

	SaveAction( menuWidget, { parentMenu = parent and parent:GetInstanceId(), childMenu = nil } )
	menuWidget:Show( true )
	return menuWidget
end

function DestroyMenu( menuWidget )
	local childMenu = Actions[ menuWidget:GetInstanceId() ].childMenu
	if childMenu then
		DestroyMenu( childMenu )
	end

	ClearActions( menuWidget )
	menuWidget:DestroyWidget()
end

----------------------------------------------------------------------------------------------------

function SaveAction( widget, action )
	Actions[ widget:GetInstanceId() ] = action
end

function ClearActions( widget )
	local name = widget:GetInstanceId()
	if Actions[ name ] then
		Actions[ name ] = nil
	end

	local children = widget:GetNamedChildren()
	for _, child in pairs( children ) do
		ClearActions( child )
	end
end

function CreateItemWidget( item )
	local widget
	if item.submenu and item.onActivate then
		widget = mainForm:CreateWidgetByDesc( CombinedTemplate )
		widget:GetChildChecked( "CombinedItem", true ):SetVal( "button_label", item.name )
		SaveAction( widget:GetChildChecked( "CombinedItem", true ), item.onActivate )
		SaveAction( widget:GetChildChecked( "CombinedSubmenu", true ), item.submenu )
	elseif item.submenu then
		widget = mainForm:CreateWidgetByDesc( SubmenuTemplate )
		widget:SetVal( "button_label", item.name )
		SaveAction( widget, item.submenu )
	else
		widget = mainForm:CreateWidgetByDesc( ItemTemplate )
		widget:SetVal( "button_label", item.name )
		if item.onActivate then
			SaveAction( widget, item.onActivate )
		end
	end

	return widget
end

function GetParentMenu( childWidget )
	local menu = childWidget
	while menu:GetParent():GetInstanceId() ~= mainForm:GetInstanceId() do
		menu = menu:GetParent()
	end
	return menu
end

function MakeVisible( placement )
	local posConverter = widgetsSystem:GetPosConverterParams()
	if placement.posX + placement.sizeX > posConverter.fullVirtualSizeX then
		placement.posX = posConverter.fullVirtualSizeX - placement.sizeX
	end
	if placement.posY + placement.sizeY > posConverter.fullVirtualSizeY then
		placement.posY = posConverter.fullVirtualSizeY - placement.sizeY
	end
end

----------------------------------------------------------------------------------------------------
-- Reaction handlers

function OnActivate( params )
	if params.active and not IsDragging() then
		local action = Actions[ params.widget:GetInstanceId() ]

		local menu = GetParentMenu( params.widget )
		local parentMenuInfo = Actions[ Actions[ menu:GetInstanceId() ].parentMenu ]
		if parentMenuInfo then
			parentMenuInfo.childMenu = nil
		end
		DestroyMenu( menu )

		if action then
			action()
		end
	end
end

function OnOpenSubmenu( params )
	if params.active then
		local action = Actions[ params.widget:GetInstanceId() ]
		if action then
			local wt = params.widget
			local pos = { x = wt:GetPlacementPlain().sizeX, y = 0 }
			while wt do
				local placement = wt:GetPlacementPlain()
				pos.x = pos.x + placement.posX
				pos.y = pos.y + placement.posY
				wt = wt:GetParent()
			end

			local menuWidget = GetParentMenu( params.widget )
			local menuInfo = Actions[ menuWidget:GetInstanceId() ]
			if menuInfo.childMenu then
				DestroyMenu( menuInfo.childMenu )
				menuInfo.childMenu = nil
			end
			menuInfo.childMenu = ShowMenu( pos, action, menuWidget )
		end
	end
end

function OnCloseSubmenu( params )
	if params.active then
		local menuWidget = GetParentMenu( params.widget )
		local menuInfo = Actions[ menuWidget:GetInstanceId() ]
		if menuInfo.childMenu then
			DestroyMenu( menuInfo.childMenu )
			menuInfo.childMenu = nil
		end
	end
end

----------------------------------------------------------------------------------------------------

function InitMenu()
	common.RegisterReactionHandler( OnActivate, "MenuActivateItemReaction" )
	common.RegisterReactionHandler( OnOpenSubmenu, "MenuOpenSubmenuReaction" )
	common.RegisterReactionHandler( OnOpenSubmenu, "SubmenuMouseOverReaction" )
	common.RegisterReactionHandler( OnCloseSubmenu, "ItemMouseOverReaction" )
end
