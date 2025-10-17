include build_scripts/config.mk

.PHONY: all floppy_image kernel bootloader clear always tools_fat
all: floppy_image tools_fat

include build_scripts/toolchain.mk

#
# Floppy Image
#
floppy_image: $(BUILD_DIR)/main_floppy.img tools_fat

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	
	mkfs.fat -F 12 -n "WIZOS" $(BUILD_DIR)/main_floppy.img

	dd if=$(BUILD_DIR)/stage1.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc

	mcopy -i $(BUILD_DIR)/main_floppy.img  $(BUILD_DIR)/stage2.bin "::stage2.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img  $(BUILD_DIR)/kernel.bin "::kernel.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img  test.txt "::test.txt"
	mmd -i $(BUILD_DIR)/main_floppy.img "::mydir"
	mcopy -i $(BUILD_DIR)/main_floppy.img test.txt "::mydir/test.txt"
	mcopy -i $(BUILD_DIR)/main_floppy.img bigText.txt "::mydir/bigText.txt"
	

#
# Bootloader
#
bootloader: stage1 stage2

stage1: $(BUILD_DIR)/stage1.bin
$(BUILD_DIR)/stage1.bin: always
	$(MAKE) -C src/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR))

stage2: $(BUILD_DIR)/stage2.bin
$(BUILD_DIR)/stage2.bin: always
	$(MAKE) -C src/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR))

#
# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: always
	$(MAKE) -C src/kernel BUILD_DIR=$(abspath $(BUILD_DIR))

# 
# Tools
#
tools_fat: $(BUILD_DIR)/tools/fat
$(BUILD_DIR)/tools/fat: always tools/fat/fat.c
	mkdir -p $(BUILD_DIR)/tools/fat
	$(MAKE) -C tools/fat BUILD_DIR=$(abspath $(BUILD_DIR))

BOCHS_DBG = /mnt/c/Program\ Files/Bochs-2.8/bochsdbg.exe
BOCHSRC = bochs

# Run bochs with gui debugger
debug: floppy_image
	$(BOCHS_DBG) -q -f bochs_config


always: 
	mkdir -p $(BUILD_DIR)

clean: 
	$(MAKE) -C src/kernel BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C src/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C src/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	rm -rf $(BUILD_DIR)/*