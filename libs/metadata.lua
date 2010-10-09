local vstruct = require'vstruct'
local vUnpack = vstruct.unpack

--[[
 http://www.xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-810005
 The comment header is decoded as follows:

  1) [vendor_length] = read an unsigned integer of 32 bits
  2) [vendor_string] = read a UTF-8 vector as [vendor_length] octets
  3) [user_comment_list_length] = read an unsigned integer of 32 bits
  4) iterate [user_comment_list_length] times {

       5) [length] = read an unsigned integer of 32 bits
       6) this iteration's user comment = read a UTF-8 vector as [length] octets

     }

  7) [framing_bit] = read a single bit as boolean
  8) if ( [framing_bit] unset or end of packet ) then ERROR
  9) done.
]]

local _EMPTY = {}
local vorbiscomment_unpack = function(fd)
	local vendorLength = vUnpack('< u4', fd, true)
	local vendorString = vUnpack('< s' .. vendorLength, fd, true)

	local numComments = vUnpack('< u4', fd, true)
	if(numComments > 0) then
		local comments = {}

		for i=1, numComments do
			local length = vUnpack('< u4', fd, true)
			local key, value = vUnpack('< s' .. length, fd, true):match('([^=]*)=(.*)')

			-- For consistency
			key = key:lower()
			if(not comments[key]) then comments[key] = {} end

			table.insert(comments[key], value)
		end

		return comments
	else
		return _EMPTY
	end
end

-- http://www.xiph.org/vorbis/doc/Vorbis_I_spec.html
-- http://www.xiph.org/ogg/doc/framing.html
local ogg_read_page = function(fd)
	local magicNumber, version = vUnpack('s4 u1', fd, true)
	if(magicNumber ~= 'OggS') then
		return nil, 'Not an Ogg file container.'
	end

	if(version ~= 0) then
		return nil, 'Ogg version not supported.'
	end

	local headerType, granulePosition, serialNumber, pageSequenceNumber,
	checksum, numSegmenst = vUnpack('< u1 u8 u4 u4 u4 u1', fd, true)

	local segments = {[1]=0}
	for i=1, numSegmenst do
		local segment = vUnpack('< u1', fd, true)
		segments[#segments] = segments[#segments] + segment
		if(segment < 255 and i ~= numSegmenst) then
			table.insert(segments, 0)
		end
	end

	for i=1, #segments do
		segments[i] = fd:read(segments[i])
	end

	return segments
end

local _MAGIC = {
	-- http://flac.sourceforge.net/format.html
	fLaC = function(fd)
		repeat
			local blockType, lastBlock, blockLength = vUnpack('> [1| u7 u1] u3', fd, true)
			if(lastBlock == 1) then return _EMPTY end
			if(blockType == 4) then
				return vorbiscomment_unpack(fd)
			end
		until not fd:read(blockLength)
	end,

	OggS = function(fd)
		-- Reset the cursor.
		fd:seek'set'

		while(true) do
			local page = ogg_read_page(fd)
			if(page and page[1]:byte(1) == 0x3 and page[1]:sub(2, 7) == 'vorbis') then
				return vorbiscomment_unpack(vstruct.cursor(page[1]:sub(8)))
			end
		end
	end,
}

local readMetadata = function(fd, keepOpen)
	if(type(fd) == 'string') then
		fd = io.open(fd)
	end

	local magicNumber = fd:read(4)
	local metadata
	if(_MAGIC[magicNumber]) then
		metadata = _MAGIC[magicNumber](fd)
	end

	if(not keepOpen) then
		fd:close()
	end

	return metadata
end

return {read = readMetadata}
