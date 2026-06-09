#include <stdio.h>
#include <string.h>

#include "pico/unique_id.h"
#include "tusb.h"

#define USB_VID 0xCAFE
#define USB_PID 0x4001
#define USB_BCD 0x0200

tusb_desc_device_t const desc_device = {
    .bLength = sizeof(tusb_desc_device_t),
    .bDescriptorType = TUSB_DESC_DEVICE,
    .bcdUSB = USB_BCD,

    // Use IAD for composite device.
    .bDeviceClass = TUSB_CLASS_MISC,
    .bDeviceSubClass = MISC_SUBCLASS_COMMON,
    .bDeviceProtocol = MISC_PROTOCOL_IAD,

    .bMaxPacketSize0 = CFG_TUD_ENDPOINT0_SIZE,

    .idVendor = USB_VID,
    .idProduct = USB_PID,
    .bcdDevice = 0x0100,

    .iManufacturer = 0x01,
    .iProduct = 0x02,
    .iSerialNumber = 0x03,

    .bNumConfigurations = 0x01,
};

uint8_t const *tud_descriptor_device_cb(void)
{
    return (uint8_t const *)&desc_device;
}

#if ENABLE_KEYBOARD
uint8_t const desc_keyboard_report[] = { TUD_HID_REPORT_DESC_KEYBOARD() };
#endif

#if ENABLE_MOUSE
uint8_t const desc_mouse_report[] = { TUD_HID_REPORT_DESC_MOUSE() };
#endif

#if ENABLE_ABSOLUTE_MOUSE
// Absolute-positioning mouse. iOS applies pointer acceleration to relative
// pointers; absolute X/Y are mapped directly so the cursor jumps to the
// reported coordinate without acceleration or sensitivity scaling.
//
// Logical range 0..16383 (14-bit). Pairs neatly with two 7-bit MIDI CC
// bytes per axis on the host side. Click events from MIDI ch 0 are routed
// through this interface so the down/up transitions arrive at the same
// HID device that owns the visible cursor position.
//
// clang-format reflows comma-separated byte initializers, so the report
// descriptors below are aligned by hand and fenced with clang-format off/on.
// clang-format off
uint8_t const desc_abs_mouse_report[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x02,        // Usage (Mouse)
    0xA1, 0x01,        // Collection (Application)
    0x09, 0x01,        //   Usage (Pointer)
    0xA1, 0x00,        //   Collection (Physical)

    // Buttons 1..5.
    0x05, 0x09,        //     Usage Page (Button)
    0x19, 0x01,        //     Usage Minimum (1)
    0x29, 0x05,        //     Usage Maximum (5)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x01,        //     Logical Maximum (1)
    0x95, 0x05,        //     Report Count (5)
    0x75, 0x01,        //     Report Size (1)
    0x81, 0x02,        //     Input (Data, Var, Abs)
    0x95, 0x01,        //     Report Count (1)
    0x75, 0x03,        //     Report Size (3)
    0x81, 0x03,        //     Input (Const, Var, Abs) — padding to byte

    // Absolute X / Y (0..16383, 16-bit field).
    0x05, 0x01,        //     Usage Page (Generic Desktop)
    0x09, 0x30,        //     Usage (X)
    0x15, 0x00,        //     Logical Minimum (0)
    0x26, 0xFF, 0x3F,  //     Logical Maximum (16383)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Var, Abs)
    0x09, 0x31,        //     Usage (Y)
    0x81, 0x02,        //     Input (Data, Var, Abs)

    // Wheel + horizontal pan (relative deltas, same as the relative mouse).
    0x09, 0x38,        //     Usage (Wheel)
    0x15, 0x81,        //     Logical Minimum (-127)
    0x25, 0x7F,        //     Logical Maximum (127)
    0x95, 0x01,        //     Report Count (1)
    0x75, 0x08,        //     Report Size (8)
    0x81, 0x06,        //     Input (Data, Var, Rel)
    0x05, 0x0C,        //     Usage Page (Consumer)
    0x0A, 0x38, 0x02,  //     Usage (AC Pan)
    0x15, 0x81,        //     Logical Minimum (-127)
    0x25, 0x7F,        //     Logical Maximum (127)
    0x95, 0x01,        //     Report Count (1)
    0x75, 0x08,        //     Report Size (8)
    0x81, 0x06,        //     Input (Data, Var, Rel)

    0xC0,              //   End Collection
    0xC0,              // End Collection
};
// clang-format on
#endif

#if ENABLE_BRAILLE
#define BRAILLE_CELL_COUNT 40

// HID Usage Page 0x41 (Braille Display), Report ID 3 for all three reports
// (Feature: Number of Cells, Output: cell data, Input: routing keys).
// clang-format off
uint8_t const desc_braille_report[] = {
    0x05, 0x41,        // Usage Page (Braille Display)
    0x09, 0x01,        // Usage (Braille Display)
    0xA1, 0x01,        // Collection (Application)

    0x85, 0x03,        //   Report ID (3)

    // Feature: Number of Cells.
    0x09, 0x05,        //   Usage (Number of Braille Cells)
    0x15, 0x00,        //   Logical Minimum (0)
    0x26, 0xFF, 0x00,  //   Logical Maximum (255)
    0x75, 0x08,        //   Report Size (8)
    0x95, 0x01,        //   Report Count (1)
    0xB1, 0x02,        //   Feature (Data, Var, Abs)

    // Output: cell data.
    0x09, 0x02,        //   Usage (Braille Row)
    0xA1, 0x02,        //   Collection (Logical)
    0x09, 0x03,        //     Usage (8 Dot Braille Cell)
    0x15, 0x00,        //     Logical Minimum (0)
    0x26, 0xFF, 0x00,  //     Logical Maximum (255)
    0x75, 0x08,        //     Report Size (8)
    0x95, BRAILLE_CELL_COUNT, // Report Count (40)
    0x91, 0x02,        //     Output (Data, Var, Abs)
    0xC0,              //   End Collection

    // Input: routing keys (40 bits, byte aligned).
    0x09, 0x08,        //   Usage (Router Set 1)
    0xA1, 0x02,        //   Collection (Logical)
    0x0A, 0x00, 0x01,  //     Usage (Router Key, 0x100)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x01,        //     Logical Maximum (1)
    0x75, 0x01,        //     Report Size (1)
    0x95, BRAILLE_CELL_COUNT, // Report Count (40)
    0x81, 0x02,        //     Input (Data, Var, Abs)
    0xC0,              //   End Collection

    // Input: Braille keyboard (Dot 1-8 + Space).
    0x0A, 0x00, 0x02,  //   Usage (Braille Buttons, 0x200)
    0xA1, 0x02,        //   Collection (Logical)
    0x0A, 0x01, 0x02,  //     Usage (Keyboard Dot 1)
    0x0A, 0x02, 0x02,  //     Usage (Keyboard Dot 2)
    0x0A, 0x03, 0x02,  //     Usage (Keyboard Dot 3)
    0x0A, 0x04, 0x02,  //     Usage (Keyboard Dot 4)
    0x0A, 0x05, 0x02,  //     Usage (Keyboard Dot 5)
    0x0A, 0x06, 0x02,  //     Usage (Keyboard Dot 6)
    0x0A, 0x07, 0x02,  //     Usage (Keyboard Dot 7)
    0x0A, 0x08, 0x02,  //     Usage (Keyboard Dot 8)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x01,        //     Logical Maximum (1)
    0x75, 0x01,        //     Report Size (1)
    0x95, 0x08,        //     Report Count (8)
    0x81, 0x02,        //     Input (Data, Var, Abs) — 8 dot bits
    0x0A, 0x09, 0x02,  //     Usage (Keyboard Space)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Var, Abs) — 1 space bit
    0x75, 0x07,        //     Report Size (7)
    0x81, 0x03,        //     Input (Const, Var, Abs) — 7 padding bits
    0xC0,              //   End Collection

    0xC0,              // End Collection
};
// clang-format on
#endif

uint8_t const *tud_hid_descriptor_report_cb(uint8_t instance)
{
#if ENABLE_KEYBOARD
    if (instance == HID_INSTANCE_KEYBOARD) {
        return desc_keyboard_report;
    }
#endif
#if ENABLE_MOUSE
    if (instance == HID_INSTANCE_MOUSE) {
        return desc_mouse_report;
    }
#endif
#if ENABLE_ABSOLUTE_MOUSE
    if (instance == HID_INSTANCE_ABS_MOUSE) {
        return desc_abs_mouse_report;
    }
#endif
#if ENABLE_BRAILLE
    if (instance == HID_INSTANCE_BRAILLE) {
        return desc_braille_report;
    }
#endif
    return NULL;
}

// Interface numbers: MIDI is always first; enabled HID interfaces follow in
// the fixed order Keyboard → Mouse → Absolute Mouse → Braille.
enum {
    ITF_NUM_MIDI = 0,
    ITF_NUM_MIDI_STREAMING,
#if ENABLE_KEYBOARD
    ITF_NUM_HID_KEYBOARD,
#endif
#if ENABLE_MOUSE
    ITF_NUM_HID_MOUSE,
#endif
#if ENABLE_ABSOLUTE_MOUSE
    ITF_NUM_HID_ABS_MOUSE,
#endif
#if ENABLE_BRAILLE
    ITF_NUM_HID_BRAILLE,
#endif
    ITF_NUM_TOTAL,
};

// Endpoint numbers (raw, direction bit added at descriptor site).
#define EPNUM_MIDI 0x01
#define _EPNUM_HID_BASE 0x02

#if ENABLE_KEYBOARD
#define EPNUM_HID_KEYBOARD (_EPNUM_HID_BASE + (HID_INSTANCE_KEYBOARD))
#endif
#if ENABLE_MOUSE
#define EPNUM_HID_MOUSE (_EPNUM_HID_BASE + (HID_INSTANCE_MOUSE))
#endif
#if ENABLE_ABSOLUTE_MOUSE
#define EPNUM_HID_ABS_MOUSE (_EPNUM_HID_BASE + (HID_INSTANCE_ABS_MOUSE))
#endif
#if ENABLE_BRAILLE
#define EPNUM_HID_BRAILLE (_EPNUM_HID_BASE + (HID_INSTANCE_BRAILLE))
#endif

#define CONFIG_TOTAL_LEN \
    (TUD_CONFIG_DESC_LEN + TUD_MIDI_DESC_LEN + (ENABLE_KEYBOARD) * TUD_HID_DESC_LEN + (ENABLE_MOUSE) * TUD_HID_DESC_LEN + (ENABLE_ABSOLUTE_MOUSE) * TUD_HID_DESC_LEN + (ENABLE_BRAILLE) * TUD_HID_DESC_LEN)

uint8_t const desc_configuration[] = {
    TUD_CONFIG_DESCRIPTOR(1, ITF_NUM_TOTAL, 0, CONFIG_TOTAL_LEN, 0x00, 100),

    TUD_MIDI_DESCRIPTOR(ITF_NUM_MIDI, 0, EPNUM_MIDI, 0x80 | EPNUM_MIDI, 64),

#if ENABLE_KEYBOARD
    TUD_HID_DESCRIPTOR(ITF_NUM_HID_KEYBOARD, 0, HID_ITF_PROTOCOL_NONE,
        sizeof(desc_keyboard_report), 0x80 | EPNUM_HID_KEYBOARD,
        CFG_TUD_HID_EP_BUFSIZE, 10),
#endif

#if ENABLE_MOUSE
    TUD_HID_DESCRIPTOR(ITF_NUM_HID_MOUSE, 0, HID_ITF_PROTOCOL_NONE,
        sizeof(desc_mouse_report), 0x80 | EPNUM_HID_MOUSE,
        CFG_TUD_HID_EP_BUFSIZE, 10),
#endif

#if ENABLE_ABSOLUTE_MOUSE
    TUD_HID_DESCRIPTOR(ITF_NUM_HID_ABS_MOUSE, 0, HID_ITF_PROTOCOL_NONE,
        sizeof(desc_abs_mouse_report),
        0x80 | EPNUM_HID_ABS_MOUSE, CFG_TUD_HID_EP_BUFSIZE, 10),
#endif

#if ENABLE_BRAILLE
    // Braille: IN endpoint only; SET_REPORT (cell data) comes via control
    // transfer.
    TUD_HID_DESCRIPTOR(ITF_NUM_HID_BRAILLE, 0, HID_ITF_PROTOCOL_NONE,
        sizeof(desc_braille_report), 0x80 | EPNUM_HID_BRAILLE,
        CFG_TUD_HID_EP_BUFSIZE, 10),
#endif
};

uint8_t const *tud_descriptor_configuration_cb(uint8_t index)
{
    (void)index;
    return desc_configuration;
}

enum {
    STRID_LANGID = 0,
    STRID_MANUFACTURER,
    STRID_PRODUCT,
    STRID_SERIAL,
};

char const *string_desc_arr[] = {
    (const char[]) { 0x09, 0x04 }, // 0: supported language (English, US)
    "Raspberry Pi", // 1: Manufacturer
    "Pico Controller", // 2: Product
    NULL, // 3: Serial (filled from chip ID)
};

static uint16_t _desc_str[32 + 1];

uint16_t const *tud_descriptor_string_cb(uint8_t index, uint16_t langid)
{
    (void)langid;

    size_t chr_count = 0;

    switch (index) {
    case STRID_LANGID:
        memcpy(&_desc_str[1], string_desc_arr[STRID_LANGID], 2);
        chr_count = 1;
        break;

    case STRID_SERIAL: {
        pico_unique_board_id_t board_id;
        pico_get_unique_board_id(&board_id);
        char serial[2 * sizeof(board_id.id) + 1];
        for (size_t i = 0; i < sizeof(board_id.id); i++) {
            snprintf(serial + 2 * i, 3, "%02X", board_id.id[i]);
        }
        chr_count = strlen(serial);
        if (chr_count > 32) {
            chr_count = 32;
        }
        for (size_t i = 0; i < chr_count; i++) {
            _desc_str[1 + i] = serial[i];
        }
        break;
    }

    default:
        if (index >= sizeof(string_desc_arr) / sizeof(string_desc_arr[0])) {
            return NULL;
        }
        const char *str = string_desc_arr[index];
        chr_count = strlen(str);
        if (chr_count > 32) {
            chr_count = 32;
        }
        for (size_t i = 0; i < chr_count; i++) {
            _desc_str[1 + i] = str[i];
        }
        break;
    }

    _desc_str[0] = (uint16_t)((TUSB_DESC_STRING << 8) | (2 * chr_count + 2));
    return _desc_str;
}
