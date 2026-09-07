local addonName=...
local DB
local frame
local bossBox,diffBox,editBox,leadBox,status
local activeTag="DFT_PERSONAL_TACTICS"
local currentContext
local mod

local function dft()
 return _G.DFT and select(1,unpack(_G.DFT))
end

local function difficultyCode(value)
 if value==14 or value=="N" or value=="Normal" then return "N" end
 if value==15 or value=="H" or value=="Heroic" then return "H" end
 if value==16 or value==233 or value=="M" or value=="Mythic" then return "M" end
 return nil
end

local function contextKey(encID,diff)
 return tostring(encID)..":"..tostring(difficultyCode(diff)or diff)
end

local function parseLine(line)
 local minutes,seconds,text=line:match("^%s*{%s*([%d%.]+)%s*:%s*([%d%.]+)%s*}%s*(.-)%s*$")
 minutes,seconds=tonumber(minutes),tonumber(seconds)
 if not minutes or not seconds or minutes<0 or seconds<0 or seconds>=60
 or not text or text=="" then return nil end
 return {time=minutes*60+seconds,text=text}
end

local function parseText(text)
 local out,invalid={},{}
 for line in (text.."\n"):gmatch("(.-)\n") do
  if line:match("%S") then
   local item=parseLine(line)
   if item then out[#out+1]=item else invalid[#invalid+1]=line end
  end
 end
 table.sort(out,function(a,b)return a.time<b.time end)
 return out,invalid
end

local function serialize(items)
 local lines={}
 for _,item in ipairs(items or{})do
  lines[#lines+1]=string.format("{0:%04.1f} %s",item.time,item.text)
 end
 return table.concat(lines,"\n")
end

local function selectedContext()
 local encID=tonumber(bossBox and bossBox:GetText()or"")
 if not encID then return nil end
 local diff=difficultyCode(diffBox and diffBox:GetText()or"M")
 if not diff then return nil end
 return encID,diff
end

local function getItems(encID,diff)
 local key=contextKey(encID,diff)
 DB.boards[key]=DB.boards[key]or{}
 return DB.boards[key]
end

local function refreshEditor()
 local encID,diff=selectedContext()
 if not encID then return end
 editBox:SetText(serialize(getItems(encID,diff)))
 status:SetText(string.format("%d_%s",encID,diff))
end

local function saveEditor()
 local encID,diff=selectedContext()
 if not encID then status:SetText("Boss ID 无效");return end
 local items,invalid=parseText(editBox:GetText()or"")
 if#invalid>0 then status:SetText("未保存：格式错误 "..invalid[1]);return end
 DB.boards[contextKey(encID,diff)]=items
 DB.selectedBoss=encID
 DB.selectedDiff=diff
 status:SetText(string.format("已保存 %d 条提醒",#items))
end

local function schedule(encID,diff,t0)
 local ns=dft()
 diff=difficultyCode(diff)
 if not diff then return end
 if not(ns and ns.Notify and ns.Notify.Schedule)then return end
 local items=DB.boards[contextKey(encID,diff)]or{}
 local lead=math.max(0,tonumber(DB.leadTime)or 5)
 ns.Notify:CancelByTag(activeTag)
 for index,item in ipairs(items)do
  local target=t0+item.time
  local fireAt=math.max(GetTime(),target-lead)
  ns.Notify:Schedule({
   id=activeTag.."_"..index,tag=activeTag,fireAt=fireAt,
   channels={BAR={text=item.text,duration=math.max(0.1,target-fireAt)},TTS={text=item.text}},
  })
 end
end

local function openEditor()
 if not frame then
  frame=CreateFrame("Frame","DFTPersonalTacticsFrame",UIParent,"BackdropTemplate")
  frame:SetSize(520,420);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function(self)self:StartMoving()end)
  frame:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
  frame:SetBackdropColor(0.04,0.04,0.06,0.98);frame:SetBackdropBorderColor(0.3,0.3,0.4,1)
  local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",16,-14);title:SetText("DFT 个人战术板")
  local hint=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");hint:SetPoint("TOPLEFT",16,-44);hint:SetPoint("TOPRIGHT",-16,-44);hint:SetJustifyH("LEFT");hint:SetText("一行一个提醒：{0:04} 王者大军；难度支持 N / H / M")
  local bossLabel=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");bossLabel:SetPoint("TOPLEFT",16,-78);bossLabel:SetText("Boss ID")
  bossBox=CreateFrame("EditBox",nil,frame,"InputBoxTemplate");bossBox:SetSize(90,24);bossBox:SetPoint("LEFT",bossLabel,"RIGHT",8,0);bossBox:SetAutoFocus(false)
  local diffLabel=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");diffLabel:SetPoint("LEFT",bossBox,"RIGHT",18,0);diffLabel:SetText("难度 N/H/M")
  diffBox=CreateFrame("EditBox",nil,frame,"InputBoxTemplate");diffBox:SetSize(45,24);diffBox:SetPoint("LEFT",diffLabel,"RIGHT",8,0);diffBox:SetAutoFocus(false);diffBox:SetMaxLetters(1)
  local leadLabel=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");leadLabel:SetPoint("LEFT",diffBox,"RIGHT",18,0);leadLabel:SetText("提前秒数")
  leadBox=CreateFrame("EditBox",nil,frame,"InputBoxTemplate");leadBox:SetSize(45,24);leadBox:SetPoint("LEFT",leadLabel,"RIGHT",8,0);leadBox:SetAutoFocus(false);leadBox:SetMaxLetters(4)
  local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",16,-112);scroll:SetPoint("BOTTOMRIGHT",-32,54)
  editBox=CreateFrame("EditBox",nil,scroll);editBox:SetMultiLine(true);editBox:SetAutoFocus(false);editBox:SetFontObject(GameFontHighlight);editBox:SetWidth(450);editBox:SetTextColor(1,1,1,1);editBox:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);scroll:SetScrollChild(editBox)
  local save=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");save:SetSize(90,24);save:SetPoint("BOTTOMRIGHT",-16,16);save:SetText("保存");save:SetScript("OnClick",saveEditor)
  local close=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");close:SetSize(90,24);close:SetPoint("RIGHT",save,"LEFT",-8,0);close:SetText("关闭");close:SetScript("OnClick",function()frame:Hide()end)
  status=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");status:SetPoint("BOTTOMLEFT",16,20);status:SetTextColor(0.5,0.8,1,1)
  bossBox:SetScript("OnEnterPressed",refreshEditor);diffBox:SetScript("OnEnterPressed",refreshEditor);leadBox:SetScript("OnEnterPressed",function(self)DB.leadTime=math.max(0,tonumber(self:GetText())or 5);self:ClearFocus()end)
 end
 bossBox:SetText(tostring(DB.selectedBoss or(currentContext and currentContext.encID)or""))
 diffBox:SetText(DB.selectedDiff or(currentContext and difficultyCode(currentContext.difficulty))or"M")
 leadBox:SetText(tostring(DB.leadTime or 5));frame:Show();refreshEditor()
end

local function buildSettings(panel)
 local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",20,-20);title:SetText("DFT 个人战术板")
 local enabled=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");enabled:SetPoint("TOPLEFT",16,-60);enabled.text=enabled:CreateFontString(nil,"OVERLAY","GameFontNormal");enabled.text:SetPoint("LEFT",enabled,"RIGHT",6,0);enabled.text:SetText("启用个人爆发提醒");enabled:SetChecked(DB.enabled)
 enabled:SetScript("OnClick",function(self)DB.enabled=self:GetChecked()and true or false;if not DB.enabled then local ns=dft();if ns and ns.Notify then ns.Notify:CancelByTag(activeTag)end end end)
 local lead=panel:CreateFontString(nil,"OVERLAY","GameFontNormal");lead:SetPoint("TOPLEFT",20,-105);lead:SetText("提前倒数秒数")
 local leadInput=CreateFrame("EditBox",nil,panel,"InputBoxTemplate");leadInput:SetSize(60,24);leadInput:SetPoint("LEFT",lead,"RIGHT",10,0);leadInput:SetAutoFocus(false);leadInput:SetText(tostring(DB.leadTime or 5));leadInput:SetScript("OnEnterPressed",function(self)DB.leadTime=math.max(0,tonumber(self:GetText())or 5);self:ClearFocus()end)
 local edit=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");edit:SetSize(160,26);edit:SetPoint("TOPLEFT",20,-145);edit:SetText("打开个人战术编辑器");edit:SetScript("OnClick",openEditor)
 local format=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");format:SetPoint("TOPLEFT",20,-190);format:SetText("格式示例：\n{0:04} 王者大军\n{0:35} 第二轮爆发\n\n{0:04} 表示 Boss 开战后 4 秒。")
end

SLASH_DFTPERSONALTACTICS1="/dftpt"
SlashCmdList.DFTPERSONALTACTICS=function(msg)
 local cmd=(msg or""):match("^%s*(%S+)")
 if cmd=="on"or cmd=="off"then
  print("|cff66ff66[DFT个人战术板]|r 请在 WoW 插件设置中修改启用状态")
  return
 end
 openEditor()
end

local event=CreateFrame("Frame")
event:RegisterEvent("ADDON_LOADED")
event:SetScript("OnEvent",function(_,eventName,name)
 if eventName~="ADDON_LOADED"or name~=addonName then return end
 DB=_G.DFTPersonalTacticsDB or{};_G.DFTPersonalTacticsDB=DB;DB.boards=DB.boards or{};if DB.leadTime==nil then DB.leadTime=5 end;DB.enabled=DB.enabled~=false
 local ns=dft()
 if ns and ns.On then
   mod=ns:NewModule("DFTPersonalTactics","DFT 个人战术板")
   mod.db=DB
   mod.options.Load=function(self)buildSettings(self)end
   buildSettings(mod.options)
   mod.options.isLoaded=true
   if Settings and Settings.RegisterCanvasLayoutCategory then
    local category=Settings.RegisterCanvasLayoutCategory(mod.options,"DFT 个人战术板")
    Settings.RegisterAddOnCategory(category)
   end
   ns:On("BOSS_ENGAGED",function(encID,difficulty,t0,info)currentContext=info or{encID=encID,difficulty=difficulty};if DB.enabled then schedule(encID,difficulty,t0)end end)
  ns:On("BOSS_DISENGAGED",function()if ns.Notify then ns.Notify:CancelByTag(activeTag)end end)
 end
 print("|cff66ff66[DFT个人战术板]|r 输入 /dftpt 编辑")
end)
