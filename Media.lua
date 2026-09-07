local ADDON_NAME, ns = ...

-- Shared media catalog. Layout consumes the actual paths/colors while Config
-- consumes the same keys and display names. New fonts/textures should be added
-- here rather than duplicated across runtime and configuration code.
ns.Media = {
    fonts = {
        friz = { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        arial = { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
        morpheus = { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
        skurri = { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
    },
    fontOrder = { "friz", "arial", "morpheus", "skurri" },

    textures = {
        flat = { name = "Flat", path = "Interface\\Buttons\\WHITE8x8" },
        blizzard = { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    },
    textureOrder = { "flat", "blizzard" },

    healthColors = {
        automatic = { name = "Automatic" },
        green = { name = "Green", rgb = { 0.18, 0.72, 0.28 } },
        blue = { name = "Blue", rgb = { 0.20, 0.48, 0.85 } },
        gray = { name = "Gray", rgb = { 0.48, 0.50, 0.52 } },
        red = { name = "Red", rgb = { 0.78, 0.22, 0.22 } },
    },
    healthColorOrder = { "automatic", "green", "blue", "gray", "red" },

    powerColors = {
        automatic = { name = "Automatic" },
        blue = { name = "Blue", rgb = { 0.20, 0.45, 0.90 } },
        purple = { name = "Purple", rgb = { 0.55, 0.28, 0.85 } },
        gray = { name = "Gray", rgb = { 0.45, 0.47, 0.50 } },
    },
    powerColorOrder = { "automatic", "blue", "purple", "gray" },
}

function ns.GetFontPath(key)
    local entry = ns.Media.fonts[key] or ns.Media.fonts.friz
    return entry.path
end

function ns.GetTexturePath(key)
    local entry = ns.Media.textures[key] or ns.Media.textures.flat
    return entry.path
end
