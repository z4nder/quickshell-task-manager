{ config, lib, pkgs, ... }:
let
  cfg = config.programs.focus-notch;

  # Icons already have correct fills — copy directly from source
  icons = ../quickshell/config/focus-icons;

  qmlFiles = [
    "FocusActivityHeatmap.qml"
    "FocusAppScreen.qml"
    "FocusBarBadge.qml"
    "FocusDatePicker.qml"
    "FocusFullTaskItem.qml"
    "FocusHoverPanel.qml"
    "FocusHoverTaskItem.qml"
    "FocusMonthCalendar.qml"
    "FocusProjectsView.qml"
    "FocusService.qml"
    "FocusStatsView.qml"
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
    home.packages = [ pkgs.focusctl ];

    home.file = lib.mkMerge [
      # All QML components
      (lib.listToAttrs (map (f: {
        name  = "${cfg.quickshellDir}/${f}";
        value = { source = ../quickshell/config/${f}; };
      }) qmlFiles))

      # Theme JS + JSON
      { "${cfg.quickshellDir}/FocusTheme.js".source  = ../quickshell/config/FocusTheme.js; }
      { "${cfg.quickshellDir}/themes.json".source     = ../quickshell/config/themes.json; }

      # Icons (pre-processed fills already in source)
      { "${cfg.quickshellDir}/focus-icons".source = icons; }
    ];
  };
}
