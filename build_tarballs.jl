# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "jlcasacore"
version = v"0.0.1"

# Collection of sources required to complete build
sources = [GitSource("https://github.com/kiranshila/jlcasacore.git",
                     "7bf01222d93539578e10563d1172446ab8e12199")]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd CasacoreWrapper/
mkdir build && cd build
cmake \
    -DCMAKE_CXX_STANDARD_COMPUTED_DEFAULT=11 \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_FIND_ROOT_PATH=${prefix} \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DJulia_PREFIX=${prefix}\
    ..
VERBOSE=ON cmake --build . --config Release --target install -- -j${nproc}
exit
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [Platform("x86_64", "linux"; libc="glibc")]
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = Product[]

# Dependencies that must be installed before this package can be built
dependencies = [Dependency("libcxxwrap_julia_jll"),
                Dependency("casacore_jll"),
                BuildDependency("libjulia_jll")]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.7",
               preferred_gcc_version=v"9")
