{ config, lib, pkgs, ... }:
let
  cfg      = config.programs.focus-notch;
  focusctl = pkgs.callPackage ./package.nix {};

  # Pre-color the Heroicons SVGs at build time
  icons = pkgs.runCommand "focus-notch-icons" {} ''
    mkdir -p $out
    src=${../assets}
    ${lib.concatStrings (lib.mapAttrsToList (name: color: ''
      sed 's/currentColor/${color}/g' "$src/${name}.svg" > "$out/${name}.svg"
    '') {
      "check"                = "#e53935";
      "play"                 = "#ffffff";
      "play-accent"          = "#e53935";   # play.svg re-colored accent
      "pause"                = "#e53935";
      "trash"                = "#48484a";
      "arrows-up-down"       = "#8e8e93";
      "arrows-pointing-out"  = "#8e8e93";
      "cog-6-tooth"          = "#8e8e93";
      "chevron-left"         = "#8e8e93";
      "chevron-right"        = "#8e8e93";
      "pencil-square"        = "#8e8e93";
    })}
    # play-accent sources from play.svg
    sed 's/currentColor/#e53935/g' "$src/play.svg" > "$out/play-accent.svg"
  '';

  qmlFiles = [
    "FocusActivityHeatmap.qml"
    "FocusAppScreen.qml"
    "FocusBarBadge.qml"
    "FocusFullTaskItem.qml"
    "FocusHoverPanel.qml"
    "FocusHoverTaskItem.qml"
    "FocusMonthCalendar.qml"
    "FocusService.qml"
    "FocusWidget.qml"
  ];

in {
  options.programs.focus-notch = {
    enable = lib.mkEnableOption "Focus Notch — Quickshell task manager";

    quickshellDir = lib.mkOption {
      type    = lib.types.str;
      default = ".config/quickshell";
      description = "Path relative to home where Quickshell config lives.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ focusctl ];

    home.file = lib.mkMerge [
      # Deploy each QML file
      (lib.listToAttrs (map (f: {
        name  = "${cfg.quickshellDir}/${f}";
        value = { source = ../quickshell/config/${f}; };
      }) qmlFiles))

      # Deploy FocusTheme.js (iconsPath is relative, no substitution needed)
      { "${cfg.quickshellDir}/FocusTheme.js".source = ../quickshell/config/FocusTheme.js; }

      # Deploy pre-colored icons
      { "${cfg.quickshellDir}/focus-icons".source = icons; }
    ];
  };
}
