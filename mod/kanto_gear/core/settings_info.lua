-- Explanations are shared by the touch settings and the native mod menu.
local Info = {}
Info.help = {
  language = "Language of Kanto Gear. Game translations are separate mods.",
  theme_v3 = "Choose a light or dark companion. Auto follows the time of day.",
  clock_source = "Choose the game clock or your device clock. Games without a clock use device time.",
  clock_format = "Show 12-hour or 24-hour time. System follows your device preference.",
  ui_motion = "Short page transitions in Quality mode. Performance disables UI animations. Turn off for immediate changes in both modes.",
  map_motion = "Both keep maps smooth at up to 30 updates a second. Performance disables UI animations; Quality allows transitions. Map detail stays the same.",
  info_level = "Choose a complete information preset, or Custom to control exploration, Dex, battle, partner data and stamps separately. Game controls stay available.",
  local_map = "Show the area map in older themes. Discovery is controlled separately.",
  display_mode = "Separate uses two displays. Combined shows both views together. Fullscreen switches views. Phone uses a paired browser on the same Wi-Fi.",
  fullscreen_start = "Choose which view appears first in fullscreen mode.",
  auto_battle_screen = "Show Gear for battle choices, then return to the game for battle text and animations.",
  combined_layout = "Auto fits the window. Stacked puts Gear below the game; side by side puts it beside the game. Overlay uses a small corner view.",
  combined_primary = "Choose which view gets the larger area in the combined layout.",
  secondary_size = "Size of the smaller view. Auto adapts to the window dimensions.",
  bottom_safe_area = "Reserve empty space below both views for device controls or a gesture bar.",
  overlay_corner = "Place the smaller overlay view in this corner of the game window.",
  overlay_button = "Optional shortcut to hide or show the corner overlay.",
  display_target = "Choose the display used by Gear. Auto uses the host's available second display.",
  screen_swap = "Let the host's Y shortcut exchange the game and Gear views.",
  battle_view = "Companion keeps the original battle above with touch controls below. Info shows opponent details. Gear moves menus and text below; Full Gear moves HP bars too. Outside battles the game stays unchanged.",
  caught_icon = "Mark wild opponents you have already caught. Uses the current save's Pokedex.",
  type_hints = "Show type effectiveness for your attacks. Does not change which Pokemon or areas are revealed.",
  move_details = "Show attack power, accuracy and effect details in battle and move inspection.",
  catch_odds = "Show estimated catch chances for Poke Balls. Estimates are not a guarantee.",
  keyboard_layout = "Choose the order of letters on Gear's touch keyboard. QWERTY puts Y in the top row; QWERTZ puts Z there.",
  ui_haptics = "Brief vibration for accepted touches on devices that support it.",
  home_help = "Show how to add, move and remove apps and widgets on Home.",
  reset_home = "Restore the initial Home layout and installed apps. Notes and game progress are kept. Tap Reset twice to confirm.",
  reset_options = "Restore Gear's default settings, including discovery and battle helpers. Notes and game saves are kept. Tap Reset twice to confirm.",
}
Info.discovery = {
  purist = "Original-game information only. No live area map, encounter guide, extra battle hints, completion totals or hidden Pokemon values. Touch controls and your notes stay available.",
  enhanced = "Guides for visited places, encounter chances, Dex research and battle hints. Hidden items, unvisited places, future tasks and hidden partner values stay concealed.",
  spoiler = "Enable every information switch, including hidden items, unvisited places, future tasks, genes and egg contents. This does not unlock anything in the game.",
  custom = "Start from your preset. Set each category's facts for all apps and widgets.",
}
function Info.description(key, value)
  return key == "info_level" and Info.discovery[value] or Info.help[key]
end
return Info
