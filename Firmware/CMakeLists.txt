cmake_minimum_required(VERSION 3.17)

include(pico_sdk_import.cmake)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

project(firmware)

option(ENABLE_KEYBOARD       "Enable USB HID Keyboard"                ON)
option(ENABLE_MOUSE          "Enable USB HID Mouse"                   OFF)
option(ENABLE_ABSOLUTE_MOUSE "Enable USB HID Absolute Mouse"          ON)
option(ENABLE_BRAILLE        "Enable USB HID Braille Display"         OFF)

pico_sdk_init()

add_executable(firmware
    main.c
    usb_descriptors.c
)

target_include_directories(firmware PRIVATE ${CMAKE_CURRENT_LIST_DIR})

target_compile_definitions(firmware PRIVATE
    ENABLE_KEYBOARD=$<BOOL:${ENABLE_KEYBOARD}>
    ENABLE_MOUSE=$<BOOL:${ENABLE_MOUSE}>
    ENABLE_ABSOLUTE_MOUSE=$<BOOL:${ENABLE_ABSOLUTE_MOUSE}>
    ENABLE_BRAILLE=$<BOOL:${ENABLE_BRAILLE}>

    # Dim the colored (WS2812) status LED used on boards like the RP2040-One.
    PICO_DEFAULT_COLORED_STATUS_LED_ON_COLOR=0x00080808
)

target_link_libraries(firmware
    pico_stdlib
    pico_unique_id
    pico_status_led
    tinyusb_device
    tinyusb_board
)

pico_add_extra_outputs(firmware)
