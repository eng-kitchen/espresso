# dmgbuild settings for the Espresso café disk image.
# Invoked from installer/build-dmg.sh with -D defines.

import os.path

application = defines.get("app")  # noqa: F821
helper = defines.get("helper")  # noqa: F821
background_picture = defines.get("background")  # noqa: F821
volicon = defines.get("volicon")  # noqa: F821

filename = defines.get("filename", "Espresso.dmg")  # noqa: F821
volume_name = "Espresso"
format = "UDZO"

files = [application, helper]
symlinks = {"Applications": "/Applications"}

icon_locations = {
    os.path.basename(application): (140, 170),
    "Applications": (520, 170),
    os.path.basename(helper): (330, 340),
}

background = background_picture
icon = volicon

window_rect = ((200, 120), (660, 440))
icon_size = 96
text_size = 12
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
include_icon_view_settings = True
show_icon_preview = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
