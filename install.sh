#!/bin/bash
set -euo pipefail

BACKED_UP=()
backup_file() {
    local src="$1"
    local dest="$PWD/.backup/${src#./}"

    for f in "${BACKED_UP[@]:-}"; do
        [[ "$f" == "$src" ]] && return 0
    done

    mkdir -p "$(dirname "$dest")"
    cp -p "$src" "$dest"
    BACKED_UP+=("$src")
}

read -r -p 'Enter the theme path (e.g. ~/.itgmania/Themes/ZMod): ' FILE_PATH
FILE_PATH="${FILE_PATH/#\~/$HOME}"

#Verify the file path exists.
if [[ ! -d "$FILE_PATH" ]]; then
    echo "[Err1] $FILE_PATH: No such file or directory." >&2
    exit 1
fi

#Verify the file path is a valid SL-based theme.
themeFailToLoad() {
    echo "[Err2] Invalid theme type or directory. Must be a SimplyLove-based theme to install the \"Datum\" visual style." >&2
    exit 2
}
if [[ -f "$FILE_PATH/ThemeInfo.ini" ]]; then    
    if ! grep -qi "simply love" "$FILE_PATH/ThemeInfo.ini"; then
        themeFailToLoad
    fi
else
    themeFailToLoad
fi

echo "Installing Datum Visual Style at: $FILE_PATH ..."
echo
echo "NOTE: Before installing, make sure to configure the visual style settings in DatumOptions.lua!"
echo "If you would prefer to do this after installation is complete, it will be located at:"
echo
echo "$FILE_PATH/BGAnimations/_shared background/Datum/DatumOptions.lua"
echo
echo "Install optional theme sound effects? This will replace sound effects across ALL Visual Styles."
echo "(Current sound effects will be backed up at $PWD/.backup/Sounds/)"
read -r -p "[Y/n]: " REPLY_SOUNDS
echo
[[ "${REPLY_SOUNDS:-y}" =~ ^[Yy] ]] && DO_SOUNDS_INSTALLATION=true || DO_SOUNDS_INSTALLATION=false

echo "Install optional theme tweaks? This will only minorly tweak the base theme colors."
read -r -p "[Y/n]: " REPLY_TWEAKS
[[ "${REPLY_TWEAKS:-y}" =~ ^[Yy] ]] && DO_TWEAKS_INSTALLATION=true || DO_TWEAKS_INSTALLATION=false

SHARED_BG="$FILE_PATH/BGAnimations/_shared background"
GRAPHICS="$FILE_PATH/Graphics"
SCRIPTS="$FILE_PATH/Scripts"
SOUNDS="$FILE_PATH/Sounds"

if [[ -d "$SHARED_BG" ]]; then
    # Copy main visual style lua and assets into BGAnimations
    cp -r "./BGAnimations/_shared background/Datum" "$SHARED_BG"
    # Copy the version of the visual style options at the current directory into BGAnimations
    # (placed at the current directory to be more accessible to the user installing/configuring it)
    cp -f "./DatumOptions.lua" "$SHARED_BG/Datum"

    ### Make the visual style selectable and visible.

    SHARED_BG_DEFAULT_LUA="af[#af+1] = LoadActor(\"./Datum/Datum.lua\", file)"
    # Check if the visual style has already been installed in default.lua
    if grep -qF "Datum.lua" "$SHARED_BG/default.lua"; then
        # TODO: Delete & Reinstall the visual style changes in case of structural changes.
        :
    elif grep -qF "af[#af+1] = LoadActor" "$SHARED_BG/default.lua"; then
        # Add the line to allow the visual style to be visible.
        backup_file "$SHARED_BG/default.lua"
        sed -i "\|^[[:space:]]*return af|i $SHARED_BG_DEFAULT_LUA" "$SHARED_BG/default.lua"
    else
        echo "[Err3] Failed to match line in: $SHARED_BG/default.lua" >&2
        exit 3
    fi

    # Check if the visual style has already been installed in Normal.lua
    if grep -qF "Datum" "$SHARED_BG/Normal.lua"; then
        # TODO: Delete & Reinstall the visual style changes in case of structural changes.
        :
    elif grep -qF "self:visible(not ThemePrefs" "$SHARED_BG/Normal.lua"; then
        # Edit the lines to allow the visual style to be visible.
        backup_file "$SHARED_BG/Normal.lua"
        sed -i -E 's/(self:visible\(not ThemePrefs\.Get\("RainbowMode"\)[^)]*)(\))/\1 and style ~= "Datum"\2/' "$SHARED_BG/Normal.lua"
        sed -i -E '/ThemePrefs\.Get\("RainbowMode"\)/s/[[:space:]]*then/ or style == "Datum" then/' "$SHARED_BG/Normal.lua"
    else
        echo "[Err3] Failed to match line in: $SHARED_BG/Normal.lua" >&2
        exit 3
    fi
else
    echo "[Err4] Failed to install _shared background components." >&2
    exit 4
fi

if [[ -d "$GRAPHICS" ]]; then
    # Install more Visual Style assets.
    cp -r "./Graphics/_VisualStyles/Datum" "$GRAPHICS/_VisualStyles/"

    if [[ "$DO_TWEAKS_INSTALLATION" == true ]]; then
    # Change the color of the title screen options text to be
    # the same as the currently selected Simply Love color.
        if [[ -f "$GRAPHICS/ScreenTitleMenu scroll.lua" ]]; then
            backup_file "$GRAPHICS/ScreenTitleMenu scroll.lua"
            sed -i 's/PLAYER_2/PLAYER_1/g' "$GRAPHICS/ScreenTitleMenu scroll.lua"
        fi
    fi
else
    echo "[Err4] Failed to install Graphics components." >&2
    exit 4
fi

THEMEPREFS="$SCRIPTS/99 SL-ThemePrefs.lua"
if [[ -d "$SCRIPTS" ]]; then
    if grep -qF "Datum" "$THEMEPREFS"; then
        # TODO: Delete & Reinstall the visual style changes in case of structural changes.
        :
    elif grep -qF "local visualStyleValues" "$THEMEPREFS"; then
        # Add the line to make the visual style selectable.
        backup_file "$THEMEPREFS"
        sed -i '/local visualStyleValues[[:space:]]*=[[:space:]]*{/a visualStyleChoices[#visualStyleChoices+1]="💾"; visualStyleValues[#visualStyleValues+1]="Datum"' "$THEMEPREFS"
    else
        echo "[Err3] Failed to match line in: $SCRIPTS/99 SL-ThemePrefs.lua" >&2
        exit 3
    fi
else
    echo "[Err4] Failed to install Scripts components." >&2
    exit 4
fi

if [[ -d "$SOUNDS" ]]; then
    if grep -qF "Datum" "$SOUNDS/_common menu music/default.lua"; then
        # TODO: Delete & Reinstall the visual style changes.
        :
    elif grep -qF "local songs" "$SOUNDS/_common menu music/default.lua"; then
        # Add the line to give the visual style its own Menu music
        backup_file "$SOUNDS/_common menu music/default.lua"
        sed -i '/}/a songs["Datum"]="everglow"' "$SOUNDS/_common menu music/default.lua"
    else
        echo "[Err3] Failed to match line in: $SOUNDS/_common menu music/default.lua" >&2
        exit 3
    fi

    if grep -qF "Datum" "$SOUNDS/ScreenGameOver music.lua"; then
        # TODO: Delete & Reinstall the visual style changes.
        :
    elif grep -qF "audio_file" "$SOUNDS/ScreenGameOver music.lua"; then
        # Add the line to give the visual style its own Game Over music.
        backup_file "$SOUNDS/ScreenGameOver music.lua"
        sed -i '/end/i elseif style == "Datum" then audio_file = "todolist.ogg"' "$SOUNDS/ScreenGameOver music.lua"
    else
        echo "[Err3] Failed to match line in: $SOUNDS/ScreenGameOver music.lua" >&2
        exit 3
    fi

    # Add menu music files
    cp "./Sounds/_common menu music/everglow (loop).ogg" "$SOUNDS/_common menu music/"
    cp "./Sounds/todolist.ogg" "$SOUNDS/"

    # Only ZMod has dedicated folders for Evaluation Pass/Fail.
    if [[ -d "$SOUNDS/Evaluation Pass" && -d "$SOUNDS/Evaluation Fail" ]]; then
        cp "./Sounds/Evaluation Pass/workinprogress (loop).ogg" "$SOUNDS/Evaluation Pass/"
        cp "./Sounds/Evaluation Fail/workinprogress (loop).ogg" "$SOUNDS/Evaluation Fail/"
    else
        # TODO: Edit Screen Eval Music redirects in SL main. because its different.
        :
    fi

    if [[ "$DO_SOUNDS_INSTALLATION" == true ]]; then
        # Back up the current version of the sound effects.
        mkdir -p .backup/Sounds
        shopt -s nullglob
        REPLACE_LIST=(./Sounds/_overwrites/*.ogg)

        for overwrite_file in "${REPLACE_LIST[@]}"; do
            filename=$(basename "$overwrite_file")
            original_file="$SOUNDS/$filename"
            if [[ -f "$original_file" ]]; then
                cp "$original_file" .backup/Sounds/
            fi
        done

        # Install the new sounds.
        for overwrite_file in "${REPLACE_LIST[@]}"; do
            cp "$overwrite_file" "$SOUNDS/"
        done
    fi

else
    echo "[Err4] Failed to install Sounds components." >&2
    exit 4
fi

echo
echo "\"Datum\" Visual Style installed successfully!"