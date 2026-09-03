# dmgbuild settings for the TextPolisher installer disk image.
#
# Builds the styled installer window WITHOUT driving Finder (writes .DS_Store
# directly), so it works headless / in CI as well as on a desktop Mac.
#
# Used by Scripts/make_dmg.sh:
#   dmgbuild -s Scripts/dmg_settings.py \
#       -D app=dist/TextPolisher.app -D background=Packaging/dmg-background.tiff \
#       TextPolisher dist/TextPolisher.dmg
#
# Icon positions and the window size MUST match the arrow drawn by
# Scripts/make_dmg_background.swift.

import os.path

app = defines.get("app", "dist/TextPolisher.app")
appname = os.path.basename(app)

background = defines.get("background", "Packaging/dmg-background.tiff")

format = "UDZO"

files = [app]
symlinks = {"Applications": "/Applications"}

default_view = "icon-view"
show_icon_preview = False

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

# (x, y) of the top-left corner, then (width, height) of the content area.
window_rect = ((300, 140), (640, 420))

icon_size = 112
text_size = 12

icon_locations = {
    appname: (165, 205),
    "Applications": (475, 205),
}
