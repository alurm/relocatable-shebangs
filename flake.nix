{
  description = "Example of relocatable shebangs using \${ORIGIN} with a patched Linux kernel";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      busybox = pkgs.pkgsStatic.busybox;

      kernel = pkgs.linux.override {
        kernelPatches = [{
          name = "relocatable-shebangs";
          patch = ./relocatable-shebangs.patch;
        }];
      };

      demo = pkgs.stdenv.mkDerivation {
        name = "relocatable-shebangs-demo";
        src = ./demo;
        dontPatchShebangs = true;
        installPhase = ''
          mkdir -p $out/libexec $out/bin
          install -m755 $src/hello.sh $out/libexec/hello.sh
          ln -s ../libexec/hello.sh $out/bin/hello
          source ${./patch-shebangs.sh}
          HOST_PATH=${busybox}/bin patchShebangs --host $out/libexec
        '';
      };

      # Packages live at /store rather than /nix/store to demonstrate relocatability
      storeRoot = "/store";

      initramfs = pkgs.stdenv.mkDerivation {
        name = "relocatable-shebangs-initramfs";
        nativeBuildInputs = [ pkgs.cpio pkgs.gzip ];
        exportReferencesGraph = [ "closure" demo ];
        buildCommand = ''
          root=$TMPDIR/root
          mkdir -p $root/{bin,dev,proc,sys,root,${storeRoot}}

          cp ${busybox}/bin/busybox $root/bin/busybox
          for cmd in sh mount poweroff echo cat ls; do
            ln -s busybox $root/bin/$cmd
          done

          grep -E '^/nix/store/' closure | while read p; do
            dest=$root/${storeRoot}/$(basename $p)
            [ -e $dest ] && continue
            cp -r $p $dest
            chmod -R u+w $dest
          done

          cat > $root/init <<EOF
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
${storeRoot}/$(basename ${demo})/libexec/hello.sh && echo "PASS: direct"   || echo "FAIL: direct"
${storeRoot}/$(basename ${demo})/bin/hello         && echo "PASS: symlink"  || echo "FAIL: symlink"
echo o > /proc/sysrq-trigger
EOF
          chmod +x $root/init

          (cd $root && find . -print0 | sort -z | cpio --null -o -H newc | gzip) > $out
        '';
      };

      # Kernel build deps for incremental development.
      # Usage: nix develop, then make -C ../linux -j$(nproc)
      devShell = pkgs.mkShell {
        packages = with pkgs; [
          gnumake gcc binutils flex bison bc perl python3
          openssl elfutils pahole
          qemu
        ];
      };

    in {
      packages.${system} = { inherit demo initramfs kernel; default = initramfs; };
      devShells.${system}.default = devShell;
    };
}
