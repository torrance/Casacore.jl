# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "casacorecxx"
version = v"0.3.0"

# Collection of sources required to complete build
sources = [DirectorySource("casacorecxx")]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
mkdir build && cd build
cmake \
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
platforms = [Platform("x86_64", "linux"; libc="glibc", julia_version="1.8")]
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = Product[LibraryProduct("libcasacorecxx", :libcasacorecxx),]

# Dependencies that must be installed before this package can be built
dependencies = [Dependency("libcxxwrap_julia_jll", compat="0.11.2"),
                Dependency("casacore_jll", compat="3.5.1"),
                BuildDependency("libjulia_jll")]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.8",
               preferred_gcc_version=v"7") # We need C++17 for CxxWrap
