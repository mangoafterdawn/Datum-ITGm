**BEFORE INSTALLING: Ensure the theme you are installing the visual style into is a Simply Love based theme.**
This visual style works best and has been tested with Simply Love ZMod the most.

If there are any bugs, please submit them as an issue to the [GitHub](https://github.com/mangoafterdawn/Datum-ITGm)

1. Copy the entire `Datum` folder at `./BGAnimations/_shared background/Datum` into `[Theme]/BGAnimations/_shared_background/`

2. Within `[Theme]/BGAnimations/_shared background/default.lua`, add the following code below line 33:
	```lua
	af[#af+1] = LoadActor("./Datum/Datum.lua", file)
	```

3. Copy the entire `Graphics` folder into `[Theme]/Graphics/`

4. Within `[Theme]/BGAnimations/_shared background/Normal.lua`:

      - line 16 should look something like this:
      	```lua
      	self:visible(not ThemePrefs.Get("RainbowMode") and style ~= "SRPG10" and style ~= "Technique" and style ~= "Transistor")
      	```
      	insert the following code:
      	```lua
      	and style ~="Datum"
      	```
      	within the `self:visible(...)` call, so that it appears like this:
      	```lua
      	self:visible(not ThemePrefs.Get("RainbowMode") and style ~= "SRPG10" and style ~= "Technique" and style ~= "Transistor" and style ~="Datum")
      	```
      - line 24 should look something like this:
      	```lua
      	if ThemePrefs.Get("RainbowMode") or style == "SRPG10" or style == "Technique" or style == "Transistor" then
      	```
      	insert the following code:
      	```lua
      	or style =="Datum"
      	```
      	between the `if` statement's conditionals and `then` keyword, so that it appears like this:
      	```lua
      	if ThemePrefs.Get("RainbowMode") or style == "SRPG10" or style == "Technique" or style == "Transistor" or style =="Datum" then
      	```

5. Within `[Theme]/Scripts/99 SL-ThemePrefs.lua`, add the following code below line 20:
	```lua
	visualStyleChoices[#visualStyleChoices+1]="💾"; visualStyleValues[#visualStyleValues+1]="Datum"
	```

6. **[Optional]** Within `[Theme]/Sounds/_common menu music/default.lua`, add the following code below the `songs` table:
	```lua
	songs["Datum"]="everglow"
	```
   - Then, copy `everglow (loop).ogg` to `[Theme]/Sounds/_common menu music/`

7. **[Optional]** Within `[Theme]/Sounds/ScreenGameOver music.lua`, add the following conditional below line 7:
	```lua
	elseif style == "Datum" then audio_file = "todolist.ogg"
	```
	- Then, copy `todolist.ogg` to `[Theme]/Sounds/`

8. **[Optional]** [ZMod Only] Copy `Evaluation Fail` and `Evaluation Pass` into `[Theme]/Sounds/`

9. **[Optional]** Within `[Theme]/Graphics/ScreenTitleMenu scroll.lua`, replace `PLAYER_2` with `PLAYER_1` on line 29:
	```lua
	local textColor = PlayerColor(PLAYER_1)
	```

10. **[Optional]** Select all files within `Sounds/_overwrites` and copy them into `[Theme]/Sounds/`
