pragma Singleton
import QtQuick

QtObject {
    // Backgrounds
    readonly property color bg:       "#111111"
    readonly property color bgPanel:  "#1c1c1e"
    readonly property color bgItem:   "#2c2c2e"
    readonly property color bgHover:  "#3a3a3c"

    // Text
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#8e8e93"
    readonly property color textMuted:     "#48484a"

    // Accent
    readonly property color accent:      "#e53935"
    readonly property color accentDim:   "#7b1a1a"

    // Borders
    readonly property color border: "#3a3a3c"

    // Radii
    readonly property int radiusSm: 6
    readonly property int radiusMd: 10
    readonly property int radiusLg: 14

    // Font sizes
    readonly property int fontSm:   11
    readonly property int fontMd:   13
    readonly property int fontLg:   15
    readonly property int fontXl:   17
}
