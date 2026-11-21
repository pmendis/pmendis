# Ender 3 V2 display-port sniffer

ESP32 firmware that **listens** to the stock Ender 3 V2 screen connection and logs
everything in a readable, timestamped form:

| Tag | What | From |
|---|---|---|
| `B>D` | Drawing commands from the mainboard to the screen (DWIN frames, decoded) | mainboard TX |
| `D>B` | Replies from the screen to the mainboard (startup handshake) | screen TX |
| `ENC` | Knob steps: direction, transitions per step, duration, gap | knob A / B |
| `BTN` | Knob button press and hold time | knob button |
| `EDGE` | Raw knob/button signal changes with µs timing (optional) | knob A / B / button |
| `BEEP` | Buzzer activity: duration and tone frequency | buzzer line |
| `MARK` | Your own labels ("opening Prepare menu") | you |

The log is the input for the replacement display: it shows which screen is up,
where each value is drawn, how the menus are ordered and what knob timing Marlin accepts.

**Nothing is transmitted.** The UART TX pins are never connected to a pin and every
GPIO is a plain input, so the printer and its stock screen keep working normally.

---

## 1. Hardware

- ESP32-S3-DevKitC-1 (default) or a classic ESP32 DevKit
- A way to tap the 10-pin display cable without cutting it: back-probe the connector,
  or make a pass-through adapter (2×5 IDC male + female, ribbon, wires soldered on)
- Logic analyzer or scope (optional, helpful to find the TX pin)

### Find each pin first (the pinout differs between board revisions)

1. **Printer off.** Use continuity from the header to the stock screen's PCB to find
   the knob A, knob B, knob button and buzzer pins.
2. **Printer on.** Measure every signal pin against GND. **Each must be at most 3.3 V.**
   If any line sits at 5 V, put a divider on it (e.g. 10 k / 20 k) before it reaches the ESP32.
3. The mainboard TX pin idles at about 3.3 V and flickers when the printer boots or the screen
   changes. The screen TX pin only flickers once at boot (handshake).

### Wiring

| Display connector signal | ESP32-S3 | Classic ESP32 |
|---|---|---|
| Mainboard TX (to screen) | GPIO16 | GPIO16 |
| Screen TX (to mainboard) | GPIO17 | GPIO17 |
| Knob A | GPIO38 | GPIO32 |
| Knob B | GPIO39 | GPIO33 |
| Knob button | GPIO40 | GPIO25 |
| Buzzer | GPIO41 | GPIO26 |
| GND | GND | GND |
| 5V | **not connected** | **not connected** |

Power the ESP32 from your computer's USB, not from the printer. Connect GND, otherwise
nothing will decode. Pins are set in `include/config.h`.

---

## 2. Build and flash

**Not built or tested on hardware yet.**

```
pip install platformio pyserial
cd hardware/ender3v2-dwin-sniffer
pio run -e esp32s3 -t upload        # or: -e esp32dev
```
The S3 log comes out of the board's **USB** port (native USB, not the UART port).

---

## 3. Capture

```
python3 tools/capture.py /dev/ttyACM0                 # S3 on Linux/macOS
python3 tools/capture.py COM5 --baud 921600           # classic ESP32 on Windows
```
Logs go to `captures/capture_<date>.log`. Type a label + Enter before each action,
e.g. `open Prepare menu`, so the log is easy to read later.

Or use any serial monitor (`pio device monitor`). Commands are a letter + Enter:

| Cmd | Effect |
|---|---|
| `h` | Help |
| `i` | Pins, current line levels, settings |
| `d` | Decoded frame lines on/off (default on) |
| `x` | Raw hex of each frame on/off (default off) |
| `e` | Raw knob/button edges with µs timing on/off (default off) |
| `u` | Dedupe on/off: hide redraws that didn't change. **Keep off for real captures.** |
| `p` | Pause/resume output |
| `s` / `z` | Statistics / reset statistics |
| `m text` | Numbered MARK line |

### Example output (illustrative)
```
     1523.412 SYS  Ender 3 V2 DWIN sniffer v1.0  target=ESP32-S3 ...
     2010.207 B>D  HANDSHAKE (board asks: are you there?)
     2011.002 D>B  HANDSHAKE_OK (screen replies)
     2015.880 B>D  SETDIR    dir=1 (5A A5)
     2016.101 B>D  JPG_SHOW  id=0 (arg=00)
     2310.554 B>D  ICON      x=72 y=168 lib=9 icon=3 flags=80
     2311.020 B>D  NUMBER    x=26 y=382 font=8x16 fg=FFFF bg=0000 digits=3.0 flags=82 raw=200 vbytes=8
     2311.301 B>D  STRING    x=12 y=270 font=10x20 fg=FFFF bg=0000 flags=42(showbg) text="PLA"
     2311.512 B>D  AREACOPY  x=14 y=7 from cache=1 (0,0)-(60,14) size=60x14
     2311.700 B>D  UPDATE    ---- frame shown ----
     5102.334 MARK #1 open Prepare menu
     5240.118 ENC  DIR+   transitions=4 net=+4 dur=6.2ms gap_since_prev=812.0ms
     5701.003 BTN  DOWN
     5806.420 BTN  UP   held=105.4ms
     5807.010 BEEP dur=48.0ms edges=2
```
`DIR+` / `DIR-` are not labelled clockwise/anticlockwise on purpose: turn the knob
clockwise once at the start (with a MARK) and note which one appears.

Problems show up as `JUNK` (bytes outside frames: wrong baud or no GND), `WARN … framing
errors` (wrong baud, noisy wiring), `OVERFLOW` (no frame end: wrong protocol) or
`WARN … data lost` (the computer isn't reading the log fast enough).

---

## 4. What to capture

Keep dedupe **off**. Add a MARK before each step. Save one log per session.

1. **Boot:** start logging, then power the printer on. Leave it 30 s on the main screen.
2. **Knob calibration:** `m clockwise 5 slow`, turn 5 detents slowly; `m anticlockwise 5 slow`;
   then 5 fast each way. Repeat with `e` (raw edges) on, then turn it off again.
3. **Every menu:** for each one, MARK it, enter it, scroll every item top to bottom and back,
   then go back. Prepare (and its sub-menus: Move, Home, Preheat, Cooldown, Disable steppers),
   Control (Temperature, Motion, Store/Read/Reset settings, Info), Level/Leveling, Print (file list).
4. **Editing a value:** nozzle and bed target temperatures, fan speed, Z offset. Change each one
   up and down and confirm.
5. **Heating:** preheat PLA and wait until both temperatures are reached, then cool down.
6. **A short print:** start it from the file list, open Tune during the print (speed, flow,
   Z offset), pause, resume, and let it finish (or stop it).
7. **Popups:** anything that asks for confirmation (stop print, reset settings, finished).
8. `s` at the end for the statistics.

Then send the logs back. From them we work out:
- how to tell which screen is showing
- the x/y position of every value (temperatures, progress, times, Z, fan, speed)
- the order of menu items and how the selection cursor is drawn
- the knob timing that works, and whether numbers use 4- or 8-byte values in your firmware

---

## 5. Files

```
platformio.ini          build environments (esp32s3, esp32dev)
include/config.h        pins, baud, buffer sizes, timing thresholds
src/main.cpp            UART listeners, knob/button/buzzer decoding, commands, output
src/dwin_decode.{h,cpp} DWIN frame splitter and decoder (no Arduino code; PC-testable)
tools/capture.py        log saver with MARK labels
```
