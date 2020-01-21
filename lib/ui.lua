local ui = {

    reel = {
        pos = { x = 28, y = 21 },  -- default
        left  = { {}, {}, {}, {}, {}, {} },
        right = { {}, {}, {}, {}, {}, {} },
    },
    tape = { 
        tension = 30,
        flutter = { on = false, amount = 60 }
    },
    playhead = {
        height = 35,
        brightness = 0,
    },
}
local ui_lib = require("ui")

local speed = 0.2


local function update_reel()
  for i=1, 6 do
    ui.reel.left[i].velocity = util.linlin(0, 1, 0.01, (speed / 1.9) / (1 / 2), 0.15)
    ui.reel.left[i].position = (ui.reel.left[i].position - ui.reel.left[i].velocity) % (math.pi * 2)
    ui.reel.left[i].x = 30 + ui.reel.left[i].orbit * math.cos(ui.reel.left[i].position)
    ui.reel.left[i].y = 25 + ui.reel.left[i].orbit * math.sin(ui.reel.left[i].position)
    ui.reel.right[i].velocity = util.linlin(0, 1, 0.01, (speed / 1.5) / (1 / 2), 0.15)
    ui.reel.right[i].position = (ui.reel.right[i].position - ui.reel.right[i].velocity) % (math.pi * 2)
    ui.reel.right[i].x = 95 + ui.reel.right[i].orbit * math.cos(ui.reel.right[i].position)
    ui.reel.right[i].y = 25 + ui.reel.right[i].orbit * math.sin(ui.reel.right[i].position)
  end
end


ui.init  = function()
for i=1, 6 do
    ui.reel.right[i].orbit = math.fmod(i,2)~=0 and 3 or 9
    ui.reel.right[i].position = i <= 2 and 0 or i <= 4 and 2 or 4
    ui.reel.right[i].velocity = util.linlin(0, 1, 0.01, speed, 1)
    ui.reel.left[i].orbit = math.fmod(i,2)~=0 and 3 or 9
    ui.reel.left[i].position = i <= 2 and 3 or i <= 4 and 5 or 7.1
    ui.reel.left[i].velocity = util.linlin(0, 1, 0.01, speed * 3, 0.2)
end
update_reel()
end


local music = require 'musicutil'
local rules = { [0] = 'OFF', '10%', '20%', '30%', '50%', '60%', '70%', '90%', 'PREV', 'NEXT', '/ 2', '/ 3', '/ 4', '/ 5', '/ 6', '/ 7', '/ 8', } 


local function get_step(x) return (x * 16) - 15 end

local function set_brightness(n, i) screen.level(i == n and 6 or 2) end

local function metro_icon(x, y, pos)
  local metroicon = pos % 4
  screen.level(0)
  screen.move(x + 2, y + 5)
  screen.line(x + 7, y)
  screen.line(x + 12, y + 5)
  screen.line(x + 3, y + 5)
  screen.stroke()
  screen.move(x + 7, y + 3)
  screen.line(metroicon <= 1 and (x + 4) or (x + 10), y ) 
  screen.stroke()

end

function ui.head(params_data, data, view) -- , selected, data[data.pattern].track, data, data.ui_index)
  
  screen.level((not view.sampling and data.ui_index == -6 ) and 5 or 2)  
  screen.rect(1, 0, 20, 7)
  screen.fill()
  screen.level(0)
  
  screen.font_size(6)
  screen.font_face(25)
  screen.move(2,6)
  screen.text('P')--  .. pattern)
  screen.move(17,6)
  screen.text_right(data.pattern or nil )
  screen.stroke()
  
  screen.level((not view.sampling and data.ui_index == -5 ) and 5 or 2)  
  screen.rect(22, 0, 20, 7)
  screen.fill()
  screen.level(0)
  screen.move(31,6)
  local tr = data.selected[1]
  local s = data.selected[2]
  
  if s then 
    screen.text_center( data.selected[1] ..':' .. data.selected[2] )
  else
    screen.text_center( 'TR ' .. data.selected[1] )
  end
  
  screen.stroke()
  
  if s then 
    
    screen.level((not view.sampling and data.ui_index == -2 ) and 5 or 2)  
    screen.rect(43, 0, 41, 7)
    screen.fill()
    screen.level(0)
    screen.move(44, 6)
    screen.text('RULE')
    screen.move(82, 6)
    screen.text_right(rules[params_data.rule])
    
    
  else
    screen.level((not view.sampling and data.ui_index == -4) and 5 or 2)  
    screen.rect(43, 0, 25, 7)
    screen.fill()
    screen.level(0)
    metro_icon(42,1, data[data.pattern].track.p_pos[data.selected[1]])
    screen.move(66, 6)
    screen.text_right(data[data.pattern].bpm)
    
    
  end

  screen.stroke()
  if not s then
    screen.level((not view.sampling and data.ui_index == -3) and 5 or 2)  
    screen.rect(69, 0, 15, 7)
    screen.fill()
    screen.level(0)
    screen.move(70,6)
    screen.text('/ ')
    screen.move(81,6)
    screen.text_right(data[data.pattern].track.div[data.selected[1]])
    screen.stroke()
  end
  screen.level((not view.sampling and data.ui_index == -1) and 5 or 2)  
  screen.rect(85, 0, 9, 7)
  screen.fill()
  screen.level(0)
  screen.move(89,6)
  screen.text_center(params_data.retrig)
  screen.stroke()

  
  for i = 1, 16 do
    local offset_y = i <= 8 and 0 or 4
    local offset_x = i <= 8 and 0 or 8
    local tr = data.selected[1]
    local s = data.selected[2] and get_step(data.selected[2]) or data[data.pattern].track.pos[tr]
    screen.level((not view.sampling and data.ui_index == 0) and 5 or 2)

      local step = data[data.pattern][data.selected[1]][s + (i - 1 )]
      if step == 1 then
        screen.rect(92 + ((i - offset_x) * 4), offset_y + 1, 2, 2)
      else
        screen.rect(91 + ((i - offset_x) * 4), offset_y, 3, 3)
      end

      if step == 1 then screen.stroke() else screen.fill() end

  end
end

function ui.draw_env(x, y, t, params_data, ui_index)
    local atk, dec, sus, rel
    atk = util.clamp(params_data.attack, 0, 4)
    dec = params_data.decay
    sus = params_data.sustain
    rel = params_data.release
    

    local sy = util.clamp(y - (sus * 10) + 2, 0, y )
    local attack_peak = x + atk * 2
    
    screen.level(2)
    screen.rect(x - 1, y - 15, 40, 16)
    screen.stroke()
    
    screen.level(1)
    screen.move(x,y)
    screen.line(attack_peak, y - 14)
    screen.stroke()
    
    screen.move(attack_peak, y - 14)
    screen.line(x + (dec) * 3 + 2, sy)

    screen.move(x + (dec) * 3 + 2, sy)
    screen.line(util.clamp(x + (rel) * 3 + 24, 0,  x+38), sy )

    screen.move(util.clamp(x + ( rel) * 3 + 24, 2, x+38), sy)
    screen.line(util.clamp(x + ( rel) * 2 + 38, 0, x+38), y)
    screen.stroke()
  
    screen.level(15)
    if ui_index == 9 then 
      screen.pixel((x + atk * 2 ), y - 14) 
    elseif ui_index == 10 then 
      screen.pixel(x + (dec) * 3 + 2, sy - 1) 
    elseif ui_index == 11 then 
      --screen.pixel(x + (dec ) * 2 + (17 - atk), sy - 1) 
      screen.pixel(util.clamp(x + (rel) * 3 + 19, 0, x + 37), sy -1) 
    elseif ui_index == 12 then 
      screen.pixel(util.clamp(x + (rel) * 3 + 24, 0, x + 37), sy -1) 
    end
    screen.stroke() 

end

function ui.draw_filter(x, y, params_data, ui_index)

    screen.level(2)
    screen.rect(x - 1, y - 15, 40, 16)
    screen.stroke()

    local sample = params_data.sample
    local cut = params_data.cutoff / 1200
    local res = params_data.resonance


    screen.level(1)
    if params_data.ftype == 1 then
        local t = util.clamp(x + cut * 2, x + 9, x + 34)
        screen.move(x - 1, y - 9)
        screen.line(t - 10, y - 9)
        screen.move(t - 10, y - 9)
        screen.line(t + 2, y - 9 - (res * 4))
        screen.move(t + 2, y - 9 - (res * 4))
        screen.line(t + 4, y)
        screen.stroke()
        
        screen.level(15) 
        if ui_index == 17 then 
          screen.pixel(t - 10, y - 10)
        elseif ui_index == 18 then 
          screen.pixel(t + 2, y - 10 - (res * 4)) 
        end
    
    screen.stroke() 

  elseif params_data.ftype == 2 then
        cut =  10 - cut
        local t = util.clamp((x + cut * 2),x , x + 33)
        screen.move(t - 1, y)
        screen.line(t + 1 , y - 9 - (res * 4))
        screen.move(t  + 1 , y - 9 - (res * 4))
        screen.line(t  + (38 - util.clamp((cut * 2), 0, 33)), y - 9)
         
          screen.stroke()
          screen.level(15) 
          if ui_index == 17 then 
            screen.pixel(t,y - 9)
          elseif ui_index == 18 then 
            screen.pixel(t + 3, y - 9 - (res * 4)) 
          end
    
    screen.stroke() 

     
      
    end
    

end

function ui.draw_mode(x, y, mode, index)
    set_brightness(4, index)
    screen.rect(x - 3, y - 15, 20, 17)
    screen.fill()
    screen.level(0)
    screen.move(x ,y - 8)
    screen.text('MODE')
    screen.stroke()
    screen.level(0)
    if mode == 0 then -- rev
      
      screen.move(x + 2, y - 2)
      screen.line(x + 11, y - 2)
      
      
      screen.move(x + 4, y - 5)
      screen.line(x + 1, y - 2)
      screen.move(x + 4, y  )
      screen.line(x + 1, y - 3)
      
      
    --[[elseif mode == 1 then -- loop
      
      screen.move(x + 2, y)
      screen.line(x + 4, y)
      screen.move(x + 4, y + 1)
      screen.line(x + 7, y + 1)
      screen.move(x + 7, y)
      screen.line(x + 9, y)
      screen.move(x + 10, y - 1)
      screen.line(x + 10, y - 3)
      screen.move(x + 7, y - 3)
      screen.line(x + 9, y - 3)
      screen.move(x + 4, y - 4)
      screen.line(x + 7, y - 4)
      screen.move(x + 2, y - 3)
      screen.line(x + 4, y - 3)
      screen.move(x + 3, y - 2)
      screen.line(x + 3, y - 6)
      screen.move(x + 3, y - 2)
      screen.line(x + 6, y - 2)
      
    elseif mode == 2 then -- inf loop
      
      screen.move(x - 1, y)
      screen.line(x + 1, y)
      screen.move(x + 1, y + 1)
      screen.line(x + 4, y + 1)
      screen.move(x + 4, y)
      screen.line(x + 6, y)
      screen.move(x + 7, y - 1)
      screen.line(x + 7, y - 3)
      screen.move(x + 4, y - 3)
      screen.line(x + 6, y - 3)
      screen.move(x + 1, y - 4)
      screen.line(x + 4, y - 4)
      screen.move(x - 1, y - 3)
      screen.line(x + 1, y - 3)
      screen.move(x , y - 2)
      screen.line(x , y - 6)
      screen.move(x , y - 2)
      screen.line(x + 3, y - 2)
      
      screen.move(x + 8, y)
      screen.font_size(8)
      screen.font_face(1)
      screen.text('∞')
      screen.font_size(6)
      screen.font_face(25)
      
    elseif mode == 3 then -- gated
      
      screen.move(x + 4, y + 1)
      screen.line(x + 4, y - 6)
      screen.move(x + 4, y - 5 )
      screen.line(x + 6, y - 5)
      screen.move(x + 6, y + 1)
      screen.line(x + 6, y - 6)
      screen.move(x + 6, y + 1)
      screen.line(x + 10, y + 1)
      ]]
    elseif mode == 1 then -- oneshot
    
      screen.move(x + 1, y - 2)
      screen.line(x + 10, y - 2)
      screen.move(x + 8, y - 5)
      screen.line(x + 11, y - 2)
      screen.move(x + 8, y  )
      screen.line(x + 11, y - 3)
      
    end
    screen.stroke()
end


function ui.draw_note(x, y, params_data, ui_index, count)
  set_brightness(count and count or 2, ui_index)
  screen.rect(x,  y, 20, 17)
  screen.fill()
  -- note icon
  local offset = 0
  if count then offset = 2 end
  
  screen.level(0)
  screen.rect(x + 6 - offset, y + 6, 3, 2)
  screen.rect(x + 7 - offset, y + 6, 3, 1)
  screen.rect(x + 9 - offset, y +2, 1, 4)
  screen.rect(x + 10 - offset, y + 3, 1, 1)
  screen.rect(x + 11 - offset, y + 4, 1, 1)
  screen.fill()
  
  local note_name
  if count then
    --tab.print(params_data)
    --print(count)
    note_name = params_data['note_' .. count]
  else
    note_name = params_data.note
  end
  
  local oct = math.floor(note_name / 12 - 2) == 0 and '' or math.floor(note_name / 12 - 2)
  screen.level(0)
  if count then 
    screen.move(x + 12, y + 8)
    screen.text(count)
    screen.stroke()
  end
  screen.move(x + 9, y + 15)
  screen.text_center(oct ..  music.note_num_to_name(note_name):gsub('♯', '#'))
  screen.stroke()
 
end


function ui.tile(index, name, value, ui_index, lock)
  
  local x = index > 14 and (21 * index) - 314
          or (index == 13 or index == 14) and (21 * index) - 188
          or index > 6 and (21 * index) - 146
          or (21 * index) - 20

  
  
  local y = index > 14 and 44 or index > 6 and 26 or 8
  local x_ext =  index == 4 and 6 or index == 3 and 2 or 0
  
  
  set_brightness(index, ui_index)
  screen.rect(x , y,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  screen.move( x  + 10, y + 7)
  screen.text_center(name)
  screen.move( x  + 10,y + 15)
  local lvl = lock == true and 15 or 0 --
  
  
  screen.level(lvl)
  if (index == 3 or index == 4) and type(value) == 'number' then value = util.round(value / 10000, value % 1 == 0 and 1 or 0.1) end
  if type(value) == 'number' then value = util.round(value, value % 1 == 0 and 1 or 0.1) end
  
  
  screen.text_center(value)
  screen.stroke()
  
end

local name_lookup = {
  ['SMP'] = 'sample',
  ['NOTE'] = 'note',
  ['STRT'] = 'start',
  ['END'] = 's_end',
  ['LFO1'] = 'freq_lfo1',
  ['LFO2'] = 'freq_lfo2',
  ['VOL'] = 'vol',
  ['PAN'] = 'pan',
  ['ENV'] = 'env',
  ['LFO1'] = 'amp_lfo1',
  ['LFO2'] = 'amp_lfo2',
  ['SR'] = 'sr',
  ['TYPE'] = 'ftype',
  ['LFO1'] = 'cut_lfo1',
  ['LFO2'] = 'cut_lfo2',
}


function ui.sample_screen(params_data, data)
    local sr_types = { '8k', '16k', '32k', '48k' }
    local f_types = { 'LPF', 'HPF' } 
  
    local tile = { 
      {1, 'SMP',  params_data.sample },
      {2, 'NOTE', function() ui.draw_note(22, 8, params_data, data.ui_index) end },
      {3, 'STRT', params_data.start },
      {4, 'END',   params_data.s_end }, -- function() ui.draw_mode(67, 23, params_data.rev, data.ui_index) end },
      {5, 'LFO1', params_data.freq_lfo1 },
      {6, 'LFO2', params_data.freq_lfo2 },
      {7, 'VOL', params_data.vol },
      {8, 'PAN', params_data.pan },
      {9, 'ENV', function()  ui.draw_env(45, 42, 'AMP', params_data, data.ui_index) end },
      {13, 'LFO1', params_data.amp_lfo1 },
      {14, 'LFO2', params_data.amp_lfo2 },
      {15, 'SR', sr_types[params_data.sr] },
      {16, 'TYPE', f_types[params_data.ftype] },
      {17, 'FILTER', function() ui.draw_filter(45, 60, params_data, data.ui_index) end },
      {19, 'LFO1', params_data.cut_lfo1 },
      {20, 'LFO2', params_data.cut_lfo2 },

}
   for k, v in pairs(tile) do
      if v[3] and type(v[3]) == 'function' then
        v[3](v[1], v[2])
      elseif v[3] then
        
        
        local lock = false

        if params_data.default then
          if v[2] == 'SR' then
             lock = sr_types[params_data.default[name_lookup[v[2]]]] ~= v[3] and true or false
          elseif v[2] == 'TYPE' then
            lock = f_types[params_data.default[name_lookup[v[2]]]] ~= v[3] and true or false
          else
            lock = params_data.default[name_lookup[v[2]]] ~= v[3]  and true or false
          end
        end
          
        ui.tile(v[1], v[2], v[3], data.ui_index, lock or false)
      end
    end
 
end






local function draw_reel(x, y, reverse)
  local flutter = ui.tape.flutter
  local right = ui.reel.right
  local left = ui.reel.left
  
  local l = util.round(speed * 10)
  if l < 0 then
    l = math.abs(l) + 4
  elseif l >= 4 then
    l = 4
  elseif l == 0 then
    l = reverse and 5 or 1
  end
  screen.level(2)
  screen.line_width(1.5)
  
  local pos = { 1, 3, 5}
  
  for i = 1, 3 do
    screen.move((x + right[pos[i]].x) - 30, (y + right[pos[i]].y) - 20)
    screen.line((x + right[pos[i] + 1].x) - 30, (y + right[pos[i] + 1].y) - 20)
    screen.stroke()
    
    screen.move((x + left[pos[i]].x) +5, (y + left[pos[i]].y) - 20)
    screen.line((x + left[pos[i] + 1].x) +5, (y + left[pos[i] + 1].y) - 20)
    screen.stroke()
  end
  screen.line_width(1)
  --
  screen.level(2)
  screen.circle(x + 35, y + 5, 11)
  screen.stroke()
  screen.circle(x + 65, y + 5, 11)
  screen.stroke()
  
--[[  screen.level(1)
  screen.circle(x + 5, y + 28, 2)
  screen.fill()
  screen.circle(x + 55, y + 28, 2)
  screen.fill()
  screen.level(0)
  screen.circle(x + 5, y + 28, 1)
  screen.circle(x + 55, y + 28, 1)
  screen.fill()
  --right reel
  screen.level(1)
  screen.circle(x + 65, y, 1)
  screen.stroke()
  screen.circle(x + 65, y, 20)
  screen.stroke()
  screen.circle(x + 65, y, 3)
  screen.stroke()
  -- left
  screen.circle(x, y, 20)
  screen.stroke()
  screen.circle(x, y, 1)
  screen.stroke()
  screen.circle(x, y, 3)
  screen.stroke()
  -- tape
  if mounted then
    local x1, x2, x3
    screen.level(6)
    if not flutter.on or (flutter.on and not playing) then
      x1 = x + 65
      x2 = x + 65
      x3 = x + 70
    elseif (flutter.on and playing) then
      x1 =  x + 65 - math.random(0, 5)
      x2 =  x + 65 - math.random(0, 10)
      x3 =  x + 70 - math.random(0, 5)
    end
    screen.move(x, y - 17)
    screen.curve(x1, y - 12, x2, y - 12, x3, y - 12)
    screen.stroke()
    screen.level(6)
    screen.circle(x, y, 18)
    screen.stroke()
    screen.level(3)
    screen.circle(x, y, 17)
    screen.stroke()
    screen.level(6)
    screen.circle(x + 65, y, 14)
    screen.stroke()
    screen.level(3)
    screen.circle(x + 65, y, 13)
    screen.stroke()
    screen.level(6)

    screen.move(x + 75, y + 10)
    screen.line(x + 55, y + 30)
    screen.stroke()
    screen.move(x - 9, y + 16)
    screen.line(x + 5, y + 30)
    screen.curve(x + 5, y + 30, x + 5, y + 30, x + 5, y + 30)
    screen.stroke()
    screen.move(x + 5, y + 30)
    screen.curve(x + 40, y + ui.tape.tension, x + 25, y + ui.tape.tension, x + 56, y + 30)
    screen.stroke()
  end
  -- playhead
  screen.level(ui.playhead.brightness)
  screen.circle(x + 32, y + ui.playhead.height + 1, 3)
  screen.rect(x + 28, y + ui.playhead.height, 8, 4)
  screen.fill()
]]end


local function tile_x(x)
  return 21 * (x) + 1 
end

function ui.sampling(params_data, data, pos, len, active)
  local modes = {'ST', 'L+R', 'L', 'R'}
  local sources = {'EXT', 'INT' } 
  local src = sources[data.sampling.source]
  local mode = modes[data.sampling.mode] 
  local rec = data.sampling.rec and 'ON' or 'OFF'
  local play = data.sampling.play and 'ON' or 'OFF'
  
  set_brightness(-1, data.ui_index)
  
  screen.rect(tile_x(4), 8,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  screen.move( tile_x(4)  + 10, 8 + 7)
  screen.text_center('MODE')
  screen.move( tile_x(4)  + 10, 8 + 15)
  screen.text_center(mode)

  set_brightness(0, data.ui_index)
  screen.rect(tile_x(5) , 8,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  screen.move( tile_x(5)  + 10, 8 + 7)
  screen.text_center('SRC')
  screen.move( tile_x(5) + 10, 8 + 15)
  screen.text_center(src)


  set_brightness(1, data.ui_index)
  if data.sampling.rec then screen.level(15) end
  screen.rect( tile_x(0) , 26,  20, 17)
  screen.fill()
  

  screen.level(0) --- disp lock
  --screen.line_width(2)
  
  screen.circle( tile_x(0)  + 10, 26 + 9, 4.5)
  if data.sampling.rec then
    screen.circle( tile_x(0)  + 10, 26 + 9, 5)
    screen.fill() 
  else 
    screen.circle( tile_x(0)  + 10, 26 + 9, 4.5)
    screen.stroke() 
  end
  --screen.text_center('REC')

  set_brightness(2, data.ui_index)
  screen.rect( tile_x(1) , 26,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  --screen.move( tile_x(1)  + 10, 26 + 10)
  --screen.text_center('PLAY')
  screen.move(tile_x(1) + 7, 31)
  screen.line(tile_x(1) + 7 + 8, 31 + 8 * 0.5)
  screen.line(tile_x(1) + 7, 31 + 8)
  screen.close()
  if data.sampling.play then screen.fill() 
  else screen.stroke() end

  screen.line_width(1)


  set_brightness(3, data.ui_index)
  screen.rect( tile_x(2) , 26,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  --screen.move( tile_x(2)  + 10, 26 + 7)
  --screen.text_center('SAVE')
  --screen.move( tile_x(2) + 10, 26 + 15)
  --screen.text_center(data.sampling.slot)
  
  screen.rect( tile_x(2) + 5, 26 + 3, 12, 12)
  screen.stroke()
  set_brightness(3, data.ui_index)
  
  screen.rect( tile_x(2) + 16, 26 + 2,1,1)
  screen.fill()
  
  --set_brightness(3, data.ui_index)
  --screen.rect( tile_x(2) + 6, 26 + 2,8,5)
  --screen.fill()

  screen.level(0)  
  screen.rect( tile_x(2) + 7, 26 + 3,8,4)
  screen.stroke()
  
  screen.rect( tile_x(2) + 11, 26 + 3,2,2)
  screen.fill()
  
  screen.move( tile_x(2) + 10, 26 + 13)
  screen.text_center(data.sampling.slot)
  
  


  set_brightness(4, data.ui_index)
  screen.rect( tile_x(0) , 44,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  screen.move( tile_x(0)  + 10, 44 + 7)
  screen.text_center('STRT')
  screen.move( tile_x(0) + 10, 44 + 15)
  screen.text_center(data.sampling.start)

  set_brightness(5, data.ui_index)
  screen.rect( tile_x(1) , 44,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
  screen.move( tile_x(1)  + 10, 44 + 7)
  screen.text_center('END')
  screen.move( tile_x(1) + 10, 44 + 15)
  screen.text_center(util.round(len, 0.1))

  set_brightness(6, data.ui_index)
  screen.rect( tile_x(2) , 44,  20, 17)
  screen.fill()
  screen.level(0) --- disp lock
--[[  screen.move( tile_x(2)  + 10, 44 + 7)
  screen.text_center('CLR')
  screen.move( tile_x(2) + 10, 44 + 15)
  screen.text_center('')
  ]]
  
  screen.move( tile_x(2) + 10, 44 + 15)
  screen.rect(tile_x(2) + 7, 44 + 7, 8, 8)
  screen.rect(tile_x(2) + 6, 44 + 5, 10, 2)
  
  screen.stroke()

  screen.rect(tile_x(2) + 9, 44 + 3, 1, 1)
  screen.rect(tile_x(2) + 10, 44 + 2, 1, 1)
  screen.rect(tile_x(2) + 11, 44 + 3, 1, 1)
  
  
  screen.rect(tile_x(2) + 8, 44 + 8, 1, 5)
  screen.rect(tile_x(2) + 10, 44 + 8, 1, 5)
  screen.rect(tile_x(2) + 12, 44 + 8, 1, 5)
  
  screen.fill()
  
  set_brightness(6, data.ui_index)
  screen.rect(tile_x(2) + 6, 44 + 14, 1, 1)
  screen.rect(tile_x(2) + 14, 44 + 14, 1, 1)
  screen.rect(tile_x(2) + 5, 44 + 4, 1, 1)
  screen.rect(tile_x(2) + 15, 44 + 4, 1, 1)
  
  screen.fill()
 -- ui.tile(9, 'MODE', pos, data.ui_index)
--[[  ui.tile(6, 'SRC', src, data.ui_index)
  ui.tile(7, 'REC', rec, data.ui_index)
  ui.tile(8, 'STRT',  data.sampling.start, data.ui_index)
  ui.tile(9, 'END', data.sampling.length, data.ui_index)
  ui.tile(15, 'PLAY', play, data.ui_index)
  ui.tile(16, 'SAVE', '', data.ui_index)
  ui.tile(17, 'CLR', '', data.ui_index)]]
  screen.level(2)
  screen.rect(1 , 8,  83, 17)
  
  screen.fill()
  screen.rect(65, 27, 61 , 34 )
  screen.stroke()
  screen.level(0)
  screen.move(3, 15)
  screen.text('L')
  screen.move(3, 23)
  screen.text('R')
  screen.stroke()
  screen.rect(8, 10, data.in_l, 5)
  screen.rect(8, 18, data.in_r, 5)
  screen.fill()
  screen.level(2)
  screen.stroke()
  
  if active then update_reel() end
  draw_reel(45, 38)
  screen.stroke()
  
  screen.level(5)
  screen.rect(65 , 58, 1+ util.clamp(pos, 0, 59), 2)
  screen.fill()
  screen.level(0)
  screen.rect(65 , 58, util.clamp(data.sampling.start, 0, 59), 2)
  
  screen.fill()

  
end


return ui