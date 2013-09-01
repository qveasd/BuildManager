-- Import and export to/from external formats


-- Create a link to the build for the allodswiki.ru build calculator
function ExportWikiLink( build )
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

	local codes = "abcdefghijklmnopqrstuvwxyz" .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .. "0123456789"
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
function ImportWikiLink( link )
	local build = {}
	build.talents = {}
	build.fieldTalents = {}
	build.binding = {}

	local codes = "abcdefghijklmnopqrstuvwxyz" .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .. "0123456789"
	function Number( code )
		return string.find( codes, code ) - 1
	end

	local iter = string.gfind( string.gsub( link, ".*#", "" ), "_[%a%d]+")

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
