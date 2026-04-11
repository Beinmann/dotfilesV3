#!/bin/sh

path=~/Main/Uni/SoSe2024/Bachelorarbeit/BachelorAnfangsPraesentation/beamer-template

latexmk --interaction=nonstopmode --halt-on-error

pkill xournalpp

open "$path/slides.pdf" &
