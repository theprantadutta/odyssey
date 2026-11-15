#!/usr/bin/env bash
# Records the Odyssey tour on the Galaxy A24 (1080x2340) as rec1.mp4.
#
#   bash store_video/tools/record_tour.sh [serial]
#
# Start with Odyssey open on Home, signed in as the demo account, in light
# mode (`adb shell cmd uimode night no`; restore it afterwards). Other
# sessions share the phone: agree a turn first, and never restart adb.
# Tap coordinates are for the A24 and the New York City trip; check them
# with a screenshot on any other device or account.
set -u
# Git Bash rewrites arguments that look like POSIX paths (/sdcard/...) into
# Windows paths; adb needs them as they are.
export MSYS_NO_PATHCONV=1
S="${1:-RR8W901JDRL}"
OUT="$(cd "$(dirname "$0")" && pwd)"
a() { adb -s "$S" shell "$@" >/dev/null; }
tap() { a input tap "$1" "$2"; }
swipe() { a input swipe "$1" "$2" "$3" "$4" "${5:-600}"; }
T0=0
mark() { echo "$1 $(awk "BEGIN{printf \"%.1f\", $(date +%s.%N) - $T0}")"; }

a "nohup screenrecord --bit-rate 8000000 --time-limit 178 /sdcard/odyssey_rec1.mp4 >/dev/null 2>&1 &"
T0=$(date +%s.%N)
sleep 2
mark home;          sleep 3; swipe 540 1700 540 1000 900; sleep 2; swipe 540 1000 540 1700 900; sleep 2
mark trips;         tap 450 2235; sleep 3; swipe 540 1800 540 900 900; sleep 2; swipe 540 900 540 1800 900; sleep 2
mark trip_open;     tap 540 1800; sleep 4
mark overview;      swipe 540 1900 540 1300 900; sleep 2; swipe 540 1300 540 1900 900; sleep 2
mark plan;          tap 417 1494; sleep 3; swipe 540 1900 540 1300 900; sleep 3
# The rest of the tour (packing, spend, documents, memories, map) is not
# scripted: where the trip tab bar ends up depends on how far the page flings,
# and blind taps here ticked plan items instead. Record it as rec2.mp4 by hand,
# taking a screencap after each tab tap to find the next tab. On the A24 the
# tab bar settles near y=1170-1200 once a tab is open; it scrolls sideways, so
# Documents, Memories and Map come into view as you go right.
mark end;           sleep 1
a pkill -INT screenrecord
sleep 3
adb -s "$S" pull /sdcard/odyssey_rec1.mp4 "$OUT/rec1.mp4" >/dev/null
a rm /sdcard/odyssey_rec1.mp4
echo "saved $OUT/rec1.mp4"
