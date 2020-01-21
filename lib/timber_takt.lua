--- Timber Engine lib
-- Engine params, functions and UI views.
--
-- @module TimberEngine
-- @release v1.0.0 Beta 6
-- @author Mark Eats
-- @minor tweaks for takt

local ControlSpec = require "controlspec"
local Formatters = require "formatters"
local MusicUtil = require "musicutil"
local UI = require "ui"
local Graph = require "graph"
local FilterGraph = require "filtergraph"
local EnvGraph = require "envgraph"

local Timber = {}

Timber.FileSelect = require "fileselect"

local SCREEN_FRAMERATE = 15

Timber.sample_changed_callback = function() end
Timber.meta_changed_callback = function() end
Timber.waveform_changed_callback = function() end
Timber.play_positions_changed_callback = function() end
Timber.views_changed_callback = function() end

Timber.setup_params_dirty = false
Timber.filter_dirty = false
Timber.env_dirty = false
Timber.lfo_functions_dirty = false
Timber.lfo_1_dirty = false
Timber.lfo_2_dirty = false
Timber.bpm = 120
Timber.display = "id" -- Can be "id", "note" or "none"
Timber.shift_mode = false
Timber.file_select_active = false

local samples_meta = {}
local specs = {}
local options = {}

local STREAMING_BUFFER_SIZE = 65536
local MAX_FRAMES = 2000000000

Timber.specs = specs
Timber.options = options
Timber.samples_meta = samples_meta
Timber.num_sample_params = 0

local param_ids = {
  "sample", "quality", "transpose", "detune_cents", "play_mode", "start_frame", "end_frame", "loop_start_frame", "loop_end_frame",
  "freq_mod_lfo_1", "freq_mod_lfo_2", "freq_mod_env",
  "filter_type", "filter_freq", "filter_resonance", "filter_freq_mod_lfo_1", "filter_freq_mod_lfo_2", "filter_freq_mod_env", "filter_freq_mod_vel", "filter_freq_mod_pressure", "filter_tracking",
  "pan", "pan_mod_lfo_1", "pan_mod_lfo_2", "pan_mod_env", "amp", "amp_mod_lfo_1", "amp_mod_lfo_2",
  "amp_env_attack", "amp_env_decay", "amp_env_sustain", "amp_env_release",
  "mod_env_attack", "mod_env_decay", "mod_env_sustain", "mod_env_release",
  "lfo_1_fade", "lfo_2_fade"
}
local extra_param_ids = {}
local beat_params = false

options.PLAY_MODE_BUFFER = {"Loop", "Inf. Loop", "Gated", "1-Shot"}
options.PLAY_MODE_BUFFER_DEFAULT = 1
options.PLAY_MODE_STREAMING = {"Loop", "Gated", "1-Shot"}
options.PLAY_MODE_STREAMING_DEFAULT = 1
options.PLAY_MODE_IDS = {{0, 1, 2, 3}, {1, 2, 3}}

options.SCALE_BY = {"Percentage", "Length", "Bars"}
options.SCALE_BY_NO_BARS = {"Percentage", "Length"}
specs.BY_PERCENTAGE = ControlSpec.new(10, 500, "lin", 0, 100, "%")

options.BY_BARS = {"1/64", "1/48", "1/32", "1/24", "1/16", "1/12", "1/8", "1/6", "1/4", "1/3", "1/2", "2/3", "3/4", "1 bar"}
options.BY_BARS_NA = {}
for i = 1, #options.BY_BARS do table.insert(options.BY_BARS_NA, "N/A") end
options.BY_BARS_DECIMAL = {1/64, 1/48, 1/32, 1/24, 1/16, 1/12, 1/8, 1/6, 1/4, 1/3, 1/2, 2/3, 3/4, 1}
for i = 2, 32 do
  table.insert(options.BY_BARS, i .. " bars")
  table.insert(options.BY_BARS_DECIMAL, i)
end

specs.LFO_1_FREQ = ControlSpec.new(0.05, 20, "exp", 0, 2, "Hz")
specs.LFO_2_FREQ = ControlSpec.new(0.05, 20, "exp", 0, 4, "Hz")
options.LFO_WAVE_SHAPE = {"Sine", "Triangle", "Saw", "Square", "Random"}
specs.LFO_FADE = ControlSpec.new(-10, 10, "lin", 0, 0, "s")
options.FILTER_TYPE = {"Low Pass", "High Pass"}
specs.FILTER_FREQ = ControlSpec.new(20, 20000, "exp", 0, 20000, "Hz")
specs.FILTER_RESONANCE = ControlSpec.new(0, 1, "lin", 0, 0, "")
specs.FILTER_TRACKING = ControlSpec.new(0, 2, "lin", 0, 1, ":1")
specs.AMP_ENV_ATTACK = ControlSpec.new(0, 5, "lin", 0, 0, "s")
specs.AMP_ENV_DECAY = ControlSpec.new(0.003, 5, "lin", 0, 1, "s")
specs.AMP_ENV_SUSTAIN = ControlSpec.new(0, 1, "lin", 0, 1, "")
specs.AMP_ENV_RELEASE = ControlSpec.new(0.003, 10, "lin", 0, 0.003, "s")
specs.MOD_ENV_ATTACK = ControlSpec.new(0.003, 5, "lin", 0, 1, "s")
specs.MOD_ENV_DECAY = ControlSpec.new(0.003, 5, "lin", 0, 2, "s")
specs.MOD_ENV_SUSTAIN = ControlSpec.new(0, 1, "lin", 0, 0.65, "")
specs.MOD_ENV_RELEASE = ControlSpec.new(0.003, 10, "lin", 0, 1, "s")
options.QUALITY = {"Nasty", "Low", "Medium", "High"}
specs.AMP = ControlSpec.new(-48, 16, 'db', 0, 0, "dB")

QUALITY_SAMPLE_RATES = {8000, 16000, 32000, 48000}
QUALITY_BIT_DEPTHS = {8, 10, 12, 24}

local function default_sample()
  local sample = {
    manual_load = false,
    streaming = 0,
    num_frames = 0,
    num_channels = 0,
    sample_rate = 0,
    freq_multiplier = 1,
    playing = false,
    positions = {},
    waveform = {}
  }
  return sample
end

-- Meta data
-- These are index zero to align with SC and MIDI note numbers
for i = 0, 255 do
  samples_meta[i] = default_sample()
end

local waveform_last_edited
local lfos_last_edited
local filter_last_edited


-- Functions

local function copy_table(obj)
  if type(obj) ~= "table" then return obj end
  local result = setmetatable({}, getmetatable(obj))
  for k, v in pairs(obj) do result[copy_table(k)] = copy_table(v) end
  return result
end

local function lookup_play_mode(sample_id)
  return options.PLAY_MODE_IDS[samples_meta[sample_id].streaming + 1][params:get("play_mode_" .. sample_id)]
end

local function update_by_bars_options(sample_id)
  if beat_params then
    local param = params:lookup_param("by_bars_" .. sample_id)
    if params:get("scale_by_" .. sample_id) == 3 then
      param.options = options.BY_BARS
    else
      param.options = options.BY_BARS_NA
    end
  end
end

local function set_play_mode(id, play_mode)
  engine.playMode(id, play_mode)
  if samples_meta[id].streaming == 1 then
    local start_frame = params:get("start_frame_" .. id)
    params:set("start_frame_" .. id, start_frame - 1)
    params:set("start_frame_" .. id, start_frame)
  end
end

function Timber.load_sample(id, file)
  samples_meta[id].manual_load = true
  params:set("sample_" .. id, file)
end

local function sample_loaded(id, streaming, num_frames, num_channels, sample_rate)
  
  samples_meta[id].streaming = streaming
  samples_meta[id].num_frames = num_frames
  samples_meta[id].num_channels = num_channels
  samples_meta[id].sample_rate = sample_rate
  samples_meta[id].freq_multiplier = 1
  samples_meta[id].playing = false
  samples_meta[id].positions = {}
  samples_meta[id].waveform = {}
  
  local start_frame = params:get("start_frame_" .. id)
  local end_frame = params:get("end_frame_" .. id)
  local by_length = params:get("by_length_" .. id)
  
  local start_frame_max = num_frames
  if streaming == 1 then
    start_frame_max = start_frame_max - STREAMING_BUFFER_SIZE
  end
  params:lookup_param("start_frame_" .. id).controlspec.maxval = start_frame_max
  params:lookup_param("end_frame_" .. id).controlspec.maxval = num_frames
  
  local play_mode_param = params:lookup_param("play_mode_" .. id)
  if streaming == 0 then
    play_mode_param.options = options.PLAY_MODE_BUFFER
    play_mode_param.count = #options.PLAY_MODE_BUFFER
  else
    play_mode_param.options = options.PLAY_MODE_STREAMING
    play_mode_param.count = #options.PLAY_MODE_STREAMING
  end
  
  update_by_bars_options(id)
  local duration = num_frames / sample_rate

  -- Set defaults
  if samples_meta[id].manual_load then
    if streaming == 0 then
      params:set("play_mode_" .. id, options.PLAY_MODE_BUFFER_DEFAULT)
    else
      params:set("play_mode_" .. id, options.PLAY_MODE_STREAMING_DEFAULT)
    end
    
    params:set("start_frame_" .. id, 1) -- Odd little hack to make sure it actually gets set
    params:set("start_frame_" .. id, 0)
    params:set("end_frame_" .. id, 1)
    params:set("end_frame_" .. id, num_frames)
    params:set("loop_start_frame_" .. id, 1)
    params:set("loop_start_frame_" .. id, 0)
    params:set("loop_end_frame_" .. id, 1)
    params:set("loop_end_frame_" .. id, num_frames)
    
    params:set("transpose_" .. id, 0)
    params:set("detune_cents_" .. id, 0)

  else
    -- These need resetting after having their ControlSpecs altered
    params:set("start_frame_" .. id, start_frame)
    params:set("end_frame_" .. id, end_frame)
    params:set("by_length_" .. id, by_length)
    
    set_play_mode(id, lookup_play_mode(id))
  end
  
  waveform_last_edited = nil
  lfos_last_edited = nil
  filter_last_edited = nil
  Timber.sample_changed_callback(id)
  Timber.meta_changed_callback(id)
  Timber.waveform_changed_callback(id)
  Timber.play_positions_changed_callback(id)
  
  samples_meta[id].manual_load = false
end

local function sample_load_failed(id, error_status)
  
  samples_meta[id] = default_sample()
  samples_meta[id].error_status = error_status
  
  waveform_last_edited = nil
  lfos_last_edited = nil
  filter_last_edited = nil
  Timber.sample_changed_callback(id)
  Timber.meta_changed_callback(id)
  Timber.waveform_changed_callback(id)
  Timber.play_positions_changed_callback(id)
  
  samples_meta[id].manual_load = false
end

function Timber.clear_samples(first, last)
  first = first or 0
  last = last or first
  if last < first then last = first end
  
  engine.clearSamples(first, last)
  
  local extended_params = {}
  for _, v in pairs(param_ids) do table.insert(extended_params, v) end
  --for _, v in pairs(extra_param_ids) do table.insert(extended_params, v) end
  
  for i = first, last do
    
    samples_meta[i] = default_sample()
    
    -- Set all params to default without firing actions
    for k, v in pairs(extended_params) do
      local param = params:lookup_param(v .. "_" .. i)
      local param_action = param.action
      param.action = function(value) end
      if param.t == 3 then -- Control
        params:set(v .. "_" .. i, param.controlspec.default)
      elseif param.t == 4 then -- File
        params:set(v .. "_" .. i, "-")
      elseif param.t ~= 6 then -- Not trigger
        params:set(v .. "_" .. i, param.default)
      end
      param.action = param_action
    end
    
    Timber.meta_changed_callback(i)    
    Timber.waveform_changed_callback(i)
    Timber.play_positions_changed_callback(i)
  end
  
  Timber.views_changed_callback(nil)
  Timber.setup_params_dirty = true
end

local function update_freq_multiplier(sample_id)
  
  local scale_by = params:get("scale_by_" .. sample_id)
  local multiplier = 1
  local sample_duration = math.abs(params:get("end_frame_" .. sample_id) - params:get("start_frame_" .. sample_id)) / samples_meta[sample_id].sample_rate
  if scale_by == 1 then
    multiplier = params:get("by_percentage_" .. sample_id) / 100
  elseif scale_by == 2 then
    multiplier = sample_duration / params:get("by_length_" .. sample_id)
  elseif scale_by == 3 then
    multiplier = sample_duration / (options.BY_BARS_DECIMAL[params:get("by_bars_" .. sample_id)] * (60 / Timber.bpm * 4))
  end
  
  if multiplier ~= samples_meta[sample_id].freq_multiplier then
    engine.freqMultiplier(sample_id, multiplier)
    samples_meta[sample_id].freq_multiplier = multiplier
  end
end

local function update_by_bar_multipliers()
  for i = 0, Timber.num_sample_params - 1 do
    if params:get("scale_by_" .. i) == 3 then
      --update_freq_multiplier(i)
    end
  end
end

local function build_extended_params(exclusions)
  
  exclusions = exclusions or {}
  local extended_params = {}
  for _, v in pairs(param_ids) do
    
    local include = true
    for _, e in pairs(exclusions) do
      if v == e then
        include = false
        break
      end
    end
    
    if include then
      if v ~= "by_bars" or beat_params then
        table.insert(extended_params, v)
      end
    end
  end
  for _, v in pairs(extra_param_ids) do table.insert(extended_params, v) end
  
  return extended_params
end

local function copy_param(from_param, to_param, exclude_controlspec)
  local to_param_action = to_param.action
  to_param.action = function(value) end
  
  if to_param.t == 3 then -- Control
    if not exclude_controlspec then to_param.controlspec = from_param.controlspec end
    to_param:set(from_param:get())
  elseif to_param.t == 4 then -- File
    to_param:set(from_param:get())
  elseif from_param.t ~= 6 then -- Not trigger
    to_param:set(from_param:get())
  end
  
  to_param.action = to_param_action
  return to_param
end

local function move_copy_update(from_id, to_id)
  local ids = {from_id, to_id}
  for _, id in pairs(ids) do
    update_by_bars_options(id)
    --update_freq_multiplier(id)
    samples_meta[id].positions = {}
    samples_meta[id].playing = false
    Timber.meta_changed_callback(id)    
    Timber.waveform_changed_callback(id)
    Timber.play_positions_changed_callback(id)
  end
  
  Timber.setup_params_dirty = true
  Timber.filter_dirty = true
  Timber.env_dirty = true
  Timber.lfo_functions_dirty = true
  Timber.views_changed_callback(nil)
end

function Timber.move_sample(from_id, to_id)
  
  if from_id == to_id then return end
  
  engine.moveSample(from_id, to_id)
  
  local from_meta = samples_meta[from_id]
  samples_meta[from_id] = samples_meta[to_id]
  samples_meta[to_id] = from_meta
  
  local extended_params = build_extended_params()
  
  for k, v in pairs(extended_params) do
    local from_param = params:lookup_param(v .. "_" .. from_id)
    local to_param = params:lookup_param(v .. "_" .. to_id)
    local to_param_orig = copy_table(to_param)
    
    to_param = copy_param(from_param, to_param)
    from_param = copy_param(to_param_orig, from_param)
  end
  
  move_copy_update(from_id, to_id)
end

function Timber.copy_sample(from_id, to_first_id, to_last_id)
  
  engine.copySample(from_id, to_first_id, to_last_id)
  
  local extended_params = build_extended_params()
  
  for i = to_first_id, to_last_id do
    if from_id ~= i then
    
      samples_meta[i] = copy_table(samples_meta[from_id])
      
      for k, v in pairs(extended_params) do
        local from_param = params:lookup_param(v .. "_" .. from_id)
        local to_param = params:lookup_param(v .. "_" .. i)
        
        to_param = copy_param(from_param, to_param)
      end
      
      move_copy_update(from_id, i)
    end
  end
end

function Timber.copy_params(from_id, to_first_id, to_last_id, param_ids)
  
  engine.copyParams(from_id, to_first_id, to_last_id)
  
  local exclusions = {"sample", "start_frame", "end_frame", "loop_start_frame", "loop_end_frame", "play_mode"}
  local extended_params = build_extended_params(exclusions)
  
  for i = to_first_id, to_last_id do
    if from_id ~= i and samples_meta[i].num_frames > 0 then
      
      for k, v in pairs(extended_params) do
        local from_param = params:lookup_param(v .. "_" .. from_id)
        local to_param = params:lookup_param(v .. "_" .. i)
        
        local exclude_controlspec = false
        if v == "by_length" then exclude_controlspec = true end
        to_param = copy_param(from_param, to_param, exclude_controlspec)
      end
      
      move_copy_update(from_id, i)
    end
  end
end

local function store_waveform(id, offset, padding, waveform_blob)
  
  for i = 1, string.len(waveform_blob) - padding do
    
    local value = string.byte(string.sub(waveform_blob, i, i + 1))
    value = util.linlin(0, 126, -1, 1, value)
    
    local frame_index = math.ceil(i / 2) + offset
    if i % 2 > 0 then
      samples_meta[id].waveform[frame_index] = {}
      samples_meta[id].waveform[frame_index][1] = value -- Min
    else
      samples_meta[id].waveform[frame_index][2] = value -- Max
    end
  end
  
  Timber.waveform_changed_callback(id)
end

local function play_position(id, voice_id, position)
  
  samples_meta[id].positions[voice_id] = position
  Timber.play_positions_changed_callback(id)
  
  if not samples_meta[id].playing then
    samples_meta[id].playing = true
    Timber.meta_changed_callback(id)
  end
end

local function voice_freed(id, voice_id)
  samples_meta[id].positions[voice_id] = nil
  samples_meta[id].playing = false
  for _, _ in pairs(samples_meta[id].positions) do
    samples_meta[id].playing = true
    break
  end
  Timber.meta_changed_callback(id)
  Timber.play_positions_changed_callback(id)
end

local function set_marker(id, param_prefix)
  
  -- Updates start frame, end frame, loop start frame, loop end frame all at once to make sure everything is valid
  
  local start_frame = params:get("start_frame_" .. id)
  local end_frame = params:get("end_frame_" .. id)
  
  if samples_meta[id].streaming == 0 then -- Buffer
    
    local loop_start_frame = params:get("loop_start_frame_" .. id)
    local loop_end_frame = params:get("loop_end_frame_" .. id)
    
    local first_frame = math.min(start_frame, end_frame)
    local last_frame = math.max(start_frame, end_frame)
    
    -- Set loop min and max
    params:lookup_param("loop_start_frame_" .. id).controlspec.minval = first_frame
    params:lookup_param("loop_start_frame_" .. id).controlspec.maxval = last_frame
    params:lookup_param("loop_end_frame_" .. id).controlspec.minval = first_frame
    params:lookup_param("loop_end_frame_" .. id).controlspec.maxval = last_frame
    
    local SHORTEST_LOOP = 100
    if loop_start_frame > loop_end_frame - SHORTEST_LOOP then
      if param_prefix == "loop_start_frame_" then
        loop_end_frame = loop_start_frame + SHORTEST_LOOP
      elseif param_prefix == "loop_end_frame_" then
        loop_start_frame = loop_end_frame - SHORTEST_LOOP
      end
    end
    
    -- Set loop start and end
    params:set("loop_start_frame_" .. id, loop_start_frame - 1, true) -- Hack to make sure it gets set
    params:set("loop_start_frame_" .. id, loop_start_frame, true)
    params:set("loop_end_frame_" .. id, loop_end_frame + 1, true)
    params:set("loop_end_frame_" .. id, loop_end_frame, true)
    
    if param_prefix == "loop_start_frame_" or loop_start_frame ~= params:get("loop_start_frame_" .. id) then
      engine.loopStartFrame(id, params:get("loop_start_frame_" .. id))
    end
    if param_prefix == "loop_end_frame_" or loop_end_frame ~= params:get("loop_end_frame_" .. id) then
      engine.loopEndFrame(id, params:get("loop_end_frame_" .. id))
    end
    
    
  else -- Streaming
    
    if param_prefix == "start_frame_" then
      params:lookup_param("end_frame_" .. id).controlspec.minval = params:get("start_frame_" .. id)
    end
    
    if lookup_play_mode(id) < 2 then
      params:lookup_param("start_frame_" .. id).controlspec.maxval = samples_meta[id].num_frames - STREAMING_BUFFER_SIZE
    else
      params:lookup_param("start_frame_" .. id).controlspec.maxval = params:get("end_frame_" .. id)
    end
    
  end
  
  -- Set start and end
  params:set("start_frame_" .. id, start_frame - 1, true)
  params:set("start_frame_" .. id, start_frame, true)
  params:set("end_frame_" .. id, end_frame + 1, true)
  params:set("end_frame_" .. id, end_frame, true)
  
  if param_prefix == "start_frame_" or start_frame ~= params:get("start_frame_" .. id) then
    engine.startFrame(id, params:get("start_frame_" .. id))
    --update_freq_multiplier(id)
  end
  if param_prefix == "end_frame_" or end_frame ~= params:get("end_frame_" .. id) then
    engine.endFrame(id, params:get("end_frame_" .. id))
    --update_freq_multiplier(id)
  end
  
  waveform_last_edited = {id = id, param = param_prefix .. id}
  Timber.views_changed_callback(id)
end

function Timber.osc_event(path, args, from)
  
  if path == "/engineSampleLoaded" then
    sample_loaded(args[1], args[2], args[3], args[4], args[5])
    
  elseif path == "/engineSampleLoadFailed" then
    sample_load_failed(args[1], args[2])
    
  elseif path == "/engineWaveform" then
    store_waveform(args[1], args[2], args[3], args[4])
  
  elseif path == "/enginePlayPosition" then
    play_position(args[1], args[2], args[3])
    
  elseif path == "/engineVoiceFreed" then
    voice_freed(args[1], args[2])
    
  end
end

osc.event = Timber.osc_event
-- NOTE: If you need the OSC callback in your script then Timber.osc_event(path, args, from)
-- must be called from the end of that function to pass the data down to this lib

function Timber.set_bpm(bpm)
  Timber.bpm = bpm
  update_by_bar_multipliers()
end


-- Formatters

local function format_st(param)
  local formatted = param:get() .. " ST"
  if param:get() > 0 then formatted = "+" .. formatted end
  return formatted
end

local function format_cents(param)
  local formatted = param:get() .. " cents"
  if param:get() > 0 then formatted = "+" .. formatted end
  return formatted
end

local function format_frame_number(sample_id)
  return function(param)
    local sample_rate = samples_meta[sample_id].sample_rate
    if sample_rate <= 0 then
      return "-"
    else
      return Formatters.format_secs_raw(param:get() / sample_rate)
    end
  end
end

local function format_by_percentage(sample_id)
  return function(param)
    local return_string
    if params:get("scale_by_" .. sample_id) == 1 then
      return_string = util.round(param:get(), 0.1) .. "%"
    else
      return_string = "N/A"
    end
    return return_string
  end
end

local function format_by_length(sample_id)
  return function(param)
    local return_string
    if params:get("scale_by_" .. sample_id) == 2 then
      return_string = Formatters.format_secs(param)
    else
      return_string = "N/A"
    end
    return return_string
  end
end

local function format_fade(param)
  local secs = param:get()
  local suffix = " in"
  if secs < 0 then
    secs = secs - specs.LFO_FADE.minval
    suffix = " out"
  end
  secs = util.round(secs, 0.01)
  return math.abs(secs) .. " s" .. suffix
end

local function format_ratio_to_one(param)
  return util.round(param:get(), 0.01) .. ":1"
end

local function format_hide_for_stream(sample_id, param_name, formatter)
  return function(param)
    if Timber.samples_meta[sample_id].streaming == 1 then
      return "N/A"
    else
      if formatter then
        return formatter(param)
      else
        return util.round(param:get(), 0.01) .. " " .. param.controlspec.units
      end
    end
  end
end

-- Params

function Timber.add_params()
  
  params:add{type = "trigger", id = "clear_all", name = "Clear All", action = function(value)
    Timber.clear_samples(0, #samples_meta - 1)
  end}
  params:add{type = "control", id = "lfo_1_freq", name = "LFO1 Freq", controlspec = specs.LFO_1_FREQ, formatter = Formatters.format_freq, action = function(value)
    engine.lfo1Freq(value)
    lfos_last_edited = {id = nil, param = "lfo_1_freq"}
    Timber.views_changed_callback(nil)
    Timber.lfo_1_dirty = true
  end}
  params:add{type = "option", id = "lfo_1_wave_shape", name = "LFO1 Shape", options = options.LFO_WAVE_SHAPE, default = 1, action = function(value)
    engine.lfo1WaveShape(value - 1)
    lfos_last_edited = {id = nil, param = "lfo_1_wave_shape"}
    Timber.views_changed_callback(nil)
    Timber.lfo_1_dirty = true
  end}
  params:add{type = "control", id = "lfo_2_freq", name = "LFO2 Freq", controlspec = specs.LFO_2_FREQ, formatter = Formatters.format_freq, action = function(value)
    engine.lfo2Freq(value)
    lfos_last_edited = {id = nil, param = "lfo_2_freq"}
    Timber.views_changed_callback(nil)
    Timber.lfo_2_dirty = true
  end}
  params:add{type = "option", id = "lfo_2_wave_shape", name = "LFO2 Shape", options = options.LFO_WAVE_SHAPE, default = 4, action = function(value)
    engine.lfo2WaveShape(value - 1)
    lfos_last_edited = {id = nil, param = "lfo_2_wave_shape"}
    Timber.views_changed_callback(nil)
    Timber.lfo_2_dirty = true
  end}

end

function Timber.add_sample_params(id, include_beat_params, extra_params)
  
  local name_prefix = ""
  if id then name_prefix = id .. " " end
  id = id or 0
  if include_beat_params then beat_params = true end
  
  params:add{type = "file", id = "sample_" .. id, name = name_prefix .. "Sample", action = function(value)
    if samples_meta[id].num_frames > 0 or value ~= "-" then
      
      -- Set some large defaults in case a pset load is about to try and set all these
      params:lookup_param("start_frame_" .. id).controlspec.maxval = MAX_FRAMES
      params:lookup_param("end_frame_" .. id).controlspec.maxval = MAX_FRAMES
      params:lookup_param("loop_start_frame_" .. id).controlspec.maxval = MAX_FRAMES
      params:set("loop_start_frame_" .. id, 0)
      params:lookup_param("loop_end_frame_" .. id).controlspec.maxval = MAX_FRAMES
      params:set("loop_end_frame_" .. id, MAX_FRAMES)
      --params:lookup_param("by_length_" .. id).controlspec.minval = 0
      --params:lookup_param("by_length_" .. id).controlspec.maxval = 100000
      local play_mode_param = params:lookup_param("play_mode_" .. id)
      play_mode_param.options = options.PLAY_MODE_BUFFER
      play_mode_param.count = #options.PLAY_MODE_BUFFER
      
      engine.loadSample(id, value)
      Timber.views_changed_callback(id)
    else
      samples_meta[id].manual_load = false
    end
  end}
  params:add{type = "trigger", id = "clear_" .. id, name = "Clear", action = function(value)
    Timber.clear_samples(id)
    Timber.views_changed_callback(id)
  end}
  
  params:add{type = "option", id = "quality_" .. id, name = "Quality", options = options.QUALITY, default = #options.QUALITY, action = function(value)
    engine.downSampleTo(id, QUALITY_SAMPLE_RATES[value])
    engine.bitDepth(id, QUALITY_BIT_DEPTHS[value])
    Timber.views_changed_callback(id)
    Timber.setup_params_dirty = true
  end}
  params:add{type = "number", id = "transpose_" .. id, name = "Transpose", min = -48, max = 48, default = 0, formatter = format_st, action = function(value)
    engine.transpose(id, value)
    Timber.views_changed_callback(id)
    Timber.setup_params_dirty = true
  end}
  params:add{type = "number", id = "detune_cents_" .. id, name = "Detune", min = -100, max = 100, default = 0, formatter = format_cents, action = function(value)
    engine.detuneCents(id, value)
    Timber.views_changed_callback(id)
    Timber.setup_params_dirty = true
  end}
  

  
  params:add_separator()
  
  params:add{type = "option", id = "play_mode_" .. id, name = "Play Mode", options = options.PLAY_MODE_BUFFER, default = options.PLAY_MODE_BUFFER_DEFAULT, action = function(value)
    set_play_mode(id, lookup_play_mode(id))
    waveform_last_edited = {id = id}
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "start_frame_" .. id, name = "Start", controlspec = ControlSpec.new(0, MAX_FRAMES, "lin", 1, 0), formatter = format_frame_number(id), action = function(value)
    set_marker(id, "start_frame_")
  end}
  params:add{type = "control", id = "end_frame_" .. id, name = "End", controlspec = ControlSpec.new(0, MAX_FRAMES, "lin", 1, MAX_FRAMES), formatter = format_frame_number(id), action = function(value)
    set_marker(id, "end_frame_")
  end}
  params:add{type = "control", id = "loop_start_frame_" .. id, name = "Loop Start", controlspec = ControlSpec.new(0, MAX_FRAMES, "lin", 1, 0),
  formatter = format_hide_for_stream(id, "loop_start_frame_" .. id, format_frame_number(id)), action = function(value)
    set_marker(id, "loop_start_frame_")
  end}
  params:add{type = "control", id = "loop_end_frame_" .. id, name = "Loop End", controlspec = ControlSpec.new(0, MAX_FRAMES, "lin", 1, MAX_FRAMES),
  formatter = format_hide_for_stream(id, "loop_end_frame_" .. id, format_frame_number(id)), action = function(value)
    set_marker(id, "loop_end_frame_")
  end}
  
  params:add_separator()
  
  params:add{type = "control", id = "freq_mod_lfo_1_" .. id, name = "Freq Mod (LFO1)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.freqModLfo1(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "freq_mod_lfo_2_" .. id, name = "Freq Mod (LFO2)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.freqModLfo2(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "freq_mod_env_" .. id, name = "Freq Mod (Env)", controlspec = ControlSpec.BIPOLAR, action = function(value)
    engine.freqModEnv(id, value)
    Timber.views_changed_callback(id)
  end}
  
  params:add_separator()

  params:add{type = "option", id = "filter_type_" .. id, name = "Filter Type", options = options.FILTER_TYPE, default = 1, action = function(value)
    engine.filterType(id, value - 1)
    Timber.filter_dirty = true
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_freq_" .. id, name = "Filter Cutoff", controlspec = specs.FILTER_FREQ, formatter = Formatters.format_freq, action = function(value)
    engine.filterFreq(id, value)
    filter_last_edited = {id = id, param = "filter_freq_" .. id}
    Timber.filter_dirty = true
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_resonance_" .. id, name = "Filter Resonance", controlspec = specs.FILTER_RESONANCE, action = function(value)
    engine.filterReso(id, value)
    filter_last_edited = {id = id, param = "filter_resonance_" .. id}
    Timber.filter_dirty = true
    Timber.views_changed_callback(id)
  end}

  params:add{type = "control", id = "filter_freq_mod_lfo_1_" .. id, name = "Filter Cutoff Mod (LFO1)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.filterFreqModLfo1(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_freq_mod_lfo_2_" .. id, name = "Filter Cutoff Mod (LFO2)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.filterFreqModLfo2(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_freq_mod_env_" .. id, name = "Filter Cutoff Mod (Env)", controlspec = ControlSpec.BIPOLAR, action = function(value)
    engine.filterFreqModEnv(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_freq_mod_vel_" .. id, name = "Filter Cutoff Mod (Vel)", controlspec = ControlSpec.BIPOLAR, action = function(value)
    engine.filterFreqModVel(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_freq_mod_pressure_" .. id, name = "Filter Cutoff Mod (Pres)", controlspec = ControlSpec.BIPOLAR, action = function(value)
    engine.filterFreqModPressure(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "filter_tracking_" .. id, name = "Filter Tracking", controlspec = specs.FILTER_TRACKING, formatter = format_ratio_to_one, action = function(value)
    engine.filterTracking(id, value)
    Timber.views_changed_callback(id)
  end}

  params:add_separator()

  params:add{type = "control", id = "pan_" .. id, name = "Pan", controlspec = ControlSpec.PAN, formatter = Formatters.bipolar_as_pan_widget, action = function(value)
    engine.pan(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "pan_mod_lfo_1_" .. id, name = "Pan Mod (LFO1)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.panModLfo1(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "pan_mod_lfo_2_" .. id, name = "Pan Mod (LFO2)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.panModLfo2(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "pan_mod_env_" .. id, name = "Pan Mod (Env)", controlspec = ControlSpec.BIPOLAR, action = function(value)
    engine.panModEnv(id, value)
    Timber.views_changed_callback(id)
  end}
  
  params:add{type = "control", id = "amp_" .. id, name = "Amp", controlspec = specs.AMP, action = function(value)
    engine.amp(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "amp_mod_lfo_1_" .. id, name = "Amp Mod (LFO1)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.ampModLfo1(id, value)
    Timber.views_changed_callback(id)
  end}
  params:add{type = "control", id = "amp_mod_lfo_2_" .. id, name = "Amp Mod (LFO2)", controlspec = ControlSpec.UNIPOLAR, action = function(value)
    engine.ampModLfo2(id, value)
    Timber.views_changed_callback(id)
  end}
  
  params:add_separator()
  
  params:add{type = "control", id = "amp_env_attack_" .. id, name = "Amp Env Attack", controlspec = specs.AMP_ENV_ATTACK, formatter = Formatters.format_secs, action = function(value)
    engine.ampAttack(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "amp_env_decay_" .. id, name = "Amp Env Decay", controlspec = specs.AMP_ENV_DECAY, formatter = Formatters.format_secs, action = function(value)
    engine.ampDecay(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "amp_env_sustain_" .. id, name = "Amp Env Sustain", controlspec = specs.AMP_ENV_SUSTAIN, action = function(value)
    engine.ampSustain(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "amp_env_release_" .. id, name = "Amp Env Release", controlspec = specs.AMP_ENV_RELEASE, formatter = Formatters.format_secs, action = function(value)
    engine.ampRelease(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}

  params:add_separator()

  params:add{type = "control", id = "mod_env_attack_" .. id, name = "Mod Env Attack", controlspec = specs.MOD_ENV_ATTACK, formatter = Formatters.format_secs, action = function(value)
    engine.modAttack(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "mod_env_decay_" .. id, name = "Mod Env Decay", controlspec = specs.MOD_ENV_DECAY, formatter = Formatters.format_secs, action = function(value)
    engine.modDecay(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "mod_env_sustain_" .. id, name = "Mod Env Sustain", controlspec = specs.MOD_ENV_SUSTAIN, action = function(value)
    engine.modSustain(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  params:add{type = "control", id = "mod_env_release_" .. id, name = "Mod Env Release", controlspec = specs.MOD_ENV_RELEASE, formatter = Formatters.format_secs, action = function(value)
    engine.modRelease(id, value)
    Timber.views_changed_callback(id)
    Timber.env_dirty = true
  end}
  
  params:add_separator()
  
  params:add{type = "control", id = "lfo_1_fade_" .. id, name = "LFO1 Fade", controlspec = specs.LFO_FADE, formatter = format_fade, action = function(value)
    if value < 0 then value = specs.LFO_FADE.minval - 0.00001 + math.abs(value) end
    engine.lfo1Fade(id, value)
    lfos_last_edited = {id = id, param = "lfo_1_fade_" .. id}
    Timber.views_changed_callback(id)
    Timber.lfo_1_dirty = true
  end}
  params:add{type = "control", id = "lfo_2_fade_" .. id, name = "LFO2 Fade", controlspec = specs.LFO_FADE, formatter = format_fade, action = function(value)
    if value < 0 then value = specs.LFO_FADE.minval - 0.00001 + math.abs(value) end
    engine.lfo2Fade(id, value)
    lfos_last_edited = {id = id, param = "lfo_2_fade_" .. id}
    Timber.views_changed_callback(id)
    Timber.lfo_2_dirty = true
  end}
  
  Timber.num_sample_params = Timber.num_sample_params + 1
end

return Timber