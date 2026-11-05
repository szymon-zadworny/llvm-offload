{
  lib,
  stdenv,
  runCommand,
  wrapCC,
  cmake,
  ninja,
  python3,
  llvm-project,
  linkJobs ? 8,
}:

let
  versionCmake = builtins.readFile "${llvm-project}/cmake/Modules/LLVMVersion.cmake";
  versionPart =
    part: lib.head (builtins.match ".*set\\(LLVM_VERSION_${part} ([0-9]+)\\).*" versionCmake);
  llvmVersion = lib.concatMapStringsSep "." versionPart [
    "MAJOR"
    "MINOR"
    "PATCH"
  ];

  # The runtimes are built with the in-tree clang, which can't find the sandbox's libc on its own.
  inTreeClang = wrapCC (
    runCommand "in-tree-clang"
      {
        passthru = {
          isClang = true;
          langCC = true;
        };
      }
      ''
        mkdir -p $out/bin
        for tool in clang clang++; do
          printf '#!/bin/sh\nexec "$NIX_BUILD_TOP/source/build/bin/%s" "$@"\n' $tool > $out/bin/$tool
          chmod +x $out/bin/$tool
        done
      ''
  );
in

stdenv.mkDerivation {
  pname = "llvm-offload";
  version = "${llvmVersion}-unstable-${lib.substring 0 8 llvm-project.lastModifiedDate}";

  src = llvm-project;
  cmakeDir = "../llvm";

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];

  cmakeFlags = [
    (lib.cmakeFeature "LLVM_ENABLE_PROJECTS" "clang")
    (lib.cmakeFeature "LLVM_ENABLE_RUNTIMES" "offload;openmp;libsycl")
    (lib.cmakeFeature "LLVM_TARGETS_TO_BUILD" "X86;SPIRV")
    (lib.cmakeFeature "LIBOMPTARGET_PLUGINS_TO_BUILD" "level_zero")
    (lib.cmakeBool "CLANG_ENABLE_CIR" false)

    # The runtimes' lib/<triple>/ wouldn't match the wrapper's -target, so -fsycl couldn't find libsycl.
    (lib.cmakeBool "LLVM_ENABLE_PER_TARGET_RUNTIME_DIR" false)

    (lib.cmakeFeature "RUNTIMES_CMAKE_ARGS" (
      lib.concatStringsSep ";" [
        "-DCMAKE_C_COMPILER=${inTreeClang}/bin/clang"
        "-DCMAKE_CXX_COMPILER=${inTreeClang}/bin/clang++"
        "-DCMAKE_ASM_COMPILER=${inTreeClang}/bin/clang"
      ]
    ))

    (lib.cmakeBool "LLVM_LINK_LLVM_DYLIB" true)
    (lib.cmakeFeature "LLVM_PARALLEL_LINK_JOBS" (toString linkJobs))
  ];

  passthru = {
    isClang = true;
    langCC = true;
    # Rejected by the SPIR-V target, and -fsycl applies it to device code too.
    hardeningUnsupportedFlags = [ "zerocallusedregs" ];
  };

  meta = {
    description = "Upstream LLVM SYCL on liboffload for Intel GPUs";
    homepage = "https://github.com/llvm/llvm-project";
    license = lib.licenses.llvm-exception;
    mainProgram = "clang";
    platforms = [ "x86_64-linux" ];
  };
}
