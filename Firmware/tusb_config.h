#ifndef _TUSB_CONFIG_H_
#define _TUSB_CONFIG_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ENABLE_KEYBOARD
#define ENABLE_KEYBOARD 1
#endif
#ifndef ENABLE_MOUSE
#define ENABLE_MOUSE 1
#endif
#ifndef ENABLE_ABSOLUTE_MOUSE
#define ENABLE_ABSOLUTE_MOUSE 1
#endif
#ifndef ENABLE_BRAILLE
#define ENABLE_BRAILLE 1
#endif

#define CFG_TUSB_MCU OPT_MCU_RP2040
#define CFG_TUSB_OS OPT_OS_PICO

#define CFG_TUD_ENABLED 1
#define CFG_TUD_MAX_SPEED OPT_MODE_FULL_SPEED

// Legacy define required by tusb_init() when called without arguments.
#define CFG_TUSB_RHPORT0_MODE (OPT_MODE_DEVICE | OPT_MODE_FULL_SPEED)

#define CFG_TUSB_MEM_SECTION
#define CFG_TUSB_MEM_ALIGN __attribute__((aligned(4)))

#define CFG_TUD_ENDPOINT0_SIZE 64

#define CFG_TUD_CDC 0
#define CFG_TUD_MSC 0
#define CFG_TUD_HID ((ENABLE_KEYBOARD) + (ENABLE_MOUSE) + (ENABLE_ABSOLUTE_MOUSE) + (ENABLE_BRAILLE))
#define CFG_TUD_MIDI 1
#define CFG_TUD_VENDOR 0

// HID instance indices computed by packing enabled features in fixed order.
#if ENABLE_KEYBOARD
#define HID_INSTANCE_KEYBOARD 0
#endif
#if ENABLE_MOUSE
#define HID_INSTANCE_MOUSE ((ENABLE_KEYBOARD))
#endif
#if ENABLE_ABSOLUTE_MOUSE
#define HID_INSTANCE_ABS_MOUSE ((ENABLE_KEYBOARD) + (ENABLE_MOUSE))
#endif
#if ENABLE_BRAILLE
#define HID_INSTANCE_BRAILLE ((ENABLE_KEYBOARD) + (ENABLE_MOUSE) + (ENABLE_ABSOLUTE_MOUSE))
#endif

#define CFG_TUD_HID_EP_BUFSIZE 64

#define CFG_TUD_MIDI_RX_BUFSIZE 64
#define CFG_TUD_MIDI_TX_BUFSIZE 512

#ifdef __cplusplus
}
#endif

#endif
