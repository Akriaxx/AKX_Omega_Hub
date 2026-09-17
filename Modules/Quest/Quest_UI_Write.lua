local J = Quest
J.Write = {}
local W = J.Write

-- Les séquences couleur, textures et caractères UTF-8 sont indivisibles.
function W:Tokens(text)
    local tokens, pos = {}, 1
    while pos <= #text do
        local tail, token = text:sub(pos)
        token = tail:match("^|c%x%x%x%x%x%x%x%x") or tail:match("^|r") or tail:match("^|T.-|t") or tail:match("^||")
        if not token then
            local byte = text:byte(pos)
            local length = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
            token = text:sub(pos, pos + length - 1)
        end
        tokens[#tokens + 1] = token
        pos = pos + #token
    end
    return tokens
end

function W:StopSound(frame)
    if frame.quillHandle then StopSound(frame.quillHandle, 100); frame.quillHandle = nil end
end

function W:Stop(frame)
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    self:StopSound(frame)
    frame.writing = nil
end

function W:Finish(frame)
    if frame.writing then frame.writing.label:SetText(frame.writing.text) end
    self:Stop(frame)
end

function W:Start(frame, label, text)
    self:Stop(frame)
    local state = { label = label, text = text, tokens = self:Tokens(text), position = 0, elapsed = 0, sound = 2 }
    frame.writing = state
    label:SetText("")
    frame:SetScript("OnUpdate", function(_, dt)
        state.elapsed, state.sound = state.elapsed + dt, state.sound + dt
        if state.sound >= 1.35 then
            self:StopSound(frame)
            local played, handle = PlaySoundFile(J.Style.quill, "SFX")
            if played then frame.quillHandle = handle end
            state.sound = 0
        end
        local position = math.min(#state.tokens, math.floor(state.elapsed * 55))
        if position ~= state.position then
            state.position = position
            label:SetText(table.concat(state.tokens, "", 1, position) .. "|r")
        end
        if position >= #state.tokens then self:Finish(frame) end
    end)
end
