Firmware
========

A firmware for RP2040 boards that implements USB MIDI and HID composite
device. Supports the Raspberry Pi Pico and the Waveshare RP2040-One.

It implements the following USB devices, each for its own purpose.

- MIDI device for communicating between controller client applications.
- HID Keyboard and Mouse to control the iOS device.
- HID Braille Display to read the device screen items via VoiceOver and control the iOS device.


Build
-----

Source the following or similar script to set environment variables.

```bash
export PICO_SDK_PATH="/path/to/raspberrypi/pico-sdk"
export PATH="/path/to/arm-gnu-toolchain/bin:$PATH"
```

Then, run build by using cmake.

```bash
make build

# Write a firmware file to the board in BOOTSEL mode.
make write
```


Board selection
---------------

The target board is selected with the `BOARD` variable, which is passed
through to the Pico SDK as `PICO_BOARD`. It defaults to `pico`.

```bash
# Raspberry Pi Pico (default)
make build

# Waveshare RP2040-One
make build BOARD=waveshare_rp2040_one
make write BOARD=waveshare_rp2040_one
```

The only hardware difference this firmware cares about is the on-board status
LED: the Pico has a single green GPIO LED, while the RP2040-One has a WS2812
RGB LED. The firmware drives whichever is present automatically via the Pico
SDK's `pico_status_led` library, so no source changes are needed.


Build flags
-----------

Each HID role can be toggled at build time. MIDI is always enabled.

- `ENABLE_KEYBOARD`       — HID Keyboard interface (default `ON`)
- `ENABLE_MOUSE`          — HID Mouse interface (default `OFF`)
- `ENABLE_ABSOLUTE_MOUSE` — HID Absolute Mouse interface (default `ON`)
- `ENABLE_BRAILLE`        — HID Braille Display interface (default `OFF`)

To build a subset, delete the existing build directory and invoke
`cmake` directly with the flags:

```bash
make clean
cmake -B cmake-build-debug -G Ninja -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_KEYBOARD=ON -DENABLE_MOUSE=OFF \
    -DENABLE_ABSOLUTE_MOUSE=ON -DENABLE_BRAILLE=ON
cmake --build cmake-build-debug
```

Disabling a role removes the corresponding USB interface, endpoint, and
HID report descriptor from the device. The MIDI channel that drives that
role is silently ignored.

Each role is driven by a fixed MIDI channel (unaffected by which roles are
enabled):

| Channel | Role           |
|--------:|----------------|
| 0       | Keyboard       |
| 1       | Mouse          |
| 2       | Absolute Mouse |
| 3       | Braille        |
| 15      | System         |

Each mouse channel is self-contained: clicks arrive as Note On/Off and
movement as CC, so the relative (ch 1) and absolute (ch 2) interfaces each
report their own buttons and position with no cross-routing. The host sends
clicks on the absolute mouse channel so the press is reported by the same
interface that owns the visible cursor.
