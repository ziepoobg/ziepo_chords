 --[[
 * ReaScript Name: Chords (Ziepo)
 * Description: Display Chords from the Track Chords.
 * Instructions: Create a Track, name it Chords (!important), insert an item and add some Take markers to it. Finally run the script to update 
 * Author: Silvio Mechow
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]

font_size  = 100
font_name = "Arial"
window_w = 640
window_h = 270
chords_track = nil
chords = {}
chordkeys = {}
proj_guid_last = ""


function INT2RGB(color_int)
  if color_int ~= nil and color_int >= 0 then
      R = color_int & 255
      G = (color_int >> 8) & 255
      B = (color_int >> 16) & 255
  else
      R, G, B = 255, 255, 255
  end
  rgba(R, G, B, 255)
end

function rgba(r, g, b, a)
  if a ~= nil then gfx.a = a/255 else a = 255 end
  gfx.r = r/255
  gfx.g = g/255
  gfx.b = b/255
end

function HexToRGB(value)
  local hex = value:gsub("#", "")
  local R = tonumber("0x"..hex:sub(1,2))
  local G = tonumber("0x"..hex:sub(3,4))
  local B = tonumber("0x"..hex:sub(5,6))
  
  if R == nil then R = 0 end
  if G == nil then G = 0 end
  if B == nil then B = 0 end
  
  gfx.r = R/255
  gfx.g = G/255
  gfx.b = B/255
end

function color(r,g,b)
  if r == nil then r = 0 end
  if g == nil then g = 0 end
  if b == nil then b = 0 end
  
  gfx.r = r/255
  gfx.g = g/255
  gfx.b = b/255
end

function debug(message)
  reaper.ShowConsoleMsg(tostring(message) .. '\n')
end

function adjust_font_size(mouse_wheel_val)
  if mouse_wheel_val > 0 and font_size < 200 then font_size = font_size + 4 end
  if mouse_wheel_val < 0 and font_size > 60 then font_size = font_size - 4 end
  gfx.setfont(1, font_name, font_size, 'b');
  gfx.mouse_wheel = 0;
end

function get_nearest_chordkey(pos)
    local index = nil
    local key = nil
    for i, v in pairs(chordkeys) do
      if v <= pos then 
        index = i
        key   = v 
      end
    end
    if key == nil then 
      index = 0
      key   = chordkeys[0] 
    end
    return index,key
end

function ProjGuidChange()
  local ret, proj_guid = reaper.GetProjExtState(0,"chords","proj_guid")
  local changed = false

  if ret == 1 then
    if proj_guid ~= proj_guid_last then
      changed = true
    end
  else
    proj_guid = reaper.genGuid("")
    reaper.SetProjExtState(0,"chords","proj_guid",proj_guid,true)
    changed = true
  end

  proj_guid_last = proj_guid

  --if changed==true then reaper.ShowConsoleMsg(tostring(changed)) end

  return changed
end

function Quit()
  d,x,y,w,h=gfx.dock(-1,0,0,0,0)
  reaper.SetExtState("chords","wndw",w,true)
  reaper.SetExtState("chords","wndh",h,true)
  reaper.SetExtState("chords","dock",d,true)
  reaper.SetExtState("chords","wndx",x,true)
  reaper.SetExtState("chords","wndy",y,true)
  gfx.quit()
end
reaper.atexit(Quit)

function IsInTime( s, start_time, end_time )
  if s >= start_time and s <= end_time then return true end
  return false
end

function DrawProgressBar() -- Idea from Heda's Notes Reader
  progress_percent = 0
  if chordkeys[cur_chordkey_index] ~=nil and chordkeys[cur_chordkey_index+1] ~= nil then progress_percent = (play_pos-chordkeys[cur_chordkey_index])/(chordkeys[cur_chordkey_index+1]-chordkeys[cur_chordkey_index]) end
  rect_h = 30
  
  --color(252, 186, 3)
  INT2RGB(region_color)
  --gfx.rect( 0, 0, gfx.w*progress_percent, rect_h )
  gfx.rect(0, 0, gfx.w*progress_percent, rect_h )
  gfx.y = rect_h * 2
end

--// INIT //--
function init(window_w, window_h)

  _,measureoffest = reaper.TimeMap2_timeToBeats(0,reaper.GetProjectTimeOffset(0,false))
  --measureoffest = reaper.SNM_GetIntConfigVar('projmeasoffs', 0)

  gfx.init("Chords by Ziepo", 
    tonumber(reaper.GetExtState("chords","wndw")) or _gfxw,
    tonumber(reaper.GetExtState("chords","wndh")) or _gfxh,
    tonumber(reaper.GetExtState("chords","dock")) or 0,
    tonumber(reaper.GetExtState("chords","wndx")) or 100,
    tonumber(reaper.GetExtState("chords","wndy")) or 100)
   
  gfx.setfont(1, font_name, font_size, 'b')
  
  if chords_track == nil then
    cnt=reaper.CountTracks()
    for t=1,cnt do
      track=reaper.GetTrack(0,t-1)
      ok,name=reaper.GetTrackName(track,"")
      if name=="Chords" then 
        chords_track = track 
        break
      end
    end
    
    if chords_track ~= nil then
      item_count = reaper.GetTrackNumMediaItems(chords_track)
      if item_count > 0 then
        for i=0,item_count do
          --item = reaper.GetMediaItem(0,i)
          item = reaper.GetTrackMediaItem(chords_track,i)
          if item then 
            item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            take = reaper.GetActiveTake(item)
            if take then
              take_rate = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE" )
              take_marker_count = reaper.GetNumTakeMarkers(take)
              take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
              if take_marker_count > 0 then 
                for ip = take_marker_count - 1, 0, - 1 do
                  pos,chord,tcolor = reaper.GetTakeMarker(take,ip)
                  proj_pos = item_pos - take_offset + pos / take_rate
                  if IsInTime(proj_pos, item_pos, item_pos + item_len) then
                    chords[proj_pos] = chord
                  end
                end
              else
                source = reaper.GetMediaItemTake_Source(take)
                if source then
                  source_type = reaper.GetMediaSourceType(source, "")
                  if tostring(source_type) == "MIDI" then
                    _,notecnt,ccevtcnt,textsyxevtcnt = reaper.MIDI_CountEvts(take)
                    if textsyxevtcnt > 0 then
                      for i=0,textsyxevtcnt do
                        _,selected,muted,ppqpos,ttype,chord = reaper.MIDI_GetTextSysexEvt(take,i)
                        if ttype == 1 then -- support only text event
                          proj_pos = reaper.MIDI_GetProjTimeFromPPQPos(take,ppqpos)
                          chords[proj_pos] = chord
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        for n in pairs(chords) do table.insert(chordkeys, n) end
        table.sort(chordkeys)
      end
    end
  end
  _, ptitle = reaper.GetSetProjectInfo_String(0,"PROJECT_TITLE",'',false)
end

function run()
  
  if ProjGuidChange()==true then
    chords = {}
    chordkeys = {}
    chords_track = nil
    init(window_w, window_h)
  end
  
  mwbg = reaper.GetThemeColor("col_main_bg2")
  INT2RGB(mwbg)
  --color(22,22,22)
  gfx.rect( 0, 0, gfx.w, gfx.h )
  
  -- PLAY STATE
  play_state = reaper.GetPlayState()
  if play_state == 0 or play_state == 2 then play_pos = reaper.GetCursorPosition()
  else play_pos = reaper.GetPlayPosition2()
  end

  cur_chordkey_index,cur_chordkey = get_nearest_chordkey(play_pos)

  line1_txt_previous  = '-'
  line1_txt_upcomming = '-'
  line1_txt = '--'
  if cur_chordkey ~= nil then
    if chords[cur_chordkey] ~= nil then 
      line1_txt = chords[cur_chordkey]
      if chords[chordkeys[cur_chordkey_index+1]] ~= nil then
        line1_txt_upcomming = chords[chordkeys[cur_chordkey_index+1]]
      end
      if chords[chordkeys[cur_chordkey_index-1]] ~= nil then
        line1_txt_previous = chords[chordkeys[cur_chordkey_index-1]]
      end
    end
    else 
      if chords[chordkeys[1]] ~= nil then line1_txt_upcomming = chords[chordkeys[1]] end
  end
  
  line2_txt = reaper.format_timestr_pos(play_pos,'',2)
  
  line3_txt = ptitle
  marker_idx, region_idx = reaper.GetLastMarkerAndCurRegion(0, play_pos)
  if region_idx >= 0 then 
    retval, is_region, region_start, region_end, region_name, markrgnindexnumber, region_color = reaper.EnumProjectMarkers3(0, region_idx)
    line3_txt = region_name
    
    --reaper.StuffMIDIMessage(1,255*16+6,1+255,0110100001100101011011000110110001101111001000000111011101101111011100100110110001110011)
  end
  
  gfx.setfont(1, font_name, font_size, 'b')
  line1_w,line1_h = gfx.measurestr(line1_txt)
  color(252, 186, 3)
  gfx.x = 0.5*(gfx.w-line1_w);
  gfx.y = 0.5*(gfx.h-font_size)-34;
  gfx.printf(line1_txt);
  
  color(255, 255, 255)
  gfx.setfont(1, font_name, font_size-40, 'b')
  line1u_w,line1u_h = gfx.measurestr(line1_txt_upcomming)
  gfx.x = (0.5*gfx.w) + (0.5*line1_w) + 80
  gfx.y = 0.5*(gfx.h-font_size)
  gfx.printf(line1_txt_upcomming)
  
  color(60, 60,60)
  gfx.setfont(1, font_name, font_size-40, 'b')
  line1p_w,line1p_h = gfx.measurestr(line1_txt_previous)
  gfx.x = (0.5*gfx.w)-(0.5*line1_w)-line1p_w - 80
  gfx.y = 0.5*(gfx.h-font_size)
  gfx.printf(line1_txt_previous)
  
  color(160,160,160)
  gfx.setfont(1, font_name, font_size-60, 'b')
  line2_w,line2_h = gfx.measurestr(line2_txt)
  gfx.x = 0.5*(gfx.w-line2_w)
  gfx.y = gfx.y + line1_h - 40;
  gfx.printf(line2_txt)
  
  gfx.setfont(1, font_name, font_size-70, 'b')
  line3_w,line3_h = gfx.measurestr(line3_txt)

  if region_color ~=nil then
    INT2RGB(region_color)
    gfx.rect(0.5*(gfx.w-line3_w-20),gfx.y+line1_h-line2_h-10,line3_w+20,line3_h+8)
  end
  
  color(255,255,255)
  gfx.x = 0.5*(gfx.w-line3_w)
  gfx.y = gfx.y + line1_h - line2_h - 6;
  gfx.printf(line3_txt)
  
  if cur_chordkey ~= nil then
    if chords[cur_chordkey] ~= nil then 
      if chords[chordkeys[cur_chordkey_index+1]] ~= nil then DrawProgressBar() end
    end
  end
  
  gfx.update()
  if gfx.getchar() ~= 27 then reaper.defer(run) else Quit() end
end

-- RUN
init(window_w, window_h)
run()
