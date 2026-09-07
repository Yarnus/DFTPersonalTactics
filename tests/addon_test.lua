local frames={}

local function object(kind,parent)
 local value={kind=kind,parent=parent,children={},scripts={},text=""}
 if parent then parent.children[#parent.children+1]=value end
 function value:CreateFontString()
  local child=object("FontString",self)
  return child
 end
 function value:SetScript(name,callback)self.scripts[name]=callback end
 function value:SetText(text)self.text=tostring(text or"")end
 function value:GetText()return self.text end
 function value:SetMultiLine(enabled)self.multiLine=enabled end
 function value:SetChecked(enabled)self.checked=enabled end
 function value:GetChecked()return self.checked end
 function value:Show()self.shown=true end
 function value:Hide()self.shown=false end
 function value:IsShown()return self.shown end
 function value:SetScrollChild(child)self.scrollChild=child end
 function value:RegisterEvent(name)self.event=name end
 function value:SetPoint()end
 function value:SetSize()end
 function value:SetFrameStrata()end
 function value:SetMovable()end
 function value:EnableMouse()end
 function value:RegisterForDrag()end
 function value:SetBackdrop()end
 function value:SetBackdropColor()end
 function value:SetBackdropBorderColor()end
 function value:SetAutoFocus()end
 function value:SetMaxLetters()end
 function value:SetFontObject()end
 function value:SetWidth()end
 function value:SetTextColor()end
 function value:SetJustifyH()end
 function value:ClearFocus()end
 function value:StartMoving()end
 function value:StopMovingOrSizing()end
 return value
end

UIParent=object("UIParent")
GameFontNormalLarge={}
GameFontHighlightSmall={}
GameFontNormalSmall={}
GameFontHighlight={}
GameFontNormal={}

function CreateFrame(kind,name,parent,template)
 local value=object(kind,parent)
 value.template=template
 frames[#frames+1]=value
 if name then _G[name]=value end
 return value
end

Settings={}
SlashCmdList={}
function Settings.RegisterCanvasLayoutCategory(panel,name)return{panel=panel,name=name}end
function Settings.RegisterAddOnCategory(category)Settings.category=category end

local events={}
local scheduled={}
local cancelled={}
local T={Notify={}}
function T:NewModule(name,displayName)
 local module={name=name,displayName=displayName,options=CreateFrame("Frame",nil,UIParent)}
 return module
end
function T:On(name,callback)events[name]=callback end
function T.Notify:Schedule(spec)scheduled[#scheduled+1]=spec end
function T.Notify:CancelByTag(tag)cancelled[#cancelled+1]=tag end
DFT={T}

local now=100
function GetTime()return now end

DFTPersonalTacticsDB={
 boards={
  ["999:M"]={{time=93.9,text="Burst with {spell:42650}"}},
  ["999:H"]={{time=10,text="Heroic reminder"}},
 },
 selectedBoss=999,
 selectedDiff="M",
 leadTime=5,
}

assert(loadfile("DFTPersonalTactics.lua"))("DFTPersonalTactics")
local loader=frames[#frames]
assert(loader.event=="ADDON_LOADED","addon event was not registered")
loader.scripts.OnEvent(loader,"ADDON_LOADED","DFTPersonalTactics")
assert(Settings.category and Settings.category.name=="DFT 个人战术板","settings fallback was not registered")

SlashCmdList.DFTPERSONALTACTICS("")
local editor=DFTPersonalTacticsFrame
assert(editor and editor.shown,"/dftpt did not open the editor")

local function descendants(root,out)
 out=out or{}
 for _,child in ipairs(root.children)do
  out[#out+1]=child
  descendants(child,out)
 end
 return out
end

local bossBox,diffBox,editBox,saveButton,status
for _,child in ipairs(descendants(editor))do
 if child.multiLine then editBox=child end
 if child.template=="InputBoxTemplate"and not bossBox then
  bossBox=child
 elseif child.template=="InputBoxTemplate"and not diffBox then
  diffBox=child
 end
 if child.template=="UIPanelButtonTemplate"and child.text=="保存"then saveButton=child end
 if child.kind=="FontString"and child.text=="999_M"then status=child end
end
assert(bossBox and diffBox and editBox and saveButton and status,"editor controls were not created")
assert(editBox.text=="{time:01:33.9} - Burst with {spell:42650}","stored reminders did not render as MRT")

editBox:SetText(table.concat({
 "{time:03:06.8} - Burst with {spell:42650}",
 "",
 "{time:00:02.6} - {spell:42650}",
 "{time:01:33.9} - Use cooldowns",
},"\n"))
saveButton.scripts.OnClick()
local board=DFTPersonalTacticsDB.boards["999:M"]
assert(#board==3 and board[1].time==2.6 and board[2].time==93.9 and board[3].time==186.8,"valid lines were not sorted and saved")
assert(board[1].text=="{spell:42650}"and board[3].text=="Burst with {spell:42650}","reminder bodies changed")

local savedBoard=board
local invalid={
 "{time:00:60} - Invalid seconds",
 "{time:00:60.1} - Invalid seconds",
 "{time:00:04} - ",
 "{time:00:04} Missing separator",
 "{0:04} Old format",
 "{time:00:54.8,p2} - Dynamic",
}
for _,line in ipairs(invalid)do
 editBox:SetText(line)
 saveButton.scripts.OnClick()
 assert(DFTPersonalTacticsDB.boards["999:M"]==savedBoard,"invalid input replaced the saved board: "..line)
end
assert(status.text:match("不支持 Dynamic Timer"),"dynamic timer rejection was not explicit")

events.BOSS_ENGAGED(999,16,now,{encID=999,difficulty=16})
assert(#scheduled==3,"encounter did not schedule every reminder")
assert(scheduled[1].channels.BAR.text=="{spell:42650}","BAR body changed before DFT Notify")
assert(scheduled[3].channels.TTS.text=="Burst with {spell:42650}","TTS body changed before DFT Notify")
assert(scheduled[1].fireAt==100 and math.abs(scheduled[1].channels.BAR.duration-2.6)<0.00001,"lead time scheduling was incorrect")
events.BOSS_DISENGAGED()
assert(cancelled[#cancelled]=="DFT_PERSONAL_TACTICS","encounter end did not cancel reminders")
assert(#DFTPersonalTacticsDB.boards["999:H"]==1,"Heroic board was not kept distinct")
DFTPersonalTacticsDB.boards["999:N"]={{time=4,text="Normal reminder"}}
events.BOSS_ENGAGED(999,14,now,{encID=999,difficulty=14})
assert(scheduled[#scheduled].channels.TTS.text=="Normal reminder","Normal board was not kept distinct")

print("addon tests passed")
