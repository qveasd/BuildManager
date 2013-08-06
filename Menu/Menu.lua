-- Functions for menu creation and manipulation
-- A menu is a table of menu items, which can contain the following fields (none are required):
-- {
--	 name = "item",						-- menu item text
--	 onActivate = func,					-- function to be called when the item is clicked
--	 submenu = { }						-- a submenu to be opened on click. If onActivate is also present
--	 									-- then	the arrow must be clicked to open submenu
--	 widget = CreateWidgetByDesc(...)	-- custom menu item, no other fields are used
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

function ShowMenu( screenPosition, menu, parent )
	local menuWidget = mainForm:CreateWidgetByDesc( MenuTemplate )
	mainForm:AddChild( menuWidget )

	local menuPlacement = menuWidget:GetPlacementPlain()
	local margin = menuPlacement.sizeY / 2
	local height = margin

	for _, item in ipairs( menu ) do
		local itemWidget = item.widget or CreateItemWidget( item )

		local placement = itemWidget:GetPlacementPlain()
		placement.posY = height
		itemWidget:SetPlacementPlain( placement )
		height = height + placement.sizeY

		menuWidget:AddChild( itemWidget )
		itemWidget:Show( true )
	end

	local menuPlacement = menuWidget:GetPlacementPlain()
	menuPlacement.posX = screenPosition.x
	menuPlacement.posY = screenPosition.y
	menuPlacement.sizeY = height + margin
	MakeVisible( menuPlacement )
	menuWidget:SetPlacementPlain( menuPlacement )

	SaveAction( menuWidget, { parentMenu = parent and parent:GetName(), childMenu = nil } )
	menuWidget:Show( true )
	return menuWidget
end

function DestroyMenu( menuWidget )
	local childMenu = Actions[ menuWidget:GetName() ].childMenu
	if childMenu then
		DestroyMenu( childMenu )
	end

	ClearActions( menuWidget )
	menuWidget:DestroyWidget()
end

----------------------------------------------------------------------------------------------------

Global( "Actions", {} )

Global( "MenuTemplate", nil )
Global( "MenuItemTemplate", nil )		-- serves as a template for creating new list items
Global( "MenuSubmenuTemplate", nil )	-- template for submenus
Global( "MenuCombinedTemplate", nil ) -- template for an item with submenu

function SaveAction( widget, action )
	local name = tostring( math.random() )
	Actions[ name ] = action
	widget:SetName( name )
end

function ClearActions( widget )
	local name = widget:GetName()
	if Actions[ name ] then
		Actions[ name ] = nil
	end

	local children = widget:GetNamedChildren()
	for _, child in ipairs( children ) do
		ClearActions( child )
	end
end

function CreateItemWidget( item )
	local text = userMods.ToWString( item.name .. string.rep( " ", 40 ) ) -- poor man's left align

	local widget
	if item.submenu and item.onActivate then
		widget = mainForm:CreateWidgetByDesc( MenuCombinedTemplate )
		widget:GetChildChecked( "ItemTextSmall", true ):SetVal( "button_label", text )
		SaveAction( widget:GetChildChecked( "ItemTextSmall", true ), item.onActivate )
		SaveAction( widget:GetChildChecked( "SubmenuButtonSmall", true ), { menu = item.submenu } )
	elseif item.submenu then
		widget = mainForm:CreateWidgetByDesc( MenuSubmenuTemplate )
		widget:SetVal( "button_label", text )
		SaveAction( widget, { menu = item.submenu } )
	else
		widget = mainForm:CreateWidgetByDesc( MenuItemTemplate )
		widget:SetVal( "button_label", text )
		if item.onActivate then
			SaveAction( widget, item.onActivate )
		end
	end

	return widget
end

function GetParentMenu( childWidget )
	local menu = childWidget
	while not mainForm:GetChildUnchecked( menu:GetName(), false ) do
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
	if params.active then
		local action = Actions[ params.widget:GetName() ]
		if action then
			action()
		end

		local menu = GetParentMenu( params.widget )
		local parentMenuInfo = Actions[ Actions[ menu:GetName() ].parentMenu ]
		if parentMenuInfo then
			parentMenuInfo.childMenu = nil
		end
		DestroyMenu( menu )
	end
end

function OnOpenSubmenu( params )
	if params.active then
		local action = Actions[ params.widget:GetName() ]
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
			local menuInfo = Actions[ menuWidget:GetName() ]
			if menuInfo.childMenu then
				DestroyMenu( menuInfo.childMenu )
			end
			menuInfo.childMenu = ShowMenu( pos, action.menu, menuWidget )
		end
	end
end

----------------------------------------------------------------------------------------------------

function InitMenu()
	MenuItemTemplate = mainForm:GetChildChecked( "MenuItemTemplate", true ):GetWidgetDesc()
	MenuSubmenuTemplate = mainForm:GetChildChecked( "MenuItemSubmenuTemplate", true ):GetWidgetDesc()
	MenuCombinedTemplate = mainForm:GetChildChecked( "MenuItemCombinedTemplate", true ):GetWidgetDesc()
	MenuTemplate = mainForm:GetChildChecked( "MenuTemplate", true ):GetWidgetDesc()

	common.RegisterReactionHandler( OnActivate, "MenuActivateItemReaction" )
	common.RegisterReactionHandler( OnOpenSubmenu, "MenuOpenSubmenuReaction" )
	common.RegisterReactionHandler( OnOpenSubmenu, "MouseOverReaction" )
end
