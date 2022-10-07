#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

#include <casacore/casa/Quanta.h>
#include <casacore/measures/Measures.h>
#include <casacore/measures/Measures/MCDirection.h>
#include <casacore/measures/Measures/MeasConvert.h>
#include <casacore/measures/Measures/MEpoch.h>
#include <casacore/measures/Measures/MDirection.h>
#include <casacore/measures/Measures/MPosition.h>

using namespace casacore;

JLCXX_MODULE define_module_mdirection(jlcxx::Module &mod) {
    mod.add_bits<MDirection::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("J2000", MDirection::J2000);
    mod.set_const("JMEAN", MDirection::JMEAN);
    mod.set_const("JTRUE", MDirection::JTRUE);
    mod.set_const("APP", MDirection::APP);
    mod.set_const("B1950", MDirection::B1950);
    mod.set_const("B1950_VLA", MDirection::B1950_VLA);
    mod.set_const("BMEAN", MDirection::BMEAN);
    mod.set_const("BTRUE", MDirection::BTRUE);
    mod.set_const("GALACTIC", MDirection::GALACTIC);
    mod.set_const("HADEC", MDirection::HADEC);
    mod.set_const("AZEL", MDirection::AZEL);
    mod.set_const("AZELSW", MDirection::AZELSW);
    mod.set_const("AZELGEO", MDirection::AZELGEO);
    mod.set_const("AZELSWGEO", MDirection::AZELSWGEO);
    mod.set_const("JNAT", MDirection::JNAT);
    mod.set_const("ECLIPTIC", MDirection::ECLIPTIC);
    mod.set_const("MECLIPTIC", MDirection::MECLIPTIC);
    mod.set_const("TECLIPTIC", MDirection::TECLIPTIC);
    mod.set_const("SUPERGAL", MDirection::SUPERGAL);
    mod.set_const("ITRF", MDirection::ITRF);
    mod.set_const("TOPO", MDirection::TOPO);
    mod.set_const("ICRS", MDirection::ICRS);
    mod.set_const("N_Types", MDirection::N_Types);
    mod.set_const("MERCURY", MDirection::MERCURY);
    mod.set_const("VENUS", MDirection::VENUS);
    mod.set_const("MARS", MDirection::MARS);
    mod.set_const("JUPITER", MDirection::JUPITER);
    mod.set_const("SATURN", MDirection::SATURN);
    mod.set_const("URANUS", MDirection::URANUS);
    mod.set_const("NEPTUNE", MDirection::NEPTUNE);
    mod.set_const("PLUTO", MDirection::PLUTO);
    mod.set_const("SUN", MDirection::SUN);
    mod.set_const("MOON", MDirection::MOON);
    mod.set_const("COMET", MDirection::COMET);
    mod.set_const("N_Planets", MDirection::N_Planets);
    mod.set_const("EXTRA", MDirection::EXTRA);
    mod.set_const("DEFAULT", MDirection::DEFAULT);
    mod.set_const("AZELNE", MDirection::AZELNE);
    mod.set_const("AZELNEGEO", MDirection::AZELNEGEO);
}

JLCXX_MODULE define_module_mepoch(jlcxx::Module &mod) {
    mod.add_bits<MEpoch::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("LAST", MEpoch::LAST);
    mod.set_const("LMST", MEpoch::LMST);
    mod.set_const("GMST1", MEpoch::GMST);
    mod.set_const("GAST", MEpoch::GAST);
    mod.set_const("UT1", MEpoch::UT1);
    mod.set_const("UT2", MEpoch::UT2);
    mod.set_const("UTC", MEpoch::UTC);
    mod.set_const("TAI", MEpoch::TAI);
    mod.set_const("TDT", MEpoch::TDT);
    mod.set_const("TCG", MEpoch::TCG);
    mod.set_const("TDB", MEpoch::TDB);
    mod.set_const("TCB", MEpoch::TCB);
    mod.set_const("N_Types", MEpoch::N_Types);
    mod.set_const("RAZE", MEpoch::RAZE );
    mod.set_const("EXTRA", MEpoch::EXTRA);
    mod.set_const("IAT", MEpoch::IAT);
    mod.set_const("GMST", MEpoch::GMST);
    mod.set_const("TT", MEpoch::TT);
    mod.set_const("UT", MEpoch::UT);
    mod.set_const("ET", MEpoch::ET);
    mod.set_const("DEFAULT", MEpoch::DEFAULT);
}

JLCXX_MODULE define_module_mposition(jlcxx::Module &mod) {
    mod.add_bits<MPosition::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("ITRF", MPosition::ITRF);
    mod.set_const("WGS84", MPosition::WGS84);
    mod.set_const("N_Types", MPosition::N_Types);
    mod.set_const("Default", MPosition::DEFAULT);
}