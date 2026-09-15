"""Explicit allowlist: reports and other build outputs never enter the image."""
from pathlib import Path

app = Path(defines["app"])
files = [str(app)]
symlinks = {"Applications": "/Applications"}
icon = str(app / "Contents/Resources/Tapas.icns")
background = defines["background"]
format = "UDZO"
filesystem = "HFS+"
window_rect = ((200, 200), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_spacing = 80
icon_size = 96
text_size = 13
label_pos = "bottom"
icon_locations = {"Tapas.app": (170, 215), "Applications": (470, 215)}
