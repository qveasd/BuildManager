-- Import and export to/from external formats

function ImportBuild( link )
	return ImportWikiLink( link ) or ImportWikiLinkOld( link )
end

function ExportBuild( build )
	return ExportWikiLink( build )
end

----------------------------------------------------------------------------------------------------
-- link format:
-- pts.allodswiki.ru/calc#!<class>!<talents>!<field1>!<field2>!<field3>
-- <class> - integer class id
-- <talents> - a letter for each skill (36 total), "." - not learned, otherwise skill level
-- <fieldN> - <left> "/" <RIGHT>
-- <left> - Make a 32-bit number from field talents row-wise from center (bit0) to upper left
--					corner (bit31). Store it in base-26 with lowercase letters as digits, little-endian.
-- <RIGHT> - Make a 32-bit number from field talents row-wise from center (bit0) to lower right
--					 corner (bit31). Store it in base-26 with uppercase letters as digits, little-endian.

local classIdTable = {
	DRUID	= "5",
	MAGE	= "2",
	NECROMANCER	= "4",
	PALADIN	= "7",
	PRIEST	= "3",
	PSIONIC	= "6",
	STALKER	= "8",
	WARRIOR	= "1",
	BARD	= "9",
	ENGINEER = "10"
}

function tonumber26( s )
	if s == "a" then
		return 1
	end

	local n = 0
	for i = string.len( s ), 1, -1 do
		n = n * 26 + string.byte( s, i ) - string.byte( "a" )
	end
	return n
end

function tostring26( n )
	local s = ""
	while n > 0 do
		s = s .. string.char( string.byte( "a" ) + mod( n, 26 ) )
		n = math.floor( n / 26 )
	end
	return s
end

function indexToPos( index )
	local size = avatar.GetFieldTalentTableSize()
	local offset = math.floor( size.columnsCount * size.rowsCount / 2 )
	return { x = mod( index + offset, size.columnsCount ),
			 y = math.floor( (index + offset) / size.columnsCount ) }
end

function ImportWikiLink( link )
	local build = { talents = {}, fieldTalents = {}, binding = {} }

	local iter = string.gmatch( link, "!([^!]+)")
	iter() -- skip class id

	local talents = iter()
	if not talents then
		return nil
	end
	local size = avatar.GetBaseTalentTableSize()
	for i = 1, string.len( talents ) do
		local ch = string.sub( talents, i, i )
		if not string.find( ".123", ch ) then
			return nil
		end

		if ch ~= "." then
		local key = TalentKey( math.floor( (i - 1) / size.linesCount ), mod( i - 1, size.linesCount ) )
			build.talents[ key ] = tonumber( ch ) - 1
		end
	end

	local size = avatar.GetFieldTalentTableSize()
	for field = 0, size.fieldsCount - 1 do
		local str = iter()
		if not str then
			return nil
		end

		local _, _, left, right = string.find( str, "(%a+)/(%a+)" )
		if left == nil or right == nil then
			return nil
		end

		left = tonumber26( left )
		right = tonumber26( string.lower( right ) )
		for i = 0, math.floor( size.columnsCount * size.rowsCount / 2 ) do
			if mod( left, 2 ) > 0 then
				local p = indexToPos( -i )
				build.fieldTalents[ FieldTalentKey( field, p.y, p.x ) ] = true
			end
			left = math.floor( left / 2 )

			if mod( right, 2 ) > 0 then
				local p = indexToPos( i )
				build.fieldTalents[ FieldTalentKey( field, p.y, p.x ) ] = true
			end
			right = math.floor( right / 2 )
		end
	end

	return build
end

function ExportWikiLink( build )
	local link = "http://pts.allodswiki.ru/calc#!" .. classIdTable[ avatar.GetClass() ] .. "!"

	local size = avatar.GetBaseTalentTableSize()
	for layer = 0, size.layersCount - 1 do
		for line = 0, size.linesCount - 1 do
			local rank = build.talents[ TalentKey( layer, line ) ]
			if rank then
				link = link .. ( rank + 1 )
			else
				link = link .. "."
			end
		end
	end

	local size = avatar.GetFieldTalentTableSize()
	for field = 0, size.fieldsCount - 1 do
		local left = 0
		local right = 0
		for i = math.floor( size.columnsCount * size.rowsCount / 2 ), 1, -1 do
				local lp = indexToPos( -i )
				if build.fieldTalents[ FieldTalentKey( field, lp.y, lp.x ) ] then
					left = left + 1
				end
				left = left * 2

				local rp = indexToPos( i )
				if build.fieldTalents[ FieldTalentKey( field, rp.y, rp.x ) ] then
					right = right + 1
				end
				right = right * 2
		end

		link = link .. "!" .. tostring26( left ) .. "/" .. string.upper( tostring26( right ) )
	end

	return link
end

----------------------------------------------------------------------------------------------------
-- Create a link to the build for the allodswiki.ru build calculator

function ExportWikiLinkOld( build )
	local classIdTable = {
		DRUID		= "_new#5",
		MAGE		= "_new#2",
		NECROMANCER	= "_new#4",
		PALADIN		= "#7",
		PRIEST		= "#3",
		PSIONIC		= "#6",
		STALKER		= "#8",
		WARRIOR		= "#1",
		BARD		= "#9"
	}

	local codes = "abcdefghijklmnopqrstuvwxyz" .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .. "0123456789-"
	function Code( index )
		return string.sub( codes, index + 1, index + 1 )
	end

	local link = "http://www.allodswiki.ru/talents"
			.. classIdTable[ avatar.GetClass() ] .. "_"

	local size = avatar.GetBaseTalentTableSize()
	for layer = 0, size.layersCount - 1 do
		for line = 0, size.linesCount - 1 do
			local rank = build.talents[ TalentKey( layer, line ) ]
			if rank then
				link = link .. Code( layer * size.linesCount + line ) .. ( rank + 1 )
			end
		end
	end

	local size = avatar.GetFieldTalentTableSize()
	for field = 0, size.fieldsCount - 1 do
		link = link .. "_"

		for row = 0, size.rowsCount - 1 do
			for col = 0, size.columnsCount - 1 do
				if build.fieldTalents[ FieldTalentKey( field, row, col ) ] then
					link = link .. Code( row * size.columnsCount + col )
				end
			end
		end
	end

	return link .. "_1" -- 0: build is editable; 1: build is locked.
end

----------------------------------------------------------------------------------------------------

function mod( a, b )
	return a - math.floor(a/b) * b
end

-- Import build from a link to allodswiki.ru.
-- Only talents and field talents are filled.
function ImportWikiLinkOld( link )
	local build = {}
	build.talents = {}
	build.fieldTalents = {}
	build.binding = {}

	local codes = "abcdefghijklmnopqrstuvwxyz" .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .. "0123456789-"
	function Number( code )
		local n = string.find( codes, code )
		return n and n - 1
	end

	local iter = string.gmatch( string.gsub( link, ".*#", "" ), "_[%a%d-]+")

	local size = avatar.GetBaseTalentTableSize()
	local talents = iter()
	if not talents then
		return nil
	end
	for i = 2, string.len( talents ), 2 do
		local skill = Number( string.sub( talents, i, i ) )
		local rank = tonumber( string.sub( talents, i + 1, i + 1 ) )
		if not skill or not rank or rank < 1 or rank > 3 then
			return nil
		end

		local key = TalentKey( math.floor( skill / size.linesCount ), mod( skill, size.linesCount ) )
		build.talents[ key ] = rank - 1
	end
	for i = 0, 2 do
		if not build.talents[ TalentKey( 0, i ) ] then
			return nil
		end
	end

	local size = avatar.GetFieldTalentTableSize()
	for field = 0, size.fieldsCount - 1 do
		local talents = iter()
		for i = 2, string.len( talents ) do
			local talent = Number( string.sub( talents, i, i ) )
			if not talent then
				return nil
			end

			local key = FieldTalentKey( field, math.floor(talent / size.columnsCount), mod( talent, size.columnsCount ) )
			build.fieldTalents[ key ] = true
		end
	end
	for i = 0, size.fieldsCount - 1 do
		local key = FieldTalentKey( i, math.floor( size.rowsCount / 2 ), math.floor( size.columnsCount / 2 ) )
		if not build.fieldTalents[ key ] then
			return nil
		end
	end

	return build
end

