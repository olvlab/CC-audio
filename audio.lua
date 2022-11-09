local args = {...}

local oldPull = os.pullEvent
os.pullEvent = os.pullEventRaw

local dfpwm = require 'cc.audio.dfpwm'
local dataSize = 16 * 1024
local decoder = dfpwm.make_decoder()

local speaker, path, volume = nil, nil, 1
if #args > 0 then
	local a, b, c = table.unpack(args)
	local _b, _c = tonumber(b), tonumber(c)
	if _c then
		speaker, path, volume = a, b, _c
	elseif not c and _b then
		path, volume = a, _b
	elseif b and not _b then
		speaker, path = a, b
	else
		path = a
	end
	
	speaker = speaker and peripheral.wrap(speaker) or peripheral.find('speaker')
else
	error('usage: speaker [side] <path> [volume]')
end

assert(speaker, 'Speaker not found')
local pType = peripheral.getType(speaker)
assert(pType == 'speaker', 'Expected speaker, got ' .. pType)

local frames = ''
local sub = path:sub(1, 7)
if sub == 'http://' or sub == 'https:/' then
	print('Attempting HTTP')
	
	local valid, err = http.checkURL(path)
	assert(valid, err)
	
	local response, err = http.get(path, {}, true)
	assert(response, err)
	while true do
		local line = response.readLine(true)
		if not line then break end
		frames = frames .. line
	end
else
	for chunk in io.lines(path..'.dfpwm') do
		frames = frames .. chunk
	end
end

print('Playing audio on speaker ' .. peripheral.getName(speaker))
parallel.waitForAny(
	function()
		for pos = 1, #frames, dataSize do
			while not speaker.playAudio(decoder(frames:sub(pos, pos + dataSize - 1)), volume) do
				os.pullEvent('speaker_audio_empty')
			end
		end
	end,
	function()
		while true do
			if os.pullEventRaw('terminate') then
				print('Stopping')
				speaker.stop()
				break
			end
		end
	end
)

print('Playback ended')
os.pullEvent = oldPull