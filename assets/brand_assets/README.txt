POP CALC BRAND ASSETS
=====================
Master concept: extruded "=" mark, dark ink on marigold (#FFAE00).
Dark variant:   amber mark on graphite (#141414).
Everything is rendered from vector, so edges are crisp at every size.
Fonts in the wordmark and feature graphic are Antonio (SIL OFL), converted to outlines.

FOLDERS
-------
store/
  play_store_icon_512.png            Play Console > Main store listing > App icon (512x512, 32-bit PNG, full square)
  feature_graphic_1024x500.png       Play Console > Feature graphic (1024x500, 24-bit PNG, no alpha)
  feature_graphic_1024x500.svg       Editable vector source
  app_store_icon_1024.png            For a future iOS release (1024x1024, no alpha)

android_res/                         Drop-in Android resources
  Copy the CONTENTS into  android/app/src/main/res/  and allow overwrite.
  mipmap-*/ic_launcher.png           Legacy rounded-square icon (Android 7 and older)
  mipmap-*/ic_launcher_round.png     Legacy round icon
  mipmap-*/ic_launcher_foreground.png    Adaptive icon foreground (108dp layer, glyph inside the 66dp safe zone)
  mipmap-*/ic_launcher_monochrome.png    Android 13+ themed icon layer
  mipmap-anydpi-v26/ic_launcher.xml (+ _round.xml)   Adaptive icon definitions
  values/ic_launcher_background.xml  Adaptive background color (#FFAE00)
  Optional: in AndroidManifest.xml <application> add
      android:roundIcon="@mipmap/ic_launcher_round"
  Do NOT also run flutter_launcher_icons, it would overwrite these files.

splash/
  splash_android12.png / _dark.png   1152x1152, glyph inside the 768px circle (Android 12+ splash)
  splash_logo.png / _dark.png        512x512 centered logo (Android 11 and older, iOS)
  splash_1080x1920.png / _dark.png   Full-screen splash for any other use
  flutter_native_splash.yaml         Ready-to-use config for the flutter_native_splash package
  Note: the native splash follows the phone's light/dark setting, not the skin picked inside the app.

logo/
  pop_calc_icon.svg / _2048.png            Icon on marigold tile (full square)
  pop_calc_icon_rounded.svg / _2048.png    Icon with rounded corners (README, website, social)
  pop_calc_mark.svg / _2048.png            Mark only, transparent background
  pop_calc_mark_dark.svg / _2048.png       Amber mark for dark backgrounds, transparent
  pop_calc_lockup_light_bg.svg / .png      Icon + POP CALC wordmark, dark text
  pop_calc_lockup_dark_bg.svg / .png       Icon + POP CALC wordmark, light text

web/                                  Copy into your repo's web/ folder
  favicon.png, icons/Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png

social/
  github_social_preview_1280x640.png  GitHub repo > Settings > Social preview

NOT INCLUDED: Play Store screenshots. They must show the real app, so capture them on a device or emulator
at full resolution (for example 1080x2400) rather than resizing the low-resolution README images.

SUGGESTED ALT TEXT (Play Console, up to 140 characters each)
  Feature graphic: "Giant 3D numerals showing 1,024 + 5% = 1,075.2 on a dark background."
  App icon:        "Pop Calc icon, a bold 3D equals sign on an orange background."
