# Shebang `${ORIGIN}` examples

Relocatable script shebangs for Nix using `${ORIGIN}/` in the interpreter path,
mirroring ELF `$ORIGIN` RPATH semantics.

A patched Linux kernel expands `${ORIGIN}/` at the start of a shebang to the
directory containing the script (symlinks resolved), so packages can reference
their interpreter by a path relative to their own location in the store rather
than an absolute store path. This means a package works at any store prefix —
not just `/nix/store` — as long as the relative layout between packages is
preserved.

## Patch

`relocatable-shebangs.patch` can be applied to any recent Linux kernel:

```sh
patch -p1 < relocatable-shebangs.patch
```

For NixOS, add it to `boot.kernelPatches`:

```nix
boot.kernelPatches = [{
  name = "relocatable-shebangs";
  patch = "${inputs.relocatable-shebangs}/relocatable-shebangs.patch";
}];
```

## Demo

The demo builds a small package with a `${ORIGIN}`-relative shebang, copies the
closure to `/store` (instead of `/nix/store`), and runs it under QEMU to verify
relocatability.

```sh
# First time setup
make deps        # Ubuntu/Debian; or: nix develop

# Build
make kernel      # patched kernel (slow, cached after first build)
make initramfs   # busybox + demo closure

# Run
make test        # QEMU: expects PASS: direct / PASS: symlink
make shell       # interactive QEMU shell

# Incremental kernel development (with your own kernel source tree)
make KERNEL_IMAGE=/path/to/arch/arm64/boot/Image test
```

## patchShebangs

`patch-shebangs.sh` is a modified version of nixpkgs' `patchShebangs` that
rewrites interpreter paths to `${ORIGIN}/`-relative form. Use it in a Nix
derivation:

```nix
dontPatchShebangs = true;
installPhase = ''
  source ${./patch-shebangs.sh}
  HOST_PATH=${interpreter}/bin patchShebangs --host $out/bin
'';
```
