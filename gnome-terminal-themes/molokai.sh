#!/bin/bash
# Molokai theme for gnome-terminal
gnome_term_profile=/apps/gnome-terminal/profiles/Default

palette="#1B1B1D1D1E1E:#F9F926267272:#8282B4B41414:#FDFD97971F1F:#5656C2C2D6D6:#8C8C5454FEFE:#BABABDBDB6B6:#CCCCCCCCC6C6:#505053535454:#FFFF59599595:#B6B6E3E35454:#FEFEEDED6C6C:#8C8CEDEDFFFF:#9E9E6F6FFEFE:#89899C9CA1A1:#F8F8F8F8F2F2"
bd_color="#000000000000"
fg_color="#EEEEEEEEECEC"
bg_color="#555557575353"

gconftool-2 -s -t string $gnome_term_profile/font "Terminus 16"

gconftool-2 -s -t string $gnome_term_profile/palette $palette

gconftool-2 -s -t string $gnome_term_profile/bold_color $bd_color
gconftool-2 -s -t string $gnome_term_profile/background_color $bg_color
gconftool-2 -s -t string $gnome_term_profile/foreground_color $fg_color

gconftool-2 -s -t bool $gnome_term_profile/use_theme_colors false

gconftool-2 -s -t bool $gnome_term_profile/bold_color_same_as_fg false
