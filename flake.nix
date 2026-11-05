{
  description = "Upstream LLVM SYCL on liboffload for Intel GPUs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llvm-project = {
      url = "github:llvm/llvm-project/main";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, llvm-project, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      llvm-offload = pkgs.callPackage ./nix/llvm-offload.nix { inherit llvm-project; };

      clang = pkgs.wrapCCWith {
        cc = llvm-offload;

        # -fsycl passes -mtls-dialect on to the SPIR-V device compile, which rejects it.
        # liboffload dlopen()s the Level Zero loader, and the loader needs nixpkgs' GPU driver.
        extraBuildCommands = ''
          substituteInPlace $out/nix-support/add-local-cc-cflags-before.sh \
            --replace-fail " '-mtls-dialect=gnu2'" ""

          cat >> $out/nix-support/setup-hook <<'EOF'
          export LD_LIBRARY_PATH="${pkgs.lib.getLib pkgs.level-zero}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          export ZE_ENABLE_ALT_DRIVERS="${pkgs.intel-compute-runtime}/lib/libze_intel_gpu.so.1"
          EOF
        '';
      };
    in
    {
      packages.${system} = {
        default = llvm-offload;
        inherit llvm-offload clang;
      };

      devShells.${system}.default = pkgs.mkShell.override {
        stdenv = pkgs.overrideCC pkgs.stdenv clang;
      } { };
    };
}
