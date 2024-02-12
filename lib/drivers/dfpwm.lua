local dfpwm = require("cc.audio.dfpwm")

local driverType = "dfpwm"

local Track = {}

local function playAudio(speakers, sample)
    if speakers.isMono then
        return speakers.left.playAudio(sample)
    end

    return speakers.left.playAudio(sample) and speakers.right.playAudio(sample)
end

local function stopAudio(speakers)
    speakers.left.stop()
    if speakers.isMono then
        return
    end
    speakers.right.stop()
end

function Track:run()
    while not self.disposed do
        while self.state == "paused" do
            os.pullEvent("quartz_play")
        end
        local chunk = self.handle.read(self.blockSize)
        if not chunk then
            break
        end

        local sample = self.decoder(chunk)
        while self.state ~= "paused" and not self.disposed and not playAudio(self.speakers, sample) do
            os.pullEvent("speaker_audio_empty")
            sleep(0.5)
        end
    end

    os.queueEvent("quartz_driver_end")
end

function Track:getMeta()
    return {
        artist = "Unknown artist",
        title = "Unknown title",
        album = "Unknown album",
        size = self.size,
        length = self.size / 6000,
    }
end

function Track:getState()
    return self.state
end

function Track:getPosition()
    return self.handle.seek("cur")
end

function Track:setPosition(pos)
    if pos < 0 then
        pos = 0
    end
    self.handle.seek("set", pos * 6000)
end

function Track:play()
    self.state = "running"
    os.queueEvent("speaker_audio_empty")
    os.queueEvent("quartz_play")
end

function Track:pause()
    self.state = "paused"
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
end

function Track:stop()
    self.state = "paused"
    self.handle.seek("set", 0)
    os.queueEvent("quartz_pause")
    stopAudio(self.speakers)
end

function Track:dispose()
    self.disposed = true
    self.handle.close()
end

local function new(drive, speakers)
    local drivePath = drive.getMountPath()
    local handle = fs.open(fs.combine(drivePath, "audio.dfpwm"), "rb")
    local size = handle.seek("end")
    handle.seek("set", 0)

    local track = {
        state = "paused",
        blockSize = 1024 * 16,
        type = driverType,
        decoder = dfpwm.make_decoder(),
        filePath = filePath,
        speakers = speakers,
        handle = handle,
        size = size,
        disposed = false,
    }

    setmetatable(track, {__index = Track})
    return track
end

local function checkCompatibility(drive)
    if not drive.hasData() then
        return false
    end

    local path = drive.getMountPath()
    if fs.exists(fs.combine(path, "audio.dfpwm")) then
        return true, 0
    end
    return false
end

return {
    new = new,
    type = driverType,
    checkCompatibility = checkCompatibility,
}