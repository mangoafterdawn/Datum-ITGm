-- adapted from Technique.lua

-- created by mang;
	-- i am well aware that my coding may not be very optimized. please let me know if you run into any issues
	-- running this Visual Style (whether that be framerate issues, visual glitches and edge cases.)
	-- if you do take the time to look through my code and have any optimizations that you can share with me,
	-- i would really appreciate that. i do not have much knowledge of the SL codebase, so if anything here can
	-- be done in a simpler manner that would be awesome. i just coded this kind of like a NotITG modfile lol

local file = ...
local randomindex = math.random(1, 12)
local anim_data = {
	color_add = {-0.75,0,0,-0.75,-0.75,-0.75,0,-0.75,0,-0.75},
	diffusealpha = {0.05,0.2,0.1,0.1,0.1,0.1,0.1,0.05,0.1,0.1},
	xy = {0,40,80,120,200,280,360,400,480,560},
	texcoordvelocity = {{0.03,0.01},{0.03,0.02},{0.03,0.01},{0.02,0.02},{0.03,0.03},{0.02,0.02},{0.03,0.01},{-0.03,0.01},{0.05,0.03},{0.03,0.04}}
}

-- the screens for which a layout has been made. 
-- if a screen not on this list is pushed to the top, 
-- we will check for  these "known" screens to act as a failsafe
-- so there isn't any snapping or unintended behaviors.
local knownScreens = {
	"ScreenTitleMenu",
	"ScreenSelectMusic",
	"ScreenEvaluation*",
}
local currentKnownScreen = "ScreenTitleMenu"
-- the actor table used in the update function
local tActors = {}

-- my favorite ease <3 love u outExpo
local function easeOutExpo(t,b,c,d)
	if t == d then
		return b + c
	else
		return c * 1.001 * (-(2^(-10 * t / d)) + 1) + b
	end
end

local function GetCurrentScreen(name)
	if SCREENMAN:GetTopScreen() then
		if name then
			return SCREENMAN:GetTopScreen():GetName()
		else
			return SCREENMAN:GetTopScreen()
		end
	end
end

--//////////////////////////////////////////////////
--                 OPTION SELECT
--//////////////////////////////////////////////////

-- options are stored in "DatumOptions.lua" which
-- should be in the same directory as this .lua file
local path = THEME:GetPathB("","_shared background/Datum/DatumOptions.lua")
local DatumOptions = dofile(path)

--//////////////////////////////////////////////////
--                  STYLE CODE
--//////////////////////////////////////////////////

local function shiftActiveColorHue()
	local currentHSV = ColorToHSV(GetHexColor(SL.Global.ActiveColorIndex, true))
	local newHSV = {
		["Hue"] = currentHSV["Hue"] - DatumOptions.DATUM_HUE_SHIFT_AMOUNT,
		["Sat"] = 1.0,
		["Value"] = currentHSV["Value"],
		["Alpha"] = currentHSV["Alpha"],
	}
	return HSVToColor(newHSV)
end

local doGayMode
if DatumOptions.AUTO_PRIDE_ENABLED and MonthOfYear()+1 == 6 then
	print("Datum :: it's June! happy Pride Month!")
	doGayMode = true
elseif DatumOptions.GAY_MODE_ENABLED then
	doGayMode = true
else
	doGayMode = false
end

--transition variables
local transitionEase
local addEase = {
	{length=6 ,v=0},
	{length=12,v=0}
}
local knownScreenUptime = 0

--//////////////////////////////////////////////////
--                 UPDATE LOOP
--//////////////////////////////////////////////////

local function updater(self,delta)
	-- time since game start
	local time = GetTimeSinceStart()
	-- time since last known screen transition
	knownScreenUptime = knownScreenUptime + delta * DatumOptions.TRANSITION_SPEED

	local screen
	if currentKnownScreen then
		screen = currentKnownScreen
	end

	-- input different lengths for the ease with a table
	for i = 1, #addEase do
		if time-7 > addEase[i].length then
			addEase[i].v = 0
		else
			addEase[i].v = easeOutExpo(time-7,1,0-1,addEase[i].length)
		end
	end

	if screen == "ScreenSelectMusic" then
		--tone down the movement of the model on the song select screen
		tActors["datumModel"]:rotationx(math.sin(time* 2/-29) * 3)
		tActors["datumModel"]:rotationy(math.sin(time* 2/ 23) * 5)
		tActors["datumModel"]:rotationz(math.sin(time* 2/ 31) * 3)
		-- move and rotate ring to a different position
		tActors["datumRing"]:rotationx(-60 + math.sin(time* 1/-29) * 2)
		tActors["datumRing"]:rotationy(-30 + math.cos(time* 1/-31) * 2)
	else
		-- default case (ScreenTitleMenu)
		tActors["datumModel"]:rotationx(math.sin(time* 5/-29) * 5)
		tActors["datumModel"]:rotationy(math.sin(time* 5/ 23) * 10 + addEase[1].v*-180)
		tActors["datumModel"]:rotationz(math.sin(time* 5/ 31) * 2)
		tActors["datumModel"]:y(SCREEN_CENTER_Y - 20 + addEase[2].v*30)

		tActors["datumRing"]:rotationx(-70 + math.sin(time* 1/-29) * 2 + addEase[2].v*20)
		tActors["datumRing"]:rotationy( 40 + math.cos(time* 1/-31) * 2)
	end

	if doGayMode then
		local currentHSV = ColorToHSV(GetHexColor(SL.Global.ActiveColorIndex, true))
		local newHSV = {
			["Hue"] = currentHSV["Hue"],
			["Sat"] = 1.0,
			["Value"] = currentHSV["Value"],
			["Alpha"] = currentHSV["Alpha"],
		}
		if DatumOptions.DATUM_HUE_SHIFT_ENABLED then
			newHSV["Hue"] = (newHSV["Hue"] + time * DatumOptions.GAY_MODE_SPEED)%360
			tActors["datumMask"]:diffuse(HSVToColor(newHSV))
			newHSV["Hue"] = (newHSV["Hue"] - DatumOptions.DATUM_HUE_SHIFT_AMOUNT)%360
			tActors["datumMask"]:diffusetopedge(HSVToColor(newHSV))
		else
			newHSV["Hue"] = (newHSV["Hue"] + time * DatumOptions.GAY_MODE_SPEED)%360
			tActors["datumMask"]:diffusetopedge(HSVToColor(newHSV))
			tActors["datumMask"]:diffuse(HSVToColor(newHSV))
		end
	end
	tActors["datumMask"]:diffusealpha(DatumOptions.DATUM_OPACITY/100 + addEase[1].v*-3.8)

	for i = 1,3 do
		tActors["sPolygonFrame"..i]:GetChild("sPolygon")
		:diffusealpha(DatumOptions.SINE_OPACITY/100 - addEase[1].v*1.8)
		:rotationy(time * 10 + addEase[1].v*-80)
	end

	-- //////////////////////////////////
	--        SCREEN TRANSITIONS
	-- //////////////////////////////////

	if DatumOptions.DO_SCREEN_TRANSITIONS then
		local transitionTime = 2
		if knownScreenUptime > transitionTime then
			transitionEase = 0
		else
			transitionEase = easeOutExpo(knownScreenUptime,1,0-1,transitionTime)
		end
		-- only run this code while it is transitioning
		if knownScreenUptime < transitionTime and DatumOptions.ENABLE_BAR_TRANSITION then
			if time > 12 then				
				-- the brightness should change at a very fast rate (hence why we do x^6)
				local brightness = 20 - ((transitionEase^6)*20)
				-- while cropping can happen at a slower rate (x^2)
				local crop = 1-(transitionEase)^2
				tActors["transitionQuadTop"]:cropbottom(crop)
				tActors["transitionQuadTop"]:diffuse(brightness/255,brightness/255,brightness/255,1)
				tActors["transitionQuadTop"]:visible(1)

				tActors["transitionQuadBottom"]:croptop(crop)
				tActors["transitionQuadBottom"]:diffuse(brightness/255,brightness/255,brightness/255,1)
				tActors["transitionQuadBottom"]:visible(1)
			end
		else
			tActors["transitionQuadTop"]:playcommand("Init")

			tActors["transitionQuadBottom"]:playcommand("Init")
		end

		if knownScreenUptime < transitionTime then
			if screen == "ScreenSelectMusic" then
				local coverDiffuse = 5 - (5*transitionEase)
				local coverDiffuseBottom = 41 - (41*transitionEase)
				tActors["datumModel"]:y(SCREEN_CENTER_Y + transitionEase * 25)

				tActors["coverQuad"]
				:diffuse(coverDiffuse/255, coverDiffuse/255, coverDiffuse/255, 1)
				:diffusebottomedge(coverDiffuseBottom/255,coverDiffuseBottom/255,coverDiffuseBottom/255,1)
				:diffusealpha(0.7 + transitionEase*0.2)
			else
				tActors["datumModel"]:y(SCREEN_CENTER_Y - 20 + addEase[2].v*30 + transitionEase * 10)
			end
			tActors["datumMask"]:diffusealpha(DatumOptions.DATUM_OPACITY/100 - transitionEase^2 + addEase[1].v*-3.8)

			for i = 1,3 do
				local sines = tActors["sPolygonFrame"..i]:GetChild("sPolygon")
				-- only do the screen transitionEase after a sufficient amount of time has passed,
					-- so that it doesnt combine with the intro's ease.
					if time>12 then
					sines:diffusealpha(DatumOptions.SINE_OPACITY/100 - transitionEase - addEase[1].v*1.8)
					sines:rotationy(time * 10 + addEase[1].v*-80 - transitionEase*60)
				end
			end
		end

		-- transition the musicwheel elements
		if DatumOptions.MUSICWHEEL_TRANSITION ~= "SimplyLove" then
			if GetCurrentScreen():GetChild("MusicWheel") and knownScreenUptime < transitionTime then
				local parts = {
					"SectionExpanded",
					"SectionCollapsed",
					"SongName",
					"SongName"
				}
				local musicWheelItem = GetCurrentScreen():GetChild("MusicWheel"):GetChild("MusicWheelItem")
				for i = 1,#musicWheelItem do
					musicWheelItem[i]:diffusealpha(1-transitionEase*2)
					local transitionTime = 1
					if knownScreenUptime > transitionTime then
						transitionEase = 0
					else
						transitionEase = easeOutExpo(knownScreenUptime-(i*0.02),1,0-1,transitionTime)
					end
					for p = 1,#parts do
						local itemPart = musicWheelItem[i]:GetChild(parts[p])
						itemPart:cropright(transitionEase^4)
						if parts[p] == "SongName" then
							if DatumOptions.MUSICWHEEL_TRANSITION == "TextOnly" then
							itemPart:GetChild("Title"):cropright(transitionEase^2)
							itemPart:GetChild("Subtitle"):cropright(transitionEase^2)
							
							elseif DatumOptions.MUSICWHEEL_TRANSITION == "OpacityOnly" then
								itemPart:GetChild("Title"):diffusealpha(1-(transitionEase^6))
								itemPart:GetChild("Subtitle"):diffusealpha(1-(transitionEase^6))

							elseif DatumOptions.MUSICWHEEL_TRANSITION == "Full" then
								itemPart:GetChild("Title"):cropright(transitionEase^2)
								itemPart:GetChild("Subtitle"):cropright(transitionEase^2)
								
								itemPart:GetChild("Title"):diffusealpha(1-(transitionEase^6))
								itemPart:GetChild("Subtitle"):diffusealpha(1-(transitionEase^6))
							end
						else
							if DatumOptions.MUSICWHEEL_TRANSITION == "OpacityOnly" or DatumOptions.MUSICWHEEL_TRANSITION == "Full" then
								itemPart:diffusealpha(1-(transitionEase^8))
							end
						end
					end
				end
			end
		end
	end
end

--//////////////////////////////////////////////////
--                   ACTORS
--//////////////////////////////////////////////////

local t = Def.ActorFrame {
	Name = "Datum",
	InitCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		self:visible(style == "Datum")
		tActors = self:GetChildren()
		--[[
			local a = self:GetChildren()
			for k,v in pairs(a) do
				tActors[k] = {v,screen="None"}
			end
		]]
		if DatumOptions.UPDATE_LOOP_ENABLED then
			self:SetUpdateFunction(updater)
		end
	end,
	OnCommand=function(self) self
		:fov(120)
		:accelerate(0.8)
		:diffusealpha(1)
	end,

	HideCommand=function(self) self:visible(false) end,

	VisualStyleSelectedMessageCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		if style == "Datum" then
			self:visible(true):linear(0.6):diffusealpha(1)
		else
			self:linear(0.6):diffusealpha(0):queuecommand("Hide")
		end
		GetCurrentScreen():GetChild("Footer"):diffusealpha(0)
	end,

    LoopCommand=function(self)
		index = index + 1
		self:queuecommand("NewColor"):sleep(delay):queuecommand("Loop")
	end,

	ScreenChangedMessageCommand=function(self)
		for _,v in pairs(knownScreens) do
			if string.match(GetCurrentScreen(true),v) then
				-- update known screen, reset uptime
				currentKnownScreen = v
				if currentKnownScreen ~= v then
					knownScreenUptime = 0
				end
			end
		end
	end,

	SetCommand=function(self,params)
		-- params are passed into MusicWheelItem's SetCommand, but i am unsure how to get
		-- those directed onto this actor. because of that, this code really cant ever run.
		--[[
			if params then
				if GetCurrentScreen():GetChild("MusicWheel") then
					local parts = {
						"CourseNormalPart",
						"SongNormalPart",
						"SectionCollapsedNormalPart",
						"SectionExpandedNormalPart"
					} 
					local musicWheelItem = GetCurrentScreen():GetChild("MusicWheel"):GetChild("MusicWheelItem")
					local song = params.Song
					local offset = round(SONGMAN:GetGroup(song):GetSyncOffset(), 3)
					for i = 1,#musicWheelItem do
						for p = 1,#parts do
							local itemPart = musicWheelItem[i]:GetChild(parts[p]):GetChild("")[2]
							if offset == -0.009 then
								itemPart:diffuserightedge(DarkUI() and {1, 1, 1, 0.5} or {10 / 255, 20 / 255, 27 / 255, 1})
							else
								itemPart:diffuserightedge(DarkUI() and {1, 0.5, 0.5, 0.5} or {30 / 255, 20 / 255, 27 / 255, 1})
							end
							itemPart:diffusealpha(0.5)
						end
					end
				end
			end
		]]
	end
}

local function randomXD(t)
	if t == 0 then return 0.5 else
	return (math.sin(t * 3229.3) * 43758.5453) % 1 end
end

-- background
t[#t+1] = Def.Quad {
	Name = "bgQuad",
	InitCommand=function(self)
		self
		:diffuse(2/255, 2/255, 2/255, 1)
		:diffusetopedge(41/255,41/255,41/255,1)
		:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		--[[
			if ThemePrefs.Get("RainbowMode") then
				self:diffusealpha(0)
			end
		]]
	end
}
--old type work i made for the pack3 release video im reusing for free vague shapes
t[#t+1] = Def.Sprite {
	Name = "type",
	Texture = "./pack2.png",
	OnCommand=function(self)
		self:
		zoom(2.5):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:customtexturerect(0,0,1,1):texcoordvelocity(0.0015, 0.00)
		:diffuse(22/255,22/255,22/255,0.4)
		
	end
}

--floor and ceiling look
t[#t+1] = Def.ActorFrame{
	Name="gridFrame",
	OnCommand=function(self)
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self:diffusealpha(0.6)
		else
			self:diffusealpha(0.3)
		end
	end,
	Def.Sprite {
		Name = "gridSpriteBottom",
		Texture = "./square.png",
		OnCommand=function(self)
			self:zoom(20):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 250)
			:customtexturerect(0,0,60,60):texcoordvelocity(0.05, 0.07)
			:diffusetopedge(0,0,0,0)
			:rotationx(-80)
			:rotationy(20)
			:rotationz(5)
			--[[
			if ThemePrefs.Get("RainbowMode") then
				self:diffusealpha(0.15)
			end
			]]
		end
	},
	Def.Sprite {
		Name = "gridSpriteTop",
		Texture = "./square.png",
		OnCommand=function(self)
			self:zoom(20):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 250)
			:customtexturerect(0,0,60,60):texcoordvelocity(0.05, 0.07)
			:diffusetopedge(0,0,0,0)
			:rotationx(-80)
			:rotationy(20)
			:rotationz(5)
			--[[
				if ThemePrefs.Get("RainbowMode") then
					self:diffusealpha(0.15)
				end
			]]
		end,
	}
}

--generating sine waves
if DatumOptions.SINE_ENABLED == true then
	for s = 1,3 do
		t[#t+1] = Def.ActorFrame {
			Name = "sPolygonFrame"..s,
			OnCommand=function(self)
				if GetCurrentScreen(true) == "ScreenSelectMusic" then 
					self
					:rotationz(4)
					:rotationx(-10)
					:x(SCREEN_CENTER_X - 200)
					:y(SCREEN_CENTER_Y)
				else
					self
					:rotationx(0)
					:rotationz(-40)
					:x(SCREEN_CENTER_X)
					:y(SCREEN_CENTER_Y)
				end
			end,
			Def.ActorMultiVertex {
				Name="sPolygon",
				OnCommand=function(self)
					local numVert = 80
					local lenMult = 25
					local radius = 80 + s*20-- sine twist radius, vary by s
					-- offset in radius to give the quadstrip some width
					local lineWidth
					if GetCurrentScreen(true) == "ScreenSelectMusic" then 
						lineWidth = DatumOptions.SINE_WIDTH * 4.25
					else
						lineWidth = DatumOptions.SINE_WIDTH
					end
					self
					:zoom(.5)
					:SetDrawState({Mode="DrawMode_QuadStrip"})
					:SetNumVertices(numVert)
					local isOdd
					for i = 0,numVert-1 do
						if i%2==0 then isOdd = 0 else isOdd = 1 end
						self
						:SetVertex(i+1, {
							{
								math.sin(i/(7 + s*5) + s*30)*(radius+lineWidth*isOdd),
								i*-lenMult + (0.5*numVert*lenMult),
								math.cos(i/(7 + s*5) + s*30)*(radius+lineWidth*isOdd)
							},{1,1,1,DatumOptions.SINE_OPACITY/100}
						})
					end
				end
			}
		}
	end
end

--big swooshy ring within an actorframe to lower specifically this actor's fov
--also masked out cause i want a gradient and its a model
t[#t+1] = Def.ActorFrame{
	Name="datumRing",
	OnCommand=function(self)
		self
		:fov(55)
		:rotationx(-70)
		:rotationy( 40)
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self
			:zoom(1.25)
			:x(120 + SCREEN_CENTER_X)
			:y(-50 + SCREEN_CENTER_Y)
		else
			self
			:zoom(1)
			:x(0 + SCREEN_CENTER_X)
			:y(20 + SCREEN_CENTER_Y)
		end
	end,
	Def.Model {
	Meshes="./ring_datum.txt",
	Materials="./ring_datum.txt",
	Bones="./ring_datum.txt",
	InitCommand=function(self)
		self
		:cullmode('none')
		:clearzbuffer(true)
		:zwrite(true)
		:blend('BlendMode_NoEffect')
		:zoom(7.2)
	end,
	},
}
t[#t+1] = Def.Sprite {
	Name = "datumMask2",
	Texture = "./white_tex.png",
	OnCommand=function(self)
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self
			:diffuse(45/255,45/255,45/255,0.2)
			:diffusetopedge(125/255,125/255,125/255,0.9)
		else
			self
			:diffuse(25/255,25/255,25/255,1)
			:diffusetopedge(45/255,45/255,45/255,0.9)
		end
		self
		:zoomto(SCREEN_WIDTH,SCREEN_HEIGHT):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:ztest(true)
		:ztestmode('ZTestMode_WriteOnFail')
	end,
}

--clearzbuffer quad so objects in front of this dont overlap weirdly
t[#t+1] = Def.Quad {
	InitCommand=function(self)
		self
		:zoomto(SCREEN_WIDTH,SCREEN_HEIGHT):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:clearzbuffer(true)
		:blend('BlendMode_NoEffect')
	end
}
--[[
	t[#t+1] = Def.ActorFrame{
		Name="datumRing2",
		InitCommand=function(self) self:fov(55) end,
		OnCommand=function(self)
		self
		:x(0 + SCREEN_CENTER_X)
		:y(20 + SCREEN_CENTER_Y)
		:z(0)
	end,
	Def.ActorMultiVertex {
		Name="datumRingDashed",
		OnCommand=function(self)
		local numVert = 160
		local radius = 350
		local lineWidth = 50 -- offset in radius to give the quadstrip some width
		self
		:zoom(1)
		:xy(0,-20)
		--:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:SetDrawState({Mode="DrawMode_Quads"})
		:SetNumVertices(numVert)
		local vertex --decides which radius (radius or radius+linewidth) to apply
		local isOdd
			local dash
			local pi = math.pi
			for i = 0,numVert-1 do
				if i%2==0 then isOdd = 1 else isOdd = 0 end
				if i%4==0 then vertex = 0
				elseif i%4==1 then vertex = 1
				elseif i%4==2 then vertex = 1
				elseif i%4==3 then vertex = 0
				end
				if i%8>=4 then dash = 1 else dash = 0 end
				self
				:SetVertex(i+1, {
					{
						math.sin((i-vertex)*((pi*2)/(numVert-2)))*(radius),
						math.cos((i-vertex)*((pi*2)/(numVert-2)))*(radius),
						lineWidth*vertex
					},{1,1,1,1}
				})
			end
		end
	}
}
]]

if DatumOptions.DO_SCREEN_TRANSITIONS then
	local brightness = 20
	local offset = 100
	local skew = -0.35
	-- we have the option for top or bottom surgery!
	t[#t+1] = Def.Quad {
		Name = "transitionQuadTop",
		InitCommand=function(self)
			self
			:diffuse(brightness/255, brightness/255, brightness/255, 1)
			:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT + offset)
			:skewy(skew)
			:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - (offset/2))
			:visible(0)
		end,
	}
	t[#t+1] = Def.Quad {
		Name = "transitionQuadBottom",
		InitCommand=function(self)
			self
			:diffuse(brightness/255, brightness/255, brightness/255, 1)
			:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT + offset)
			:skewy(skew)
			:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + (offset/2))
			:visible(0)
		end,
	}
end

--pack.dat logo modelled and masked onto a gradient
t[#t+1] = Def.Model {
	Name="datumModel",
	Meshes="./datum.txt",
	Materials="./datum.txt",
	Bones="./datum.txt",
	InitCommand=function(self)
		self
		:SetTextureFiltering(true)
		:diffusealpha(0.7)
		:cullmode('none')
		:skewy(-0.39)
		:clearzbuffer(true)
		:zwrite(true)
		:blend('BlendMode_NoEffect')
		--[[
			if ThemePrefs.Get("RainbowMode") then
				self:diffuse(GetHexColor(randomindex, true))
				self:diffusealpha(0.4)
			end
		]]
	end,
	OnCommand=function(self)
		self
		:zoomx(2.7):zoomy(3.125):zoomz(2.5)
		:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		if not DatumOptions.UPDATE_LOOP_ENABLED then
			self:decelerate(1.5)
			self:diffusealpha(DatumOptions.DATUM_OPACITY)
		end
	end,
	ScreenChangedMessageCommand=function(self)
		-- change size and position for a cleaner look
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self
			:zoomx(6.75):zoomy(7.8125):zoomz(6.25)
			:x(SCREEN_CENTER_X + 200)
			:y(SCREEN_CENTER_Y - 50)
		end
	end
}
t[#t+1] = Def.Sprite {
	Name = "datumMask",
	Texture = "./white_tex.png",
	OnCommand=function(self)
		self:visible(DatumOptions.DATUM_MODEL_ENABLED)
		self:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
		-- we dont want this to be transparent on ScreenSelectMusic
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self:diffusealpha(1)
		else
			self:diffusealpha(DatumOptions.DATUM_OPACITY/100)
		end
		if DatumOptions.DATUM_HUE_SHIFT_ENABLED then
			self:diffusetopedge(shiftActiveColorHue())
		else
			self:diffusetopedge(GetHexColor(SL.Global.ActiveColorIndex, true))
		end
		self
		:zoomto(SCREEN_WIDTH,SCREEN_HEIGHT):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:ztest(true)
		:ztestmode('ZTestMode_WriteOnFail')

		if not DatumOptions.UPDATE_LOOP_ENABLED then
			self:decelerate(1.5)
			self:diffusealpha(DatumOptions.DATUM_OPACITY)
		end
	end,
	ColorSelectedMessageCommand=function(self)
		if DatumOptions.DATUM_HUE_SHIFT_ENABLED == true then
			self:linear(0.1)
			self:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
			self:diffusetopedge(shiftActiveColorHue())
		else
			self:linear(0.1)
			self:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
			self:diffusetopedge(GetHexColor(SL.Global.ActiveColorIndex, true))
		end
		self:diffusealpha(0.8)
	end,
}

-- cover for when we need a little bit more clarity
t[#t+1] = Def.Quad {
	Name = "coverQuad",
	InitCommand=function(self)
		self
		:diffuse(5/255, 5/255, 5/255, 1)
		:diffusebottomedge(41/255,41/255,41/255,1)
		:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:visible(0)
		:diffusealpha(0)
	end,
	ScreenChangedMessageCommand=function(self)
		-- since there is a bunch of text on screen, enable the cover in
		-- ScreenSelectMusic because we need to minimize visual noise
		if GetCurrentScreen(true) == "ScreenSelectMusic" then
			self
			:visible(1)
			--:decelerate(1)
			:diffusealpha(0.7)
		end
	end
}

-- i dont like the way that many of the changes the "Technique" visual style makes are spread throughout the theme.
-- this is a very jank way of changing as many of those things as possible *within* this file to minimize installation steps.
t[#t+1] = Def.Actor {
	ScreenChangedMessageCommand=function(self) -- any time there's a screen switch, this code will run
		if ThemePrefs.Get("VisualStyle") == "Datum" then
			if GetCurrentScreen():GetChild("Footer") then
				GetCurrentScreen():GetChild("Footer"):diffusealpha(0)
			end
			if GetCurrentScreen():GetChild("Header") then
				GetCurrentScreen():GetChild("Header"):GetChild(""):diffusealpha(0)
			end
			if GetCurrentScreen(true)=="ScreenTitleMenu" then
				--goodbye logo
				GetCurrentScreen():GetChild("Underlay"):GetChild("SLInfo"):GetChild("")[1]:GetChild("Simply Text"):visible(0)
				GetCurrentScreen():GetChild("Underlay"):GetChild("SLInfo"):GetChild("")[1]:GetChild(""):visible(0)
			-- im unsure if there's any other screens with the "ScreenEvaluation..." pattern,
			-- so let's just generalize it in case there is. the main one is "ScreenEvaluationStage"
			elseif GetCurrentScreen(true) == "ScreenEvaluation*" then
				local panes = GetCurrentScreen():GetChild("Overlay"):GetChild("ScreenEval Common"):GetChild("Panes")
				if panes then
					for i = 1,2 do --for each player
						-- panes 1, 2, and 5 all have conditionals for Technique:

						-- pane 1,2
						for p = 1,2 do -- pane 1, 2 have the same change done to them
							local paneSide = panes:GetChild("Pane"..p.."_SideP"..i)
							if paneSide then
								local target = paneSide:GetChild(""):GetChild("PercentageContainerP"..i)
								if target then
									target:GetChild(""):diffusealpha(0.5)
								end
							end 
						end
						-- pane 5 is a special case:
						local paneSide = panes:GetChild("Pane5_SideP"..i)
						if paneSide then
							-- "early" text is a little transparent in Technique, but it's more
							-- clean if we just make it a mid grey and prevent background from
							-- slightly poking through it
							paneSide:GetChild(""):GetChild("")[2]:diffuse(0.6,0.6,0.62,1)
							paneSide:GetChild(""):GetChild("")[4]:diffusealpha(0.5)
							-- this one is a bit of a nightmare because there's an unknown amount of 
							-- BitMapText that can be above it based on the # of judgements available.
							-- filter out actors by Diffuse (i dont know a way to check if it is a Quad)
							local paneActors = paneSide:GetChild(""):GetChild("")
							for k,_ in ipairs(paneActors) do
								local redChannel = 62745 -- approx. 65/255 * 10^6
								local targetRedChannel = paneSide:GetChild(""):GetChild("")[k]:GetDiffuse()[1]
								-- check red channel to the nearest 6 digits to ensure we have captured the right quads
								if math.floor(targetRedChannel*10^6) == redChannel then
									paneSide:GetChild(""):GetChild("")[k]:diffusealpha(0.5)
								end
							end
						end
					end
				end
				local eval = GetCurrentScreen():GetChild("Overlay"):GetChild("ScreenEval Common")
				if eval then
					for i = 1,2 do -- for each player
						local af_lower = eval:GetChild("P"..i.."_AF_Lower")
						if af_lower then
							-- main bg quad of the eval screen
							af_lower:GetChild("LowerQuad"):diffusealpha(0.75)
							-- quad below the modifiers
							af_lower:GetChild(""):GetChild("")[1]:diffusealpha(0.75)
							-- quad below scatterplot
							af_lower:GetChild("JudgeGraph"):GetChild("")[1]:diffusealpha(0.95)
							if GAMESTATE:IsCourseMode() then
								af_lower:GetChild("JudgeGraph"):GetChild("")[2]:diffusealpha(0.6)
							end
						end
					end
					--quad behind song artist, bpm, etc.
					eval:GetChild("")[3]:GetChild("")[1]:diffusealpha(0.5)
					-- GetChild("")[2]:GetChild("")[1] will return a different actor if there is an available banner
					-- because the banner actor has Name = "Banner" and the fallback does not have a name.
					-- the check is simple though, so let's just do that:
					local SongOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
					if SongOrCourse and SongOrCourse:HasBanner() then
						eval:GetChild("")[2]:GetChild("")[1]:diffusealpha(0.5)
					else
						eval:GetChild("")[2]:GetChild("")[2]:diffusealpha(0.5)
					end
				end
			elseif GetCurrentScreen(true) == "ScreenSelectMusic" then
				local overlay = GetCurrentScreen():GetChild("Overlay")
				local per_player = overlay:GetChild("PerPlayer")
				for i = 1,#per_player:GetChild("") do
					-- FolderStats.lua and DensityGraph.lua both return actorframes without names.
					-- DensityGraph.lua has a "ChartParser" element, so lets differentiate it that way.
					if per_player:GetChild("")[i]:GetChild("ChartParser") then
						per_player:GetChild("")[i]:GetChild(""):diffusealpha(0.5)
						per_player:GetChild("")[1]:GetChild("ChartParser"):GetChild("PatternInfo"):GetChild(""):diffusealpha(0.5)
					end
				end
				for i=1,#overlay:GetChild("") do
					if overlay:GetChild("")[i]:GetNumChildren()==2 then
						overlay:GetChild("")[i]:GetChild("")[1]:diffusealpha(0.5)
					end
				end
				GetCurrentScreen():GetChild("Footer"):diffusealpha(0.5):diffuse(0, 0, 0, 0.5)
				GetCurrentScreen():GetChild("Header"):GetChild(""):diffuse(0, 0, 0, 0.5)
			end

			if GetCurrentScreen():GetChild("MusicWheel") then
				local parts = {
					"CourseNormalPart",
					"SongNormalPart",
					"SectionCollapsedNormalPart",
					"SectionExpandedNormalPart"
				} 
				local musicWheelItem = GetCurrentScreen():GetChild("MusicWheel"):GetChild("MusicWheelItem")
				for i = 1,#musicWheelItem do
					for p = 1,#parts do
						local itemPart = musicWheelItem[i]:GetChild(parts[p]):GetChild("")[2]
						itemPart:diffusealpha(0.5)
					end
				end
			end

			if DatumOptions.DO_SCREEN_TRANSITIONS then
				-- hides the white transition quad in ScreenSelectMusic so we can use our own
				local sharedBG = tActors["datumMask"]:GetParent():GetParent():GetParent()
				if GetCurrentScreen(true) == "ScreenSelectMusic" or GetCurrentScreen(true) == "ScreenSelectCourse" then
					if sharedBG:GetChild("") then
						sharedBG:GetChild("")[3]:visible(0)
					end
				end
			end
			
		end
	end
}

return t