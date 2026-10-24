-- @NAME:Datum Visual Style
-- @VERSION:1.0.0
-- @ID:dat.100

-- adapted from Technique.lua
-- created by mang;
	-- i am well aware that my coding may not be very optimized. please let me know if you run into any issues
	-- running this Visual Style (whether that be framerate issues, visual glitches and other edge cases.)
	-- if you do take the time to look through my code and have any optimizations that you can share with me,
	-- i would really appreciate that. i do not have much knowledge of the SL codebase, so if anything here can
	-- be done in a simpler manner (ESPECIALLY in some of the GetChild shenanigans done to recreate Technique,
	-- that would be wonderful. i just coded this kind of like a NotITG modfile lol

-- the screens for which a layout has been made. 
-- if a screen not on this list is pushed to the top, 
-- we will check for  these "known" screens to act as a failsafe
-- so there isn't any snapping or unintended behaviors.
local knownScreens = {
	"ScreenTitleMenu",
	"ScreenSelectMusic",
	"ScreenEvaluationStage",
	"ScreenEvaluationCourse",
	"ScreenPlayerOptions",

	--planned screens
	--[[
		"ScreenEvaluationSummary"
		"ScreenGameOver",
	]]
}
local knownScreenSet = {}
for _, v in ipairs(knownScreens) do knownScreenSet[v] = true end

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
--                OPTIONS PARSING
--//////////////////////////////////////////////////

-- options are stored in "DatumOptions.lua" which
-- should be in the same directory as this .lua file
local path = THEME:GetPathB("","_shared background/Datum/DatumOptions.lua")
local DatumOptions, _ = dofile(path)
-- if for some reason, no DatumOptions.lua exists, these are the default options.
-- (you should not edit this as it may have unintended behaviors!)
if not DatumOptions then
	DatumOptions = {}
	DatumOptions.DATUM_MODEL_ENABLED = true
	DatumOptions.DATUM_OPACITY = 85
	DatumOptions.DATUM_HUE_SHIFT_ENABLED = true
	DatumOptions.DATUM_HUE_SHIFT_AMOUNT = 32
	DatumOptions.SINE_ENABLED = true
	DatumOptions.SINE_WIDTH = 1.5
	DatumOptions.SINE_OPACITY = 100
	DatumOptions.GAY_MODE_ENABLED = false
	DatumOptions.GAY_MODE_SPEED = 40
	DatumOptions.AUTO_PRIDE_ENABLED = true
	DatumOptions.UPDATE_LOOP_ENABLED = true
    DatumOptions.DO_SCREEN_TRANSITIONS = true
    DatumOptions.ENABLE_BAR_TRANSITION = true
    DatumOptions.MUSICWHEEL_TRANSITION = "Full"
    DatumOptions.TRANSITION_SPEED = 1.0
end

--//////////////////////////////////////////////////
--               CACHED REFERENCES
--//////////////////////////////////////////////////

-- Preallocated HSV table to avoid per-frame allocation
local tmpHSV = { Hue = 0, Sat = 1, Value = 1, Alpha = 1 }
-- Base color cache (refreshed on ColorSelectedMessageCommand / InitCommand)
local baseHSV = { Hue = 0, Sat = 1, Value = 1, Alpha = 1 }

local function refreshBaseColor()
    local hex = GetHexColor(SL.Global.ActiveColorIndex, true)
    baseHSV = ColorToHSV(hex)
end

-- Actor references, populated in InitCommand via cacheActorRefs()
local model, ring , coverQuad
local transTop, transBottom
-- sPolygon actors
local sines = {}
-- sPolygonFrame actors
local sineFrames = {}

-- Screen reference cache, repopulated on every ScreenChangedMessageCommand
local screenRefs = {}

local function resolveScreenRefs()
    local scr = GetCurrentScreen()
    if not scr then
        screenRefs = {}
        return
    end

    local wheel = scr:GetChild("MusicWheel")
    local wheelItems = wheel and wheel:GetChild("MusicWheelItem") or nil

    -- Precompute refs for wheel transition.
    local wheelParts = nil
    if wheelItems and #wheelItems > 0 then
        local WHEEL_PARTS = {
            "SectionExpanded", "SectionCollapsed",
            "SongName", "SongName"
        }
        wheelParts = {}
        for i = 1, #wheelItems do
            local item = wheelItems[i]
            local entry = { item = item, parts = {} }
            for p = 1, #WHEEL_PARTS do
                local name = WHEEL_PARTS[p]
                local part = item:GetChild(name)
                if part then entry.parts[#entry.parts + 1] = { name = name, actor = part } end
            end
            wheelParts[i] = entry
        end
    end

    screenRefs = {
        screen     = scr,
        name       = scr:GetName(),
        header     = scr:GetChild("Header"),
        footer     = scr:GetChild("Footer"),
        overlay    = scr:GetChild("Overlay"),
        underlay   = scr:GetChild("Underlay"),
        wheel      = wheel,
        wheelItems = wheelItems,
        wheelParts = wheelParts,
    }
end

local function cacheActorRefs(self)
    local c = self:GetChildren()
    model       = c["datumModel"]
    ring        = c["datumRing"]
    coverQuad   = c["coverQuad"]
    transTop    = c["transitionQuadTop"]
    transBottom = c["transitionQuadBottom"]

    for i = 1, 3 do
        local frame = c["sPolygonFrame" .. i]
        sineFrames[i] = frame
        sines[i] = frame and frame:GetChild("sPolygon") or nil
    end
end

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

function clamp(val, lower, upper)
    return math.max(lower, math.min(upper, val))
end
local function customActiveColorShift(h,s,v,a)
	local hsv = {
        Hue = (baseHSV.Hue + h) % 360,
        Sat = clamp(baseHSV.Sat + s, 0, 1),
        Value = clamp(baseHSV.Value + v, 0, 1),
        Alpha = clamp(baseHSV.Alpha + a, 0, 1)
    }
	return HSVToColor(hsv)
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

-- transition variables
local transitionEase
local addEase = {
	{length=6 ,v=0},
	{length=12,v=0}
}
local easesDone = false

local opaqueScreens = {
	"ScreenSelectMusic",
	"ScreenEvaluationStage",
	"ScreenEvaluationCourse",
}

local knownScreenUptime = 0

--//////////////////////////////////////////////////
--                 UPDATE LOOP
--//////////////////////////////////////////////////

local function updater(self, delta)
    local time = GetTimeSinceStart()
    knownScreenUptime = knownScreenUptime + delta * DatumOptions.TRANSITION_SPEED

    -- cache the screen name & opaque datum check
    local scrName = screenRefs.name or ""
    local isOpaque = false
    for i = 1, #opaqueScreens do
        if scrName:find(opaqueScreens[i], 1, true) then
            isOpaque = true
            break
        end
    end

    local screen = currentKnownScreen

    -- intro eases
    local e1, e2
    if not easesDone then
        local stillActive = false
        for i = 1, #addEase do
            local e = addEase[i]
            if time - 1 > e.length then
                e.v = 0
            else
                e.v = easeOutExpo(time - 1, 1, -1, e.length)
                stillActive = true
            end
        end
        if not stillActive then easesDone = true end
    end
    e1 = addEase[1].v
    e2 = addEase[2].v

    if screen == "ScreenSelectMusic" then
        model:rotationx(math.sin(knownScreenUptime * 2 / -29) * 3)
        model:rotationy(math.sin(knownScreenUptime * 2 /  23) * 5)
        model:rotationz(math.sin(knownScreenUptime * 2 /  31) * 3)
        ring:rotationx(-60 + math.sin(knownScreenUptime * 1 / -29) * 2)
        ring:rotationy(math.cos(knownScreenUptime * 1 / -31) * 2)

    elseif screen == "ScreenPlayerOptions" then
        model:rotationx(math.sin(knownScreenUptime * 2 / -29) * 3)
        model:rotationy(math.sin(knownScreenUptime * 2 /  23) * 5)
        model:rotationz(math.sin(knownScreenUptime * 2 /  31) * 3)
        ring:rotationx(40 + math.sin(knownScreenUptime * 1 / -29) * 2)
        ring:rotationy(math.cos(knownScreenUptime * 1 / -31) * 2)

    else
        model:rotationx(math.sin(knownScreenUptime * 5 / -29) * 5)
        model:rotationy(math.sin(knownScreenUptime * 5 /  23) * 10 + e1 * -30)
        model:rotationz(math.sin(knownScreenUptime * 5 /  31) * 2)
        model:y(SCREEN_CENTER_Y + e2 * 30)

        ring:rotationx(-70 + math.sin(knownScreenUptime * 1 / -29) * 2 + e2 * 10)
        ring:rotationy( 40 + math.cos(knownScreenUptime * 1 / -31) * 2)
    end

    -- hue cycling

    if doGayMode then
        local h = (baseHSV.Hue + time * DatumOptions.GAY_MODE_SPEED) % 360
        tmpHSV.Hue   = h
        tmpHSV.Sat   = 1.0
        tmpHSV.Value = baseHSV.Value
        tmpHSV.Alpha = baseHSV.Alpha
        local c = HSVToColor(tmpHSV)

        if DatumOptions.DATUM_HUE_SHIFT_ENABLED then
            model:diffuse(c)
            tmpHSV.Hue = (h - DatumOptions.DATUM_HUE_SHIFT_AMOUNT) % 360
            model:diffusetopedge(HSVToColor(tmpHSV))
        else
            model:diffuse(c)
            model:diffusetopedge(c)
        end
    end

    --model:diffusealpha(0.7)
    model:diffusealpha(DatumOptions.DATUM_OPACITY / 100 + e1 * -3.8)

    if screen == "ScreenPlayerOptions" or isOpaque then
        model:diffusealpha(1)
    end

    -- sine polygons
    local sineAlpha = DatumOptions.SINE_OPACITY / 100 - e1 * 1.8
    local sineRot   = time * 10 + e1 * -80
    for i = 1, 3 do
        local s = sines[i]
        if s then
            s:diffusealpha(sineAlpha):rotationy(sineRot)
        end
    end

    -- //////////////////////////////////
    --        SCREEN TRANSITIONS
    -- //////////////////////////////////
    if not DatumOptions.DO_SCREEN_TRANSITIONS then return end

    local transitionTime = 2
    if knownScreenUptime > transitionTime then
        transitionEase = 0
    else
        transitionEase = easeOutExpo(knownScreenUptime, 1, -1, transitionTime)
    end

    -- bars
    if knownScreenUptime < transitionTime and DatumOptions.ENABLE_BAR_TRANSITION and time > 12 then
        local te = transitionEase
        local te6 = te * te * te * te * te * te
        local te15 = (te * 0.8) ^ 1.5
        local brightness = 20 - (te6 * 20)
        local crop = 1 - te15
        local b = brightness / 255

        transTop:cropbottom(crop):diffuse(b, b, b, 1):visible(1)
        transBottom:croptop(crop):diffuse(b, b, b, 1):visible(1)
    else
        transTop:playcommand("Init")
        transBottom:playcommand("Init")
    end

    -- ---- per-screen model transition tweens ----
    if knownScreenUptime < transitionTime then
        local te = transitionEase
        local te2 = te * te

        if screen == "ScreenSelectMusic" then
            local coverDiffuse       = 5  - (5  * te)
            local coverDiffuseBottom = 41 - (41 * te)
            model:y(SCREEN_CENTER_Y - 20 + te * 25)

            coverQuad
                :diffuse(coverDiffuse / 255, coverDiffuse / 255, coverDiffuse / 255, 1)
                :diffusebottomedge(coverDiffuseBottom / 255, coverDiffuseBottom / 255, coverDiffuseBottom / 255, 1)
                :diffusealpha(0.7 + te * 0.2)

            model:diffusealpha(1 + te2)

        elseif screen == "ScreenEvaluationStage" or screen == "ScreenEvaluationCourse" then
            model:y(SCREEN_CENTER_Y + te * 25)

        elseif screen == "ScreenPlayerOptions" then
            model:x(SCREEN_CENTER_X + 250 + te * -20)
            model:diffuse(75 / 255, 75 / 255, 75 / 255, 1 - te2)

        else
            model:y(SCREEN_CENTER_Y + e2 * 30 + te * 25)
            model:diffusealpha(DatumOptions.DATUM_OPACITY / 100 - te2 + e1 * -3.8)
        end

        if time > 12 then
            local sineAlphaT = DatumOptions.SINE_OPACITY / 100 - te - e1 * 1.8
            local sineRotT   = time * 10 + e1 * -80 - te * 60
            for i = 1, 3 do
                local s = sines[i]
                if s then s:diffusealpha(sineAlphaT):rotationy(sineRotT) end
            end
        end
    end

    -- music wheel transition
    if DatumOptions.MUSICWHEEL_TRANSITION ~= "SimplyLove"
       and screenRefs.wheel
       and screenRefs.wheelParts
       and knownScreenUptime < transitionTime
    then
        local isFull       = DatumOptions.MUSICWHEEL_TRANSITION == "Full"
        local isTextOnly   = DatumOptions.MUSICWHEEL_TRANSITION == "TextOnly"
        local isOpacityOnly= DatumOptions.MUSICWHEEL_TRANSITION == "OpacityOnly"

        local wheelParts = screenRefs.wheelParts

        for i = 1, #wheelParts do
            local entry = wheelParts[i]
            local item  = entry.item

            local perItemEase
            do
                local tti = 1
                local up  = knownScreenUptime - (i * 0.02)
                if up > tti then perItemEase = 0
                else perItemEase = easeOutExpo(up, 1, -1, tti) end
            end

            item:diffusealpha(1 - perItemEase * 2)

            local pe2 = perItemEase * perItemEase
            local pe4 = pe2 * pe2
            local pe6 = pe4 * pe2
            local pe8 = pe4 * pe4

            for p = 1, #entry.parts do
                local pd = entry.parts[p]
                local part = pd.actor
                local pname = pd.name

                part:cropright(pe4)

                if pname == "SongName" then
                    local title    = part:GetChild("Title")
                    local subtitle = part:GetChild("Subtitle")

                    if isTextOnly then
                        title:cropright(pe2)
                        subtitle:cropright(pe2)
                    elseif isOpacityOnly then
                        title:diffusealpha(1 - pe6)
                        subtitle:diffusealpha(1 - pe6)
                    elseif isFull then
                        title:cropright(pe2):diffusealpha(1 - pe6)
                        subtitle:cropright(pe2):diffusealpha(1 - pe6)
                    end
                else
                    if isOpacityOnly or isFull then
                        part:diffusealpha(1 - pe8)
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
		cacheActorRefs(self)
		refreshBaseColor()
		resolveScreenRefs()
	
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

	ScreenChangedMessageCommand=function(self)
		resolveScreenRefs()
		refreshBaseColor()
	
		local name = screenRefs.name
		if name and knownScreenSet[name] then
			if currentKnownScreen ~= name then
				currentKnownScreen = name
				knownScreenUptime = 0
			end
		end
	end,
	
	--[[
	SetCommand=function(self,params)
		-- params are passed into MusicWheelItem's SetCommand, but i am unsure how to get
		-- those directed onto this actor. because of that, this code really cant ever run.
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
		end
	]]
}

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
				local curScreen=GetCurrentScreen(true)
				if curScreen == "ScreenSelectMusic" then
					self
					:rotationz(4)
					:rotationx(-10)
					:x(SCREEN_CENTER_X - 200)
					:y(SCREEN_CENTER_Y)
				elseif curScreen == "ScreenPlayerOptions" then
					self
					:rotationz(-30)
					:rotationx(-20)
					:x(SCREEN_CENTER_X - 250)
					:y(SCREEN_CENTER_Y)
				else
					self
					:rotationx(0)
					:rotationz(-40)
					:x(SCREEN_CENTER_X)
					:y(SCREEN_CENTER_Y)
				end
				if not DatumOptions.UPDATE_LOOP_ENABLED then
					self
					:rotationy(-20)
					:bezier(1,{0,1.0,1.0,1.0})
					:rotationy(0)
				end
			end,
			Def.ActorMultiVertex {
				Name="sPolygon",
				OnCommand=function(self)
					local curScreen=GetCurrentScreen(true)
					local numVert = 80
					local lenMult = 25
					local radius = 80 + s*20-- sine twist radius, vary by s
					-- offset in radius to give the quadstrip some width
					local lineWidth
					if curScreen == "ScreenSelectMusic" or curScreen == "ScreenPlayerOptions" then
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

					if not DatumOptions.UPDATE_LOOP_ENABLED then
						self
						:spin()
						:effectmagnitude(0, 10, 0)
						:effectoffset(s*400)
						--:bezier(4,{0,1.0,1.0,1.0})
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
			:z(0)
		elseif GetCurrentScreen(true) == "ScreenPlayerOptions" then
			self
			:zoom(1.9)
			:x(SCREEN_CENTER_X + 240)
			:y(SCREEN_CENTER_Y + -20)
			:z(-400)
		else
			self
			:zoom(1)
			:x(0 + SCREEN_CENTER_X)
			:y(20 + SCREEN_CENTER_Y)
			:z(0)
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
		if GetCurrentScreen(true) == "ScreenSelectMusic" or GetCurrentScreen(true) == "ScreenPlayerOptions" then
			self
			:diffuse(35/255,35/255,35/255,0.2)
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

t[#t+1] = Def.Sprite {
	Name="datumModel",
	Texture = "./datum.png",
	InitCommand=function(self)
		self:finishtweening()

		self
		:diffusealpha(0)
		:skewy(-0.05)
	end,
	OnCommand=function(self)
		self
		:visible(DatumOptions.DATUM_MODEL_ENABLED)
		:linear(0)
		:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
		:diffusetopedge(shiftActiveColorHue())
		:diffusealpha(DatumOptions.DATUM_OPACITY/100)
		:zoomto(300,280)
		--:zoomx(2.7):zoomy(3.125):zoomz(2.5)
		:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		if not DatumOptions.UPDATE_LOOP_ENABLED then
			self
			:bezier(1,{0,1.0,1.0,1.0})
			:diffusealpha(DatumOptions.DATUM_OPACITY/100)
			if DatumOptions.GAY_MODE_ENABLED then
				self
				:rainbow()
				:effectperiod(360/DatumOptions.GAY_MODE_SPEED)
			end
		end
	end,
	ScreenChangedMessageCommand=function(self)
		local name = GetCurrentScreen(true)
		if name == "ScreenSelectMusic" then
			self:finishtweening()
			self:zoomto(750,700)
			self:x(SCREEN_CENTER_X + 200):y(SCREEN_CENTER_Y - 30)
			if not DatumOptions.UPDATE_LOOP_ENABLED then
				self
				:x(SCREEN_CENTER_X + 210)
				:y(SCREEN_CENTER_Y - 30)
				self:bezier(1.5,{0,1.0,1.0,1.0})
				:x(SCREEN_CENTER_X + 200)
				:y(SCREEN_CENTER_Y - 30)
			else
				self
				:x(SCREEN_CENTER_X + 200)
				:y(SCREEN_CENTER_Y - 30)
			end
		elseif name == "ScreenPlayerOptions" then
			self
			:finishtweening()
			:zoomto(675,630)
			:x(SCREEN_CENTER_X + 300)
			:y(SCREEN_CENTER_Y - 30)
			:diffuse(75 / 255, 75 / 255, 75 / 255, 1)
			if not DatumOptions.UPDATE_LOOP_ENABLED then
				self
				:x(SCREEN_CENTER_X + 310)
				:y(SCREEN_CENTER_Y - 30)
				self:bezier(1.5,{0,1.0,1.0,1.0})
				:x(SCREEN_CENTER_X + 300)
				:y(SCREEN_CENTER_Y - 30)
			else
				self
				:x(SCREEN_CENTER_X + 300)
				:y(SCREEN_CENTER_Y - 30)
			end
		elseif name == "ScreenTitleMenu" then
			if not DatumOptions.UPDATE_LOOP_ENABLED then
				self
				:finishtweening()
				:zoomto(300,280)
				:diffusealpha(0)
				:y(SCREEN_CENTER_Y + 10)
				self:bezier(1,{0,1.0,1.0,1.0})
				:diffusealpha(DatumOptions.DATUM_OPACITY/100)
				:x(SCREEN_CENTER_X)
				:y(SCREEN_CENTER_Y)
			end
		end
	end,
	ColorSelectedMessageCommand=function(self)
		if DatumOptions.DATUM_HUE_SHIFT_ENABLED then
			self:linear(0.1)
			self:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
			self:diffusetopedge(shiftActiveColorHue())
		else
			self:linear(0.1)
			self:diffuse(GetHexColor(SL.Global.ActiveColorIndex, true))
			self:diffusetopedge(GetHexColor(SL.Global.ActiveColorIndex, true))
		end
		self:diffusealpha(DatumOptions.DATUM_OPACITY/100)
	end,
}

-- cover for when we need a little bit more clarity
t[#t+1] = Def.Quad {
	Name = "coverQuad",
	OnCommand=function(self)
		self
		:diffuse(5/255, 5/255, 5/255, 1)
		:diffusebottomedge(41/255,41/255,41/255,1)
		:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		:visible(0)
		:diffusealpha(0)
	end,
	ScreenChangedMessageCommand=function(self)
		local onScreens = {
			"ScreenSelectMusic",
			"ScreenEvaluationStage",
			"ScreenEvaluationCourse",
			"ScreenPlayerOptions",
		}
		-- if there is a bunch of info on screen, enable the cover in
		-- some screens because we need to minimize visual noise
		for i = 1,#onScreens do
			if string.find(GetCurrentScreen(true),onScreens[i]) then
				self:visible(1)
				self:diffusealpha(0.7)
			end
		end
	end
}

local screenRefs = {}

local function resolveScreenRefs()
	local scr = GetCurrentScreen()
	if not scr then return end
	local name = scr:GetName()

	screenRefs = {
		screen = scr,
		name = name,
		header = scr:GetChild("Header"),
		footer = scr:GetChild("Footer"),
		overlay = scr:GetChild("Overlay"),
		wheel = scr:GetChild("MusicWheel"),
        underlay = scr:GetChild("Underlay"),
	}

	if screenRefs.wheel then
        screenRefs.wheelItems = screenRefs.wheel:GetChild("MusicWheelItem")
    end
end

-- i dont like the way that many of the changes the "Technique" visual style makes are spread throughout the theme.
-- this is a very jank way of changing as many of those things as possible *within* this file to minimize the installation steps.
t[#t+1] = Def.Actor {
	ScreenChangedMessageCommand=function(self) -- any time there's a screen switch, this code will run
		if ThemePrefs.Get("VisualStyle") == "Datum" then
			self:sleep(0.01)

			-- find and change the header and footer
			do
				local header = GetCurrentScreen():GetChild("Header")
				local footer = GetCurrentScreen():GetChild("Footer")
				colorToDiffuse = {15/255,15/255,15/255,0.75}
				if footer then
					footer:diffuse(colorToDiffuse)
				end
				if header then
					--sometimes, the header quad we are looking for is buried within another "Header" actorframe.
					local headerAlt = header:GetChild("Header")
					if headerAlt then
						local headerAltQuad = headerAlt:GetChild("")
						if headerAltQuad then
							headerAltQuad:diffuse(colorToDiffuse)
						end
					end
					local headerQuad = header:GetChild("")
					if headerQuad then
						headerQuad:diffuse(colorToDiffuse)
					end
				end
			end

			if GetCurrentScreen(true)=="ScreenTitleMenu" then
				--remove the SL text logos ass they will be replaced with BG elements.
				local underlay = GetCurrentScreen():GetChild("Underlay")
				if underlay then
					local SLInfo = underlay:GetChild("SLInfo")
					if SLInfo then
						local SLInfoFrame = SLInfo:GetChild("")[1]
						if SLInfoFrame then
							local SimplyText = SLInfoFrame:GetChild("Simply Text")
							local arrowsLogo = SLInfoFrame:GetChild("")
							if SimplyText then
								SimplyText:visible(0)
							end
							if arrowsLogo then
								arrowsLogo:visible(0)
							end
						end
					end
				end
			elseif GetCurrentScreen(true) == "ScreenEvaluationStage" or GetCurrentScreen(true) == "ScreenEvaluationCourse" then
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
				local screen = GetCurrentScreen()				
				local overlay = screen and screen:GetChild("Overlay")
				local per_player = overlay and overlay:GetChild("PerPlayer")
				
				if per_player then
					for i = 1, #per_player:GetChild("") do
						local statsActor = per_player:GetChild("")[i]
						
						if statsActor then
							-- FolderStats.lua and DensityGraph.lua both return actorframes without names.
							-- DensityGraph.lua has a "ChartParser" element, so lets differentiate it that way.
							local densityBG = statsActor:GetChild("")
							if densityBG then
								densityBG:diffusealpha(0.3)
							end
							
							local chartParser = statsActor:GetChild("ChartParser")
							if chartParser then
								--[[ TODO: Customizable density graph?
									local densityGraph = chartParser:GetChild("DensityGraph")
									if densityGraph then
										--densityGraph:diffuse(0.5,0.5,0.5,1)
										--densityGraph:diffusetopedge(0.5,0.5,0.5,1)
										print(densityGraph:GetNumVertices() .. " DENSITYGRAPH Spotted")
									end
								]]
								local patternInfo = chartParser:GetChild("PatternInfo")
								if patternInfo then
									local patternActor = patternInfo:GetChild("")
									if patternActor then
										patternActor:diffusealpha(0.5)
									end
								end
							end
						end
					end
				end
					--[[
					local children = overlay:GetChild("")
					for i = 1,#children do
						local child = children[i]
						if child and child.GetNumChildren and child:GetNumChildren() == 2 then
							local innerChild = child:GetChild("")
							if innerChild and innerChild[1] then
								innerChild[1]:diffusealpha(0.5)
							end
						end
					end
					]]
				--GetCurrentScreen():GetChild("Footer"):diffusealpha(0.5):diffuse(0, 0, 0, 0.5)
				--GetCurrentScreen():GetChild("Header"):GetChild(""):diffuse(0, 0, 0, 0.5)
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
				local sharedBG = tActors["datumModel"]:GetParent():GetParent():GetParent()
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