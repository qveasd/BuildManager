-- Drop-down list control.
-- A button that shows a drop-down list when clicked. Each list item has a text, a button for
-- activating an item, and a button to delete the item. At the bottom of the list there's an
-- edit control and a save button to add new items to the list.
--
-- Usage: put list control on your widget, call InitList() and overload the needed handlers

Global( "WtList", nil )
Global( "WtBaseListItem", nil ) -- serves as a template for creating new list items

Global( "IsListVisible", false )
Global( "MaxItemsCount", 11 )

----------------------------------------------------------------------------------------------------
-- Handlers.

function ActivateItemHandler( index )
end

-- Called before the item is deleted
function DeleteItemHandler( index )
end

-- Called after item is added. Item is added to the end of the list.
function AddItemHandler( text )
end

----------------------------------------------------------------------------------------------------

function ItemsCount()
	return GetTableSize( WtList:GetNamedChildren() ) - 3 -- minus template, edit and a button
end

function AddListItem( text )
	-- Make a copy of item template
	local desc = WtBaseListItem:GetWidgetDesc()
	local wtItem = mainForm:CreateWidgetByDesc( desc )
	wtItem:SetName( tostring( ItemsCount() + 1 ) )
	WtList:AddChild( wtItem )

	-- Set item text
	local valuedText = common.CreateValuedText()
	valuedText:SetFormat( userMods.ToWString( "<h1>" .. text .. "</h1>" ) )
	local wtText = wtItem:GetChildChecked( "ListItemText", false )
	wtText:SetValuedText( valuedText )

	SetItemPlacement( wtItem )
	SetListPlacement()
	wtItem:Show( true )
end

function DeleteListItem( index )
	local wtItem = mainForm:GetChildChecked( tostring( index ), true )
	wtItem.DestroyWidget( wtItem )

	for i = index + 1, 100500 do
		-- Shift controls after deleted item up.
		local wtItem = mainForm:GetChildUnchecked( tostring( i ), true )
		if not wtItem then
			SetListPlacement()
			return
		end

		wtItem:SetName( tostring( i - 1 ) )
		SetItemPlacement( wtItem )
	end
end

function ClearList()
	for i = 1, 100500 do
		local wtItem = mainForm:GetChildUnchecked( tostring( i ), true )
		if not wtItem then
			return
		end

		wtItem.DestroyWidget( wtItem )
	end
	SetListPlacement()
end

-- Show/hide list
function OnShowList( params )
	WtList:Show( not IsListVisible )
	IsListVisible = not IsListVisible
	SetControlPlacement()

	if IsListVisible then
		mainForm:GetChildChecked( "ListItemName", true ):SetFocus( true )
	end
end

----------------------------------------------------------------------------------------------------
-- Internal

function SetItemPlacement( wtItem )
	local index = tonumber( wtItem:GetName() )
	local basePlacement = WtBaseListItem:GetPlacementPlain()

	local itemPlacement = wtItem:GetPlacementPlain()
	itemPlacement.posY = basePlacement.posY + ( index - 1 ) * basePlacement.sizeY

	wtItem:SetPlacementPlain( itemPlacement )
end

function SetListPlacement()
	local listPlacement = WtList:GetPlacementPlain()
	local itemPlacement = WtBaseListItem:GetPlacementPlain()

	listPlacement.sizeY = ( 1 + ItemsCount() ) * itemPlacement.sizeY + 2 * itemPlacement.posY
	WtList:SetPlacementPlain( listPlacement )

	SetControlPlacement()
end

function SetControlPlacement()
	local wtControl = mainForm:GetChildChecked( "ListControl", true )
	local placement = wtControl:GetPlacementPlain()
	if IsListVisible then
		local listPlacement = WtList:GetPlacementPlain()
		placement.sizeX = listPlacement.sizeX
		placement.sizeY = listPlacement.posY + listPlacement.sizeY
	else
		local buttonPlacement = mainForm:GetChildChecked( "ListButton", true ):GetPlacementPlain()
		placement.sizeX = buttonPlacement.sizeX
		placement.sizeY = buttonPlacement.sizeY
	end
	wtControl:SetPlacementPlain( placement )
end

----------------------------------------------------------------------------------------------------
-- Reaction handlers

function OnActivateItem( params )
	if params.active then
		local index = tonumber( params[ "widget" ]:GetParent():GetName() )

		ActivateItemHandler( index )
	end
end

function OnDeleteItem( params )
	if params.active then
		local index = tonumber( params[ "widget" ]:GetParent():GetName() )

		DeleteItemHandler( index )
		DeleteListItem( index )
	end
end

function OnAddItem( params )
	local wtEdit = mainForm:GetChildChecked( "ListItemName", true )
	local text = userMods.FromWString( wtEdit:GetText() )

	if text ~= "" then
		AddListItem( text )
		wtEdit:SetText( userMods.ToWString( "" ) )

		AddItemHandler( text )
	end
end

----------------------------------------------------------------------------------------------------

function InitList()
	common.RegisterReactionHandler( OnShowList, "ListButtonReaction" ) 
	common.RegisterReactionHandler( OnActivateItem, "ActivateItemReaction" ) 
	common.RegisterReactionHandler( OnDeleteItem, "DeleteItemReaction" ) 
	common.RegisterReactionHandler( OnAddItem, "AddItemReaction" ) 

	WtList = mainForm:GetChildChecked( "ListPanel", true )
	WtBaseListItem = mainForm:GetChildChecked( "ListItem", true )
end

