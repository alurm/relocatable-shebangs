.PHONY: help
# Boilerplate for make help.
help: # Show available targets.
	@ grep -E "^[^$$(printf \\t)#]+:.*# " Makefile \
	| column -s '#' -t

# Path to the kernel Image.
# Incremental dev (inside nix develop or with deps installed):
#   make -C ../linux -j$(nproc)
#   make KERNEL_IMAGE=../linux/arch/arm64/boot/Image test
# Reproducible build:
#   make kernel
#   make test
KERNEL_IMAGE ?= result-kernel/Image

QEMU = qemu-system-aarch64 \
    -M virt -cpu cortex-a72 -m 512 -nographic \
    -kernel $(KERNEL_IMAGE) \
    -initrd $$(readlink -f initramfs.cpio.gz)

.PHONY: kernel
kernel: # Build the patched kernel via Nix (slow, reproducible).
	nix build .#kernel -o result-kernel

.PHONY: initramfs
initramfs: # Build the initramfs (busybox + demo closure).
	nix build .#initramfs -o initramfs.cpio.gz

.PHONY: test
test: # Launch QEMU and run tests.
	$(QEMU) -append "console=ttyAMA0 rdinit=/init panic=1" -no-reboot

.PHONY: shell
shell: # Launch QEMU with an interactive shell.
	$(QEMU) -append "console=ttyAMA0 rdinit=/bin/sh panic=1" -no-reboot

.PHONY: deps
deps: # Install kernel build deps and QEMU (Ubuntu/Debian). Nix: use `nix develop` instead.
	sudo apt install -y build-essential flex bison bc libssl-dev libelf-dev \
	    dwarves pahole qemu-system-arm
