#!/usr/bin/env python3
"""Save the sniffer's output to a log file while you use the printer.

    pip install pyserial
    python3 tools/capture.py /dev/ttyACM0            # Linux, ESP32-S3
    python3 tools/capture.py COM5 --baud 921600       # Windows, classic ESP32

Everything the sniffer prints is shown and written to captures/<date>.log.
Type a line + Enter to label what you are about to do, e.g.
    open Prepare menu
and it is logged as a numbered MARK. A bare Enter adds an unlabelled MARK.
Single-letter sniffer commands (h i d x e u p s z) are passed through as is.
Ctrl+C to stop.
"""

import argparse
import datetime
import os
import sys
import threading

try:
    import serial
except ImportError:
    sys.exit("pyserial is missing: pip install pyserial")

COMMANDS = {"h", "i", "d", "x", "e", "u", "p", "s", "z", "?"}


def reader(ser, out, stop):
    while not stop.is_set():
        try:
            data = ser.readline()
        except serial.SerialException as exc:
            print(f"\n[serial error: {exc}]")
            stop.set()
            return
        if not data:
            continue
        line = data.decode("utf-8", "replace").rstrip("\r\n")
        out.write(line + "\n")
        out.flush()
        print(line)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("port", help="serial port of the sniffer, e.g. /dev/ttyACM0 or COM5")
    ap.add_argument("--baud", type=int, default=921600, help="921600 for classic ESP32; ignored by the S3 USB port")
    ap.add_argument("--out", help="log file (default captures/capture_<date>.log)")
    args = ap.parse_args()

    path = args.out
    if not path:
        os.makedirs("captures", exist_ok=True)
        path = os.path.join("captures", datetime.datetime.now().strftime("capture_%Y%m%d_%H%M%S.log"))

    ser = serial.Serial()
    ser.port = args.port
    ser.baudrate = args.baud
    ser.timeout = 0.2
    # Keep DTR/RTS released so opening the port does not reset the ESP32.
    ser.dtr = False
    ser.rts = False
    ser.open()

    stop = threading.Event()
    with open(path, "w", encoding="utf-8") as out:
        out.write(f"# capture started {datetime.datetime.now().isoformat()} port={args.port}\n")
        t = threading.Thread(target=reader, args=(ser, out, stop), daemon=True)
        t.start()
        print(f"[logging to {path}; type a label + Enter to add a MARK, Ctrl+C to stop]")
        ser.write(b"i\n")
        try:
            for line in sys.stdin:
                if stop.is_set():
                    break
                text = line.strip()
                if text.lower() not in COMMANDS:
                    text = ("m " + text).strip()
                ser.write((text + "\n").encode("utf-8", "replace"))
        except KeyboardInterrupt:
            pass
        finally:
            try:
                ser.write(b"s\n")      # final statistics into the log
                threading.Event().wait(0.5)
            except serial.SerialException:
                pass
            stop.set()
            t.join(timeout=1)
            ser.close()
    print(f"\n[saved {path}]")


if __name__ == "__main__":
    main()
