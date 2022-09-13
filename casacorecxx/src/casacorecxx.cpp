#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

#include <casacore/casa/Utilities.h>
#include <casacore/tables/Tables.h>

using namespace casacore;

JLCXX_MODULE define_julia_module(jlcxx::Module &mod) {
    // Order matters: types must be declared before they are used (or returned),
    // or else Julia will error during load.
    #include "utilities.cpp"
    #include "arrays.cpp"
    #include "tables.cpp"
}