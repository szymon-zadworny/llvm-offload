# llvm-offload

Upstream LLVM SYCL on liboffload for Intel GPUs.

## Development shell

```sh
nix develop github:szymon-zadworny/llvm-offload
clang++ -std=c++17 -fsycl app.cpp -o app
```

`sycl-ls` lists the available devices.

Your user needs access to `/dev/dri/renderD*`, usually through the `render` group.

## Use from another flake

```nix
{
  inputs.llvm-offload.url = "github:szymon-zadworny/llvm-offload";
  inputs.nixpkgs.follows = "llvm-offload/nixpkgs";

  outputs = { nixpkgs, llvm-offload, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      stdenv = pkgs.overrideCC pkgs.stdenv llvm-offload.packages.x86_64-linux.clang;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell.override { inherit stdenv; } { };
    };
}
```

## Building

LLVM isn't in the NixOS binary cache, so the first build compiles it. Limit parallelism on smaller machines:

```sh
nix build github:szymon-zadworny/llvm-offload --cores 8 --max-jobs 1
```

To update LLVM, run `nix flake update llvm-project` in a clone of this repository.
