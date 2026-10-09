POP CALC BRAND ASSETS
=====================
Master concept: extruded "=" mark, dark ink on marigold (#FFAE00).
Dark variant:   amber mark on charcoal (#141414).
Everything is rendered from vector, so edges are crisp at every size.
Fonts in the wordmark and feature graphic are Antonio (SIL OFL), converted to outlines.

FOLDERS
-------
store/
  play_store_icon_512.png            Play Console > Main store listing > App icon (512x512, 32-bit PNG, full square)
  feature_graphic_1024x500.png       Play Console > Feature graphic (1024x500, 24-bit PNG, no alpha)
  feature_graphic_1024x500.svg       Editable vector source
  app_store_icon_1024.png            For a future iOS release (1024x1024, no alpha)

logo/
  pop_calc_icon.svg / _2048.png            Icon on marigold tile (full square)
  pop_calc_icon_rounded.svg / _2048.png    Icon with rounded corners (README, website, social)
  pop_calc_mark.svg / _2048.png            Mark only, transparent background
  pop_calc_mark_dark.svg / _2048.png       Amber mark for dark backgrounds, transparent
  pop_calc_lockup_light_bg.svg / .png      Icon + POP CALC wordmark, dark text
  pop_calc_lockup_dark_bg.svg / .png       Icon + POP CALC wordmark, light text

social/
  github_social_preview_1280x640.png  GitHub repo > Settings > Social preview

ALREADY IN THE PROJECT (no second copy is kept in this folder)
  Launcher icons   android/app/src/main/res/mipmap-*/ and values/ic_launcher_background.xml
                   Do NOT also run flutter_launcher_icons, it would overwrite them.
  Splash images    assets/splash/, set up by flutter_native_splash.yaml in the project root.
                   The native splash follows the phone's light/dark setting, not the skin picked inside the app.
  Web icons        web/favicon.png and web/icons/

NOT INCLUDED: Play Store screenshots. They must show the real app, so capture them on a device or emulator
at full resolution (for example 1080x2400) rather than resizing the low-resolution README images.

SUGGESTED ALT TEXT (Play Console, up to 140 characters each)
  Feature graphic: "Giant 3D numerals showing 1,024 + 5% = 1,075.2 on a dark background."
  App icon:        "Pop Calc icon, a bold 3D equals sign on an orange background."
