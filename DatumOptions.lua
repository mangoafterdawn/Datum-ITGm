--//////////////////////////////////////////////////
--                 OPTION SELECT
--//////////////////////////////////////////////////

local DatumOptions = {}

-- ///////////////////////////////
--       BACKGROUND OPTIONS
-- ///////////////////////////////

-- TODO: Light Mode? Would be a lot of work if there's not
-- a good way to have the whole theme invert the text color.
-- "Light"
-- "Dark"
-- DatumOptions.COLOR_MODE = "Dark"

-- if true, the central model is visible.
DatumOptions.DATUM_MODEL_ENABLED = true -- (DEFAULT: true)

-- the opacity of the datum model, in percent (0-100).
DatumOptions.DATUM_OPACITY = 85 -- (DEFAULT: 85)

-- if true, the central model will have a hue shifted version of the current selected
-- Simply Love color in its gradient. otherwise, it will just be a single color.
DatumOptions.DATUM_HUE_SHIFT_ENABLED = true -- (DEFAULT: true)

-- the number that the central model should shift in hue, in degrees.
-- can be negative or positive, useful range -180 to 180 degrees.
-- recommend a higher value like 64 if GAY_MODE_ENABLED.
DatumOptions.DATUM_HUE_SHIFT_AMOUNT = 32 -- (DEFAULT: 32)

-- if true, the background sine wave elements will be visible.
DatumOptions.SINE_ENABLED = true -- (DEFAULT: true)

-- the line width of the background sine wave elements, not quite in pixels.
DatumOptions.SINE_WIDTH = 1.5 -- (DEFAULT: 1.5)

-- the opacity of the background sine wave elements, in percent (0-100).
DatumOptions.SINE_OPACITY = 100 -- (DEFAULT: 100)

-- ///////////////////////////////
--         COLOR OPTIONS
-- ///////////////////////////////

-- Better Than RainbowMode.
-- if true, colored elements constantly hue shift in a rainbow.
DatumOptions.GAY_MODE_ENABLED = false -- (DEFAULT: false)

-- the speed that the constant hue shift will be, in degrees per second.
-- can be negative or positive.
DatumOptions.GAY_MODE_SPEED = 40 -- (DEFAULT: 40)

-- if true, automatically have GAY_MODE_ENABLED during June for Pride Month.
DatumOptions.AUTO_PRIDE_ENABLED = true -- (DEFAULT: true)


-- ///////////////////////////////
--         OTHER OPTIONS
-- ///////////////////////////////

-- if true, enables the update function that controls the motion of many objects.
-- otherwise, uses only stepmania tweens where implemented.
DatumOptions.UPDATE_LOOP_ENABLED = true -- (DEFAULT: true)

    -- ///////////////////////////////
    --       TRANSITION OPTIONS
    -- ///////////////////////////////
    -- these options necessarily require UPDATE_LOOP_ENABLED, as screen transitions use
    -- the update loop to function.

    -- if true, short screen transitions will play between some screens.
    DatumOptions.DO_SCREEN_TRANSITIONS = true -- (DEFAULT: true)

        -- if true, a short black bar transition will play between some screens.
        -- otherwise, only transition animations using already existing elements will play.
        DatumOptions.ENABLE_BAR_TRANSITION = true -- (DEFAULT: true)

        -- specifies the type of transition to do for the MusicWheel.
        -- "TextOnly"  -- Only MusicWheel text (song title/subtitle) will transition
        -- "OpacityOnly"  -- Only MusicWheel opacity will transition
        -- "Full"  -- Both the opacity and text of the MusicWheel will transition
        -- "SimplyLove"  -- Only the default SimplyLove screen transition will play.
        DatumOptions.MUSICWHEEL_TRANSITION = "Full" -- (DEFAULT: "Full")

    -- (Debug! Don't change this!)
    DatumOptions.TRANSITION_SPEED = 1.0 -- (DEFAULT: 1.0)

return DatumOptions