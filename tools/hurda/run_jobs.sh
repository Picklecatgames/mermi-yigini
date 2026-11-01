#!/bin/bash
# kullanım: run_jobs.sh S paralel desen
S="$1"; P="$2"; PAT="$3"
ls "$S"/$PAT | xargs -P "$P" -I{} bash -c 'n=$(basename {} .json); HCPU=1 "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python "'"$S"'/tools/process.py" -- {} > "'"$S"'/logs/$n.log" 2>&1; grep -h "@@" "'"$S"'/logs/$n.log"'
