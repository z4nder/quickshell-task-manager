.pragma library

// ── Theme presets ─────────────────────────────────────────────────────────────
var themes = {
    "dark": {
        bg: "#111111", bgPanel: "#1c1c1e", bgItem: "#2c2c2e", bgHover: "#3a3a3c",
        textPrimary: "#ffffff", textSecondary: "#8e8e93", textMuted: "#48484a",
        accent: "#e53935", accentDim: "#7b1a1a", border: "#3a3a3c"
    },
    "forest": {
        bg: "#0d1f0d", bgPanel: "#152415", bgItem: "#1e331e", bgHover: "#274027",
        textPrimary: "#e8f5e9", textSecondary: "#81c784", textMuted: "#4a7a4a",
        accent: "#4caf50", accentDim: "#2e7d32", border: "#274027"
    },
    "neon": {
        bg: "#0a0010", bgPanel: "#130020", bgItem: "#1e0035", bgHover: "#2a0050",
        textPrimary: "#ffffff", textSecondary: "#ce93d8", textMuted: "#6a3080",
        accent: "#e040fb", accentDim: "#7b1fa2", border: "#2a0050"
    },
    "light": {
        bg: "#f5f5f7", bgPanel: "#ffffff", bgItem: "#e5e5ea", bgHover: "#d1d1d6",
        textPrimary: "#1c1c1e", textSecondary: "#636366", textMuted: "#aeaeb2",
        accent: "#e53935", accentDim: "#ffcdd2", border: "#d1d1d6"
    },
    "midnight": {
        bg: "#000000", bgPanel: "#0d0d0d", bgItem: "#1a1a1a", bgHover: "#262626",
        textPrimary: "#ffffff", textSecondary: "#999999", textMuted: "#444444",
        accent: "#4488ff", accentDim: "#1a3a7a", border: "#262626"
    }
}

function getTheme(name) {
    return themes[name] || themes["dark"]
}

// Active theme — pull from themes object
var _t = themes["dark"]

// Backgrounds
var bg       = _t.bg
var bgPanel  = _t.bgPanel
var bgItem   = _t.bgItem
var bgHover  = _t.bgHover

// Text
var textPrimary   = _t.textPrimary
var textSecondary = _t.textSecondary
var textMuted     = _t.textMuted

// Accent
var accent    = _t.accent
var accentDim = _t.accentDim

// Borders
var border = _t.border

// Radii
var radiusSm = 6
var radiusMd = 10
var radiusLg = 14

// Font sizes
var fontSm = 11
var fontMd = 13
var fontLg = 15
var fontXl = 17

// Icons — relative to the QML file, works in dev and after deploy
var iconsPath = "focus-icons/"
