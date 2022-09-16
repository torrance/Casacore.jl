#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

#include <casacore/casa/Utilities.h>
#include <casacore/tables/Tables.h>

using namespace casacore;

namespace jlcxx {
    template<> struct SuperType<ScalarColumnDesc<Bool>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Char>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<uChar>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Short>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<uShort>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Int>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<uInt>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Int64>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Float>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Double>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<Complex>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<DComplex>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ScalarColumnDesc<String>> { typedef BaseColumnDesc type; };

    template<> struct SuperType<ArrayColumnDesc<Bool>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Char>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<uChar>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Short>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<uShort>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Int>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<uInt>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Int64>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Float>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Double>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<Complex>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<DComplex>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<ArrayColumnDesc<String>> { typedef BaseColumnDesc type; };
}

JLCXX_MODULE define_julia_module(jlcxx::Module &mod) {
    // Order matters: types must be declared before they are used (or returned),
    // or else Julia will error during load.
    #include "utilities.cpp"
    #include "arrays.cpp"
    #include "tables.cpp"
}