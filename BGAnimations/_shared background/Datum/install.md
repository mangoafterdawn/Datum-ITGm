1. Copy the entire "Datum" folder into [Theme]/_shared background/
	- Make sure it is the entire "Datum" folder in /_shared background/, not just its contents.

2. Within [Theme]/_shared background/default.lua, add the following code below line 33:
	af[#af+1] = LoadActor("./Datum/Datum.lua", file)

3. Within [Theme]/_shared background/Normal.lua:
	- replace line 16 with the following code:
	self:visible(not ThemePrefs.Get("RainbowMode") and style ~= "SRPG9" and style ~= "Technique" and style ~= "Transistor" and style ~="Datum")

	- replace line 24 with the following code:
	if ThemePrefs.Get("RainbowMode") or style == "SRPG9" or style == "Technique" or style == "Transistor" or style =="Datum" then

4. Within [Theme]/Scripts/99 SL-ThemePrefs.lua:
	add "💾" to the visualStyleChoices table
	add "Datum" to the visualStyleValues table

5. [Optional] Within [Theme]/Sounds/_common menu music:
	add Datum = "everglow" to the songs table

6. [Optional] Within [Theme]/Sounds/ScreenGameOver music.lua:
	add the following conditional to the file:
	elseif style == "Datum" then
		audio_file = "todolist.ogg"