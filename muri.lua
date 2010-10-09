package.path = 'libs/?/init.lua;libs/?.lua;' .. package.path
local metadata = require'metadata'
local lfs = require'lfs'

local _USAGE = [[Usage: muri DIRECTORY...
Recursively iterates the DIRECTORY(ies) and validate the media files based on
defined rules.

Currently supports:
 - Formats: FLAC, Ogg
 - Metadata: VorbisComment]]

local print = function(fmt, ...)
	print(string.format('muri: ' .. fmt, ...))
end

if(not ...) then
	print(_USAGE)
else
	for i=1, select('#', ...) do
		local dir = select(i, ...)
		local mode = lfs.attributes(dir, 'mode')
		if(mode ~= 'directory') then
			return print("`%s' is not a directory.", dir)
		end
	end
end
