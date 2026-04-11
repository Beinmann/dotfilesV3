#!/bin/sh

# Für die Bacheloranfangspraesentation
# In xbindkeys habe ich Ctrl + F6 auf dieses Script gesetzt
path=~/Main/Uni/SoSe2024/Bachelorarbeit/BachelorAnfangsPraesentation/beamer-template

latexmk --interaction=nonstopmode --halt-on-error; pkill xournalpp

open "$path/slides.pdf" &

