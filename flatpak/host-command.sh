#!/bin/sh
exec flatpak-spawn --host "${0##*/}" "$@"
