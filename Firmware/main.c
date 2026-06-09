#include <string.h>

#include "bsp/board.h"
#include "pico/status_led.h"
#include "pico/stdlib.h"
#include "tusb.h"

// Set to 1 to repurpose the on-board LED as a "Braille Output Report
// received" indicator (toggles on every SET_REPORT delivering cell data,
// holds the new state for 50 ms so single events are still visible).
#define DEBUG 1

// MIDI channels (0-based) assigned per role. See .plans/ for spec.
#define MIDI_CH_KEYBOARD 0
#define MIDI_CH_MOUSE 1
#define MIDI_CH_ABS_MOUSE 2
#define MIDI_CH_BRAILLE 3
#define MIDI_CH_SYSTEM 15

#define ABS_MOUSE_LOGICAL_MAX 16383

#if ENABLE_BRAILLE
#define REPORT_ID_BRAILLE 3

#define BRAILLE_CELL_COUNT 40
#define BRAILLE_ROUTING_BYTES 5 // ceil(40 / 8)
#define BRAILLE_INPUT_REPORT_SZ 7 // 5 routing + 1 dots + 1 space/pad
#endif

#if ENABLE_KEYBOARD
static uint8_t kbd_modifiers;
static uint8_t kbd_keys[6];
static bool kbd_dirty;
#endif

#if ENABLE_MOUSE
// Relative mouse state. Buttons, movement, and scroll all arrive on
// MIDI ch=MIDI_CH_MOUSE and report through the relative mouse HID interface.
static uint8_t mouse_buttons;
static int8_t mouse_dx;
static int8_t mouse_dy;
static int8_t mouse_wheel_v;
static int8_t mouse_wheel_h;
static bool mouse_dirty;
#endif

#if ENABLE_ABSOLUTE_MOUSE
// Absolute mouse state. Buttons, position, and wheel all arrive on
// MIDI ch=MIDI_CH_ABS_MOUSE and report through the absolute mouse HID
// interface. Position is two 7-bit CC pairs per axis (0..ABS_MOUSE_LOGICAL_MAX);
// the LSB CC commits the new value and the Y LSB triggers a HID report.
// Position is initialised to screen centre so a click before any explicit
// move lands somewhere reasonable rather than at (0, 0). Wheel and pan are
// relative deltas (same as the relative mouse) accumulated until reported.
static uint8_t abs_mouse_buttons;
static uint16_t abs_mouse_x = ABS_MOUSE_LOGICAL_MAX / 2;
static uint16_t abs_mouse_y = ABS_MOUSE_LOGICAL_MAX / 2;
static uint8_t abs_mouse_x_msb;
static uint8_t abs_mouse_y_msb;
static int8_t abs_mouse_wheel;
static int8_t abs_mouse_pan;
static bool abs_mouse_dirty;
#endif

typedef enum {
    LED_MODE_OFF = 0,
    LED_MODE_ON,
    LED_MODE_BLINK,
} led_mode_t;

static led_mode_t led_mode = LED_MODE_OFF;

#if ENABLE_BRAILLE
// HID Braille output (cells written by host VoiceOver).
static uint8_t braille_cells[BRAILLE_CELL_COUNT];
static bool braille_dirty;
#if DEBUG
static volatile uint32_t braille_rx_count;
#endif

// HID Braille input (routing keys + dot keyboard + space) driven by MIDI ch=2.
static uint8_t braille_routing[BRAILLE_ROUTING_BYTES];
static uint8_t braille_dots; // bit0..bit7 = Dot 1..Dot 8
static bool braille_space_on;
static bool braille_input_dirty;
#endif

static void led_blink_task(void);
static void midi_task(void);
static void hid_task(void);
#if ENABLE_BRAILLE
static void braille_to_midi_task(void);
#endif

int main(void)
{
    board_init();

    // Drives the on-board status LED in a board-agnostic way: a plain GPIO LED
    // on the Raspberry Pi Pico, or the WS2812 RGB LED on boards like the
    // Waveshare RP2040-One. See pico/status_led.h.
    status_led_init();

    tusb_init();

    while (true) {
        tud_task();
        led_blink_task();
        midi_task();
        hid_task();
#if ENABLE_BRAILLE
        braille_to_midi_task();
#endif
    }
}

static void led_blink_task(void)
{
    static uint32_t last_ms = 0;
    static bool on = false;

    uint32_t now = board_millis();

#if DEBUG && ENABLE_BRAILLE
    // Toggle LED whenever a Braille Output Report arrives. Hold the new
    // state for 50 ms so individual events are still visible.
    static uint32_t last_braille_rx = 0;
    static uint32_t flash_end_ms = 0;

    uint32_t cur = braille_rx_count;
    if (cur != last_braille_rx) {
        last_braille_rx = cur;
        on = !on;
        status_led_set_state(on);
        flash_end_ms = now + 50;
        return;
    }
    if (now < flash_end_ms) {
        return;
    }
#endif

    switch (led_mode) {
    case LED_MODE_OFF:
        status_led_set_state(false);
        return;
    case LED_MODE_ON:
        status_led_set_state(true);
        return;
    case LED_MODE_BLINK:
        break;
    }

    if (now - last_ms < 500) {
        return;
    }
    last_ms = now;

    on = !on;
    status_led_set_state(on);
}

#if ENABLE_KEYBOARD
static void key_press(uint8_t k)
{
    for (int i = 0; i < 6; i++) {
        if (kbd_keys[i] == k) {
            return;
        }
    }
    for (int i = 0; i < 6; i++) {
        if (kbd_keys[i] == 0) {
            kbd_keys[i] = k;
            kbd_dirty = true;
            return;
        }
    }
}

static void key_release(uint8_t k)
{
    for (int i = 0; i < 6; i++) {
        if (kbd_keys[i] == k) {
            kbd_keys[i] = 0;
            kbd_dirty = true;
        }
    }
}
#endif

#if ENABLE_MOUSE || ENABLE_ABSOLUTE_MOUSE
static uint8_t mouse_button_for_note(uint8_t d1)
{
    switch (d1) {
    case 0:
        return MOUSE_BUTTON_LEFT;
    case 1:
        return MOUSE_BUTTON_RIGHT;
    case 2:
        return MOUSE_BUTTON_MIDDLE;
    case 3:
        return MOUSE_BUTTON_BACKWARD;
    case 4:
        return MOUSE_BUTTON_FORWARD;
    default:
        return 0;
    }
}
#endif

#if ENABLE_MOUSE || ENABLE_ABSOLUTE_MOUSE
static int8_t clamp_int8(int v)
{
    if (v > 127) {
        return 127;
    }
    if (v < -128) {
        return -128;
    }
    return (int8_t)v;
}
#endif

#if ENABLE_BRAILLE
static void braille_set_dot(uint8_t dot_index, bool on)
{
    uint8_t mask = (uint8_t)(1u << dot_index);
    if (on) {
        braille_dots |= mask;
    } else {
        braille_dots &= ~mask;
    }
    braille_input_dirty = true;
}

static void braille_set_routing(uint8_t index, bool on)
{
    if (index >= BRAILLE_CELL_COUNT) {
        return;
    }
    uint8_t mask = (uint8_t)(1u << (index % 8));
    if (on) {
        braille_routing[index / 8] |= mask;
    } else {
        braille_routing[index / 8] &= ~mask;
    }
    braille_input_dirty = true;
}
#endif

static void handle_midi_message(uint8_t status, uint8_t d1, uint8_t d2)
{
    uint8_t channel = status & 0x0F;
    uint8_t type = status & 0xF0;

    // Note On with velocity 0 is conventionally Note Off.
    if (type == 0x90 && d2 == 0) {
        type = 0x80;
    }

    bool note_on = (type == 0x90);
    bool note_off = (type == 0x80);
    bool cc = (type == 0xB0);

    switch (channel) {
#if ENABLE_KEYBOARD
    case MIDI_CH_KEYBOARD: {
        // HID Usage IDs 0x00..0x03 are reserved (ErrorRollOver etc.). Skip.
        if ((note_on || note_off) && d1 >= 0x04) {
            if (note_on) {
                key_press(d1);
            } else {
                key_release(d1);
            }
            return;
        }
        if (cc && d1 == 1) {
            kbd_modifiers = d2;
            kbd_dirty = true;
            return;
        }
        return;
    }
#endif

#if ENABLE_MOUSE
    case MIDI_CH_MOUSE: {
        if (note_on || note_off) {
            uint8_t btn = mouse_button_for_note(d1);
            if (!btn) {
                return;
            }
            if (note_on) {
                mouse_buttons |= btn;
            } else {
                mouse_buttons &= ~btn;
            }
            mouse_dirty = true;
            return;
        }
        if (cc) {
            int delta = (int)d2 - 64;
            switch (d1) {
            case 1:
                mouse_dx = clamp_int8((int)mouse_dx + delta);
                mouse_dirty = true;
                return;
            case 2:
                mouse_dy = clamp_int8((int)mouse_dy + delta);
                mouse_dirty = true;
                return;
            case 3:
                mouse_wheel_v = clamp_int8((int)mouse_wheel_v + delta);
                mouse_dirty = true;
                return;
            case 4:
                mouse_wheel_h = clamp_int8((int)mouse_wheel_h + delta);
                mouse_dirty = true;
                return;
            }
        }
        return;
    }
#endif

#if ENABLE_ABSOLUTE_MOUSE
    case MIDI_CH_ABS_MOUSE: {
        if (note_on || note_off) {
            uint8_t btn = mouse_button_for_note(d1);
            if (!btn) {
                return;
            }
            if (note_on) {
                abs_mouse_buttons |= btn;
            } else {
                abs_mouse_buttons &= ~btn;
            }
            // Report the button transition together with the current absolute
            // position so iOS sees the press at the cursor it already tracks.
            abs_mouse_dirty = true;
            return;
        }
        if (!cc) {
            return;
        }
        switch (d1) {
        case 0x01:
            abs_mouse_x_msb = d2 & 0x7F;
            return;
        case 0x02: {
            uint16_t v = ((uint16_t)abs_mouse_x_msb << 7) | (uint16_t)(d2 & 0x7F);
            if (v > ABS_MOUSE_LOGICAL_MAX) {
                v = ABS_MOUSE_LOGICAL_MAX;
            }
            abs_mouse_x = v;
            return;
        }
        case 0x03:
            abs_mouse_y_msb = d2 & 0x7F;
            return;
        case 0x04: {
            uint16_t v = ((uint16_t)abs_mouse_y_msb << 7) | (uint16_t)(d2 & 0x7F);
            if (v > ABS_MOUSE_LOGICAL_MAX) {
                v = ABS_MOUSE_LOGICAL_MAX;
            }
            abs_mouse_y = v;
            abs_mouse_dirty = true;
            return;
        }
        case 0x05:
            abs_mouse_wheel = clamp_int8((int)abs_mouse_wheel + ((int)d2 - 64));
            abs_mouse_dirty = true;
            return;
        case 0x06:
            abs_mouse_pan = clamp_int8((int)abs_mouse_pan + ((int)d2 - 64));
            abs_mouse_dirty = true;
            return;
        }
        return;
    }
#endif

#if ENABLE_BRAILLE
    case MIDI_CH_BRAILLE: {
        if (note_on || note_off) {
            bool on = note_on;
            if (d1 <= 7) {
                braille_set_dot(d1, on);
                return;
            }
            if (d1 == 8) {
                braille_space_on = on;
                braille_input_dirty = true;
                return;
            }
            if (d1 >= 16 && d1 < 16 + BRAILLE_CELL_COUNT) {
                braille_set_routing(d1 - 16, on);
                return;
            }
        }
        return;
    }
#endif

    case MIDI_CH_SYSTEM: {
        if (cc && d1 == 0) {
            if (d2 == 0) {
                led_mode = LED_MODE_OFF;
            } else if (d2 == 127) {
                led_mode = LED_MODE_ON;
            } else {
                led_mode = LED_MODE_BLINK;
            }
        }
        return;
    }
    }
}

static bool any_output_dirty(void)
{
    return false
#if ENABLE_KEYBOARD
        || kbd_dirty
#endif
#if ENABLE_MOUSE
        || mouse_dirty
#endif
#if ENABLE_ABSOLUTE_MOUSE
        || abs_mouse_dirty
#endif
#if ENABLE_BRAILLE
        || braille_input_dirty
#endif
        ;
}

static void midi_task(void)
{
    if (!tud_mounted()) {
        return;
    }
    // Don't pull new MIDI while a state change is still waiting on hid_task;
    // otherwise the next packet overwrites the pending state.
    if (any_output_dirty()) {
        return;
    }

    uint8_t pkt[4];
    while (tud_midi_packet_read(pkt)) {
        uint8_t cin = pkt[0] & 0x0F;
        // 3-byte channel voice messages: Note Off (0x8), Note On (0x9), Control
        // Change (0xB).
        if (cin == 0x8 || cin == 0x9 || cin == 0xB) {
            handle_midi_message(pkt[1], pkt[2], pkt[3]);
        }
        if (any_output_dirty()) {
            break;
        }
    }
}

#if ENABLE_BRAILLE
// Send the latest Braille cell snapshot to the host as a SysEx packet.
// Format: F0 7D 01 <count> [c0_low4 c0_high4 c1_low4 c1_high4 ...] F7
static void braille_to_midi_task(void)
{
    if (!braille_dirty) {
        return;
    }
    if (!tud_midi_mounted()) {
        return;
    }

    uint8_t buf[5 + BRAILLE_CELL_COUNT * 2];
    size_t i = 0;
    buf[i++] = 0xF0;
    buf[i++] = 0x7D;
    buf[i++] = 0x01; // sub-command: Braille update
    buf[i++] = BRAILLE_CELL_COUNT;
    for (size_t c = 0; c < BRAILLE_CELL_COUNT; c++) {
        buf[i++] = braille_cells[c] & 0x0F;
        buf[i++] = (braille_cells[c] >> 4) & 0x0F;
    }
    buf[i++] = 0xF7;

    if (tud_midi_stream_write(0, buf, i) == i) {
        braille_dirty = false;
    }
}
#endif

static void hid_task(void)
{
#if ENABLE_KEYBOARD
    if (kbd_dirty && tud_hid_n_ready(HID_INSTANCE_KEYBOARD)) {
        uint8_t kc[6] = { 0 };
        int j = 0;
        for (int i = 0; i < 6; i++) {
            if (kbd_keys[i]) {
                kc[j++] = kbd_keys[i];
            }
        }
        tud_hid_n_keyboard_report(HID_INSTANCE_KEYBOARD, 0, kbd_modifiers, kc);
        kbd_dirty = false;
    }
#endif

#if ENABLE_MOUSE
    if (mouse_dirty && tud_hid_n_ready(HID_INSTANCE_MOUSE)) {
        tud_hid_n_mouse_report(HID_INSTANCE_MOUSE, 0, mouse_buttons, mouse_dx,
            mouse_dy, mouse_wheel_v, mouse_wheel_h);
        mouse_dx = 0;
        mouse_dy = 0;
        mouse_wheel_v = 0;
        mouse_wheel_h = 0;
        mouse_dirty = false;
    }
#endif

#if ENABLE_ABSOLUTE_MOUSE
    if (abs_mouse_dirty && tud_hid_n_ready(HID_INSTANCE_ABS_MOUSE)) {
        uint8_t buf[7];
        buf[0] = abs_mouse_buttons;
        buf[1] = (uint8_t)(abs_mouse_x & 0xFF);
        buf[2] = (uint8_t)((abs_mouse_x >> 8) & 0xFF);
        buf[3] = (uint8_t)(abs_mouse_y & 0xFF);
        buf[4] = (uint8_t)((abs_mouse_y >> 8) & 0xFF);
        buf[5] = (uint8_t)abs_mouse_wheel;
        buf[6] = (uint8_t)abs_mouse_pan;
        tud_hid_n_report(HID_INSTANCE_ABS_MOUSE, 0, buf, sizeof(buf));
        abs_mouse_wheel = 0;
        abs_mouse_pan = 0;
        abs_mouse_dirty = false;
    }
#endif

#if ENABLE_BRAILLE
    if (braille_input_dirty && tud_hid_n_ready(HID_INSTANCE_BRAILLE)) {
        uint8_t buf[BRAILLE_INPUT_REPORT_SZ];
        memcpy(buf, braille_routing, BRAILLE_ROUTING_BYTES);
        buf[5] = braille_dots;
        buf[6] = braille_space_on ? 0x01 : 0x00;
        tud_hid_n_report(HID_INSTANCE_BRAILLE, REPORT_ID_BRAILLE, buf,
            BRAILLE_INPUT_REPORT_SZ);
        braille_input_dirty = false;
    }
#endif
}

#if CFG_TUD_HID > 0
uint16_t tud_hid_get_report_cb(uint8_t instance, uint8_t report_id,
    hid_report_type_t report_type, uint8_t *buffer,
    uint16_t reqlen)
{
#if ENABLE_BRAILLE
    if (instance == HID_INSTANCE_BRAILLE && report_id == REPORT_ID_BRAILLE) {
        if (report_type == HID_REPORT_TYPE_FEATURE && reqlen >= 1) {
            buffer[0] = BRAILLE_CELL_COUNT;
            return 1;
        }
        if (report_type == HID_REPORT_TYPE_INPUT && reqlen >= BRAILLE_INPUT_REPORT_SZ) {
            memset(buffer, 0, BRAILLE_INPUT_REPORT_SZ);
            return BRAILLE_INPUT_REPORT_SZ;
        }
    }
#else
    (void)instance;
    (void)report_id;
    (void)report_type;
    (void)buffer;
    (void)reqlen;
#endif
    return 0;
}

void tud_hid_set_report_cb(uint8_t instance, uint8_t report_id,
    hid_report_type_t report_type, uint8_t const *buffer,
    uint16_t bufsize)
{
#if ENABLE_BRAILLE
    if (instance == HID_INSTANCE_BRAILLE && report_id == REPORT_ID_BRAILLE && report_type == HID_REPORT_TYPE_OUTPUT) {
        size_t n = bufsize < BRAILLE_CELL_COUNT ? bufsize : BRAILLE_CELL_COUNT;
        memcpy(braille_cells, buffer, n);
        if (n < BRAILLE_CELL_COUNT) {
            memset(braille_cells + n, 0, BRAILLE_CELL_COUNT - n);
        }
        braille_dirty = true;
#if DEBUG
        braille_rx_count++;
#endif
    }
#else
    (void)instance;
    (void)report_id;
    (void)report_type;
    (void)buffer;
    (void)bufsize;
#endif
}
#endif
