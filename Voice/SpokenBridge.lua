-- "Listen": replay a quest's voiced lines through Spoken's queue (so nothing talks over
-- anything). Spoken ships generated voice-overs per quest. If it has none for a quest, fall
-- back to the client's built-in text-to-speech reading the journal text.
local _, LW = ...

local V = {}
LW.Voice = V

local ACCEPT, COMPLETE = 1, 3

-- Spoken_Quests runs in its own environment, the global `VoiceOver` (Spoken_Quests\Environment.lua);
-- Spoken's core uses `SpokenEnv`. The quest player lives in VoiceOver.
local function env()
  for _, name in ipairs({ "VoiceOver", "SpokenEnv" }) do
    local E = rawget(_G, name)
    if type(E) == "table" and E.Player and E.DataModules and E.Enums and E.Enums.SoundEvent then return E end
  end
  return nil
end

local function soundData(E, questId, event)
  local e = LW.Index:Get(questId)
  return {
    event = event == "complete" and (E.Enums.SoundEvent.QuestComplete or COMPLETE) or (E.Enums.SoundEvent.QuestAccept or ACCEPT),
    questID = questId,
    title = e and e.name or nil,
    name = "Unknown Name",
    origin = "Lorewalker",
  }
end

--- Does Spoken have a clip for this quest line? event: "accept" | "complete"
-- Only "yes" is cached for good: Spoken loads its voice packs on demand, so an early "no"
-- may turn into "yes" later. A "no" is re-asked after a few seconds.
local clipCache = {}
function V:HasClip(questId, event)
  local key = questId .. (event or "accept")
  local cached = clipCache[key]
  if cached == true then return true end
  if cached and GetTime() < cached then return false end
  local E = env()
  if not E then return false end
  local ok, found = pcall(E.DataModules.PrepareSound, E.DataModules, soundData(E, questId, event))
  if ok and found then clipCache[key] = true return true end
  clipCache[key] = GetTime() + 30
  return false
end

--- `/lw voice [questId]`: walk through every step and print what happens.
function V:Diagnose(questId)
  local function say(...) LW:Print("|cffffffff[voice]|r", ...) end
  if not questId then
    local cur = LW.Router.current
    questId = cur and cur.quest.id
  end
  if not questId then return say("No quest given and no current step. Use /lw voice <questId>.") end
  local e = LW.Index:Get(questId)
  say("quest", questId, e and e.name or "(not indexed)")
  local which
  for _, name in ipairs({ "VoiceOver", "SpokenEnv" }) do
    local t = rawget(_G, name)
    say(name, type(t) == "table" and ("present, Player=" .. tostring(t.Player ~= nil) .. ", DataModules=" .. tostring(t.DataModules ~= nil)) or "missing")
    if not which and type(t) == "table" and t.Player and t.DataModules then which = t end
  end
  local E = env()
  if not E then
    say("Spoken_Quests environment not usable -> falling back to text-to-speech")
  else
    local n = 0
    if E.DataModules.GetModules then for _ in E.DataModules:GetModules() do n = n + 1 end end
    say("voice packs registered:", n, " player source:", tostring(E.Player.source ~= nil))
    for _, ev in ipairs({ "accept", "complete" }) do
      local sd = soundData(E, questId, ev)
      local ok, found, why = pcall(E.DataModules.PrepareSound, E.DataModules, sd)
      say(ev, "lookup:", tostring(ok), tostring(found), tostring(why or ""), sd.filePath and ("file " .. sd.filePath) or "")
    end
  end
  local tts = C_VoiceChat and C_VoiceChat.SpeakText and C_VoiceChat.GetTtsVoices
  local voices = tts and C_VoiceChat.GetTtsVoices()
  say("built-in TTS:", tts and "available" or "missing", "voices:", voices and #voices or 0,
    "helper:", tostring(TextToSpeech_Speak ~= nil),
    "volume:", tostring(C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume()))
  local page = LW.Journal:Get(questId)
  say("journal text:", page and page.detail and "yes" or "no")
  say("playing now ->", tostring(self:Play(questId, "accept")))
end

-- Text-to-speech through Blizzard's own helper (TextToSpeechFrame), which knows this client's
-- C_VoiceChat.SpeakText signature (it changed between clients: passing the old shape to the
-- new one gives volume 0, i.e. silence) and uses the player's TTS voice, speed and volume.
local function tts(text)
  if not (text and C_VoiceChat and C_VoiceChat.SpeakText) then return false end
  local voiceType = Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard or 0
  local voice = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType)
  if not voice and C_VoiceChat.GetTtsVoices then
    local voices = C_VoiceChat.GetTtsVoices()
    voice = voices and voices[1]
  end
  if not voice then return false end
  -- This client's signature is (voiceID, text, rate, volume, overlap) (EllesmereUI uses the
  -- same). overlap = true: after a Stop the engine may still think it is speaking, and with
  -- overlap off it silently drops the new line (Blizzard's helper passes false).
  local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
  local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
  if volume <= 0 then volume = 100 end
  if pcall(C_VoiceChat.SpeakText, voice.voiceID, text, rate, volume, true) then return true end
  return TextToSpeech_Speak and pcall(TextToSpeech_Speak, text, voice) or false
end

---------------------------------------------------------------------------------------------
-- Playback state, so Listen can be a Play / Stop toggle.
--   V.playing = { questId, event, kind = "spoken"|"tts", clip = soundData }
---------------------------------------------------------------------------------------------

local function changed()
  LW:Fire("VOICE_STATE", V.playing)
end

local function spokenAPI() return rawget(_G, "Spoken") end

local function spokenClipActive(clip)
  local S = spokenAPI()
  if not (S and S.GetCurrent and clip) then return false end
  local ok, current = pcall(S.GetCurrent, S)
  return ok and current == clip
end

-- TTS start/finish events, and a light poll for Spoken's queue while one of ours is on.
local watcher = CreateFrame("Frame")
for _, ev in ipairs({ "VOICE_CHAT_TTS_PLAYBACK_STARTED", "VOICE_CHAT_TTS_PLAYBACK_FINISHED", "VOICE_CHAT_TTS_PLAYBACK_FAILED" }) do
  pcall(watcher.RegisterEvent, watcher, ev)
end
watcher:SetScript("OnEvent", function(_, ev, ...)
  local a, b, c = ...
  LW:Log("voice", "%s %s %s %s (playing: %s)", ev:gsub("VOICE_CHAT_TTS_PLAYBACK_", ""), tostring(a), tostring(b), tostring(c),
    V.playing and V.playing.kind or "none")
  if ev ~= "VOICE_CHAT_TTS_PLAYBACK_STARTED" and V.playing and V.playing.kind == "tts" then
    V.playing = nil
    changed()
  end
end)
local pollElapsed = 0
watcher:SetScript("OnUpdate", function(_, dt)
  local p = V.playing
  if not (p and p.kind == "spoken") then return end
  pollElapsed = pollElapsed + dt
  if pollElapsed < 0.4 then return end
  pollElapsed = 0
  if not spokenClipActive(p.clip) then
    V.playing = nil
    changed()
  end
end)

function V:IsPlaying(questId, event)
  local p = self.playing
  return p and p.questId == questId and (not event or p.event == event) and true or false
end

function V:Stop()
  local p = self.playing
  if not p then return end
  self.playing = nil
  if p.kind == "spoken" then
    local S = spokenAPI()
    if S and S.Skip and spokenClipActive(p.clip) then pcall(S.Skip, S) end
  else
    pcall(C_VoiceChat.StopSpeakingText)
    self.stoppedAt = GetTime()
  end
  LW:Log("voice", "stopped %d %s", p.questId, p.event)
  changed()
end

--- Listen buttons call this: stop if this line is playing, else play it.
function V:Toggle(questId, event)
  LW:Log("voice", "toggle %d %s: playing=%s", questId, tostring(event), tostring(self:IsPlaying(questId, event)))
  if self:IsPlaying(questId, event) then
    self:Stop()
  else
    self:Stop()
    self:Play(questId, event)
  end
end

--- Play a quest line. Returns "spoken", "tts" or nil.
function V:Play(questId, event)
  event = event or "accept"
  -- Right after a TTS stop the client is still cancelling; a new line sent now gets cancelled
  -- too. Wait a moment.
  if self.stoppedAt and GetTime() - self.stoppedAt < 0.4 then
    C_Timer.After(0.4, function() V:Play(questId, event) end)
    return "pending"
  end
  local E = env()
  if not E then LW:Log("voice", "Spoken_Quests environment not found") end
  if E and self:HasClip(questId, event) then
    local clip = soundData(E, questId, event)
    local ok, queued = pcall(E.Player.PlayNow, E.Player, clip)
    LW:Log("voice", "spoken %d %s: ok=%s queued=%s", questId, event, tostring(ok), tostring(queued))
    if ok and queued then
      self.playing = { questId = questId, event = event, kind = "spoken", clip = clip }
      changed()
      return "spoken"
    end
  end
  local page = LW.Journal:Get(questId)
  local text = page and (event == "complete" and page.complete or page.detail)
  if tts(text) then
    LW:Log("voice", "tts %d %s", questId, event)
    self.playing = { questId = questId, event = event, kind = "tts" }
    changed()
    return "tts"
  end
  LW:Log("voice", "nothing played for %d %s (text %s, C_VoiceChat.SpeakText %s)", questId, event,
    text and "yes" or "no", tostring(C_VoiceChat and C_VoiceChat.SpeakText ~= nil))
  LW:Print("No voice-over for this quest line.")
  return nil
end

function V:CanPlay(questId, event)
  if self:HasClip(questId, event) then return true end
  local page = LW.Journal:Get(questId)
  return page and (event == "complete" and page.complete or page.detail) and C_VoiceChat and C_VoiceChat.SpeakText and true or false
end
