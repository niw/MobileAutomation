.DEFAULT_GOAL := build

# Target board. Defaults to the Raspberry Pi Pico. For the Waveshare
# RP2040-One use `make build BOARD=waveshare_rp2040_one`. Each board gets its
# own build directory so their CMake caches don't clobber each other.
BOARD ?= pico

BUILD_TYPE ?= Debug
BUILD_DIR ?= cmake-build-$(shell echo $(BUILD_TYPE) | tr '[:upper:]' '[:lower:]')

.PHONY: clean
clean:
	$(RM) -r $(BUILD_DIR)

.PHONY: format
format:
	clang-format -i *.{c,h}

$(BUILD_DIR):
	cmake -B $@ -G Ninja -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) -DPICO_BOARD=$(BOARD)

.PHONY: build
build: $(BUILD_DIR)
	cmake --build $<

.PHONY: write
write:
	@if [[ -d /Volumes/RPI-RP2 ]]; then \
		cp $(BUILD_DIR)/firmware.uf2 /Volumes/RPI-RP2; \
	else \
		echo "Please put the board in BOOTSEL mode and try again."; \
		exit 1; \
	fi
