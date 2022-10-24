#include <jlcxx/jlcxx.hpp>

#include <casacore/measures/Measures/MBaseline.h>
#include <casacore/measures/Measures/MDirection.h>
#include <casacore/measures/Measures/MDoppler.h>
#include <casacore/measures/Measures/MEarthMagnetic.h>
#include <casacore/measures/Measures/MEpoch.h>
#include <casacore/measures/Measures/MFrequency.h>
#include <casacore/measures/Measures/MPosition.h>
#include <casacore/measures/Measures/MRadialVelocity.h>
#include <casacore/measures/Measures/Muvw.h>
#include <casacore/tables/Tables/Table.h>

using namespace casacore;

JLCXX_MODULE define_module_mbaseline(jlcxx::Module &mod) {
    mod.add_bits<MBaseline::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("J2000", MBaseline::J2000);
    mod.set_const("JMEAN", MBaseline::JMEAN);
    mod.set_const("JTRUE", MBaseline::JTRUE);
    mod.set_const("APP", MBaseline::APP);
    mod.set_const("B1950", MBaseline::B1950);
    mod.set_const("B1950_VLA", MBaseline::B1950_VLA);
    mod.set_const("BMEAN", MBaseline::BMEAN);
    mod.set_const("BTRUE", MBaseline::BTRUE);
    mod.set_const("GALACTIC", MBaseline::GALACTIC);
    mod.set_const("HADEC", MBaseline::HADEC);
    mod.set_const("AZEL", MBaseline::AZEL);
    mod.set_const("AZELSW", MBaseline::AZELSW);
    mod.set_const("AZELGEO", MBaseline::AZELGEO);
    mod.set_const("AZELSWGEO", MBaseline::AZELSWGEO);
    mod.set_const("JNAT", MBaseline::JNAT);
    mod.set_const("ECLIPTIC", MBaseline::ECLIPTIC);
    mod.set_const("MECLIPTIC", MBaseline::MECLIPTIC);
    mod.set_const("TECLIPTIC", MBaseline::TECLIPTIC);
    mod.set_const("SUPERGAL", MBaseline::SUPERGAL);
    mod.set_const("ITRF", MBaseline::ITRF);
    mod.set_const("TOPO", MBaseline::TOPO);
    mod.set_const("ICRS", MBaseline::ICRS);
    mod.set_const("N_Types", MBaseline::N_Types);
    mod.set_const("DEFAULT", MBaseline::DEFAULT);
    mod.set_const("AZELNE", MBaseline::AZELNE);
    mod.set_const("AZELNEGEO", MBaseline::AZELNEGEO);
}

JLCXX_MODULE define_module_mdoppler(jlcxx::Module &mod) {
    mod.add_bits<MDoppler::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("RADIO", MDoppler::RADIO);
    mod.set_const("Z", MDoppler::Z);
    mod.set_const("RATIO", MDoppler::RATIO);
    mod.set_const("BETA", MDoppler::BETA);
    mod.set_const("GAMMA", MDoppler::GAMMA);
    mod.set_const("N_Types", MDoppler::N_Types);
    mod.set_const("OPTICAL", MDoppler::OPTICAL);
    mod.set_const("RELATIVISTIC", MDoppler::RELATIVISTIC);
    mod.set_const("DEFAULT", MDoppler::DEFAULT);
}

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

JLCXX_MODULE define_module_mearthmagnetic(jlcxx::Module &mod) {
    mod.add_bits<MEarthMagnetic::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("J2000", MEarthMagnetic::J2000);
    mod.set_const("JMEAN", MEarthMagnetic::JMEAN);
    mod.set_const("JTRUE", MEarthMagnetic::JTRUE);
    mod.set_const("APP", MEarthMagnetic::APP);
    mod.set_const("B1950", MEarthMagnetic::B1950);
    mod.set_const("BMEAN", MEarthMagnetic::BMEAN);
    mod.set_const("BTRUE", MEarthMagnetic::BTRUE);
    mod.set_const("GALACTIC", MEarthMagnetic::GALACTIC);
    mod.set_const("HADEC", MEarthMagnetic::HADEC);
    mod.set_const("AZEL", MEarthMagnetic::AZEL);
    mod.set_const("AZELSW", MEarthMagnetic::AZELSW);
    mod.set_const("AZELGEO", MEarthMagnetic::AZELGEO);
    mod.set_const("AZELSWGEO", MEarthMagnetic::AZELSWGEO);
    mod.set_const("JNAT", MEarthMagnetic::JNAT);
    mod.set_const("ECLIPTIC", MEarthMagnetic::ECLIPTIC);
    mod.set_const("MECLIPTIC", MEarthMagnetic::MECLIPTIC);
    mod.set_const("TECLIPTIC", MEarthMagnetic::TECLIPTIC);
    mod.set_const("SUPERGAL", MEarthMagnetic::SUPERGAL);
    mod.set_const("ITRF", MEarthMagnetic::ITRF);
    mod.set_const("TOPO", MEarthMagnetic::TOPO);
    mod.set_const("ICRS", MEarthMagnetic::ICRS);
    mod.set_const("N_Types", MEarthMagnetic::N_Types);
    mod.set_const("IGRF", MEarthMagnetic::IGRF);
    mod.set_const("N_Models", MEarthMagnetic::N_Models);
    mod.set_const("EXTRA", MEarthMagnetic::EXTRA);
    mod.set_const("DEFAULT", MEarthMagnetic::DEFAULT);
    mod.set_const("AZELNE", MEarthMagnetic::AZELNE);
    mod.set_const("AZELNEGEO", MEarthMagnetic::AZELNEGEO);
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

JLCXX_MODULE define_module_mfrequency(jlcxx::Module &mod) {
    mod.add_bits<MFrequency::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("REST", MFrequency::REST);
    mod.set_const("LSRK", MFrequency::LSRK);
    mod.set_const("LSRD", MFrequency::LSRD);
    mod.set_const("BARY", MFrequency::BARY);
    mod.set_const("GEO", MFrequency::GEO);
    mod.set_const("TOPO", MFrequency::TOPO);
    mod.set_const("GALACTO", MFrequency::GALACTO);
    mod.set_const("LGROUP", MFrequency::LGROUP);
    mod.set_const("CMB", MFrequency::CMB);
    mod.set_const("N_Types", MFrequency::N_Types);
    mod.set_const("Undefined", MFrequency::Undefined);
    mod.set_const("N_Other", MFrequency::N_Other);
    mod.set_const("EXTRA", MFrequency::EXTRA);
    mod.set_const("DEFAULT", MFrequency::DEFAULT);
    mod.set_const("LSR", MFrequency::LSR);
}

JLCXX_MODULE define_module_mposition(jlcxx::Module &mod) {
    mod.add_bits<MPosition::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("ITRF", MPosition::ITRF);
    mod.set_const("WGS84", MPosition::WGS84);
    mod.set_const("N_Types", MPosition::N_Types);
    mod.set_const("DEFAULT", MPosition::DEFAULT);
}

JLCXX_MODULE define_module_mradialvelocity(jlcxx::Module &mod) {
    mod.add_bits<MRadialVelocity::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("LSRK", MRadialVelocity::LSRK);
    mod.set_const("LSRD", MRadialVelocity::LSRD);
    mod.set_const("BARY", MRadialVelocity::BARY);
    mod.set_const("GEO", MRadialVelocity::GEO);
    mod.set_const("TOPO", MRadialVelocity::TOPO);
    mod.set_const("GALACTO", MRadialVelocity::GALACTO);
    mod.set_const("LGROUP", MRadialVelocity::LGROUP);
    mod.set_const("CMB", MRadialVelocity::CMB);
    mod.set_const("N_Types", MRadialVelocity::N_Types);
    mod.set_const("DEFAULT", MRadialVelocity::DEFAULT);
    mod.set_const("LSR", MRadialVelocity::LSR);
}

JLCXX_MODULE define_module_muvw(jlcxx::Module &mod) {
    mod.add_bits<Muvw::Types>("Types", jlcxx::julia_type("CppEnum"));
    mod.set_const("J2000", Muvw::J2000);
    mod.set_const("JMEAN", Muvw::JMEAN);
    mod.set_const("JTRUE", Muvw::JTRUE);
    mod.set_const("APP", Muvw::APP);
    mod.set_const("B1950", Muvw::B1950);
    mod.set_const("B1950_VLA", Muvw::B1950_VLA);
    mod.set_const("BMEAN", Muvw::BMEAN);
    mod.set_const("BTRUE", Muvw::BTRUE);
    mod.set_const("GALACTIC", Muvw::GALACTIC);
    mod.set_const("HADEC", Muvw::HADEC);
    mod.set_const("AZEL", Muvw::AZEL);
    mod.set_const("AZELSW", Muvw::AZELSW);
    mod.set_const("AZELGEO", Muvw::AZELGEO);
    mod.set_const("AZELSWGEO", Muvw::AZELSWGEO);
    mod.set_const("JNAT", Muvw::JNAT);
    mod.set_const("ECLIPTIC", Muvw::ECLIPTIC);
    mod.set_const("MECLIPTIC", Muvw::MECLIPTIC);
    mod.set_const("TECLIPTIC", Muvw::TECLIPTIC);
    mod.set_const("SUPERGAL", Muvw::SUPERGAL);
    mod.set_const("ITRF", Muvw::ITRF);
    mod.set_const("TOPO", Muvw::TOPO);
    mod.set_const("ICRS", Muvw::ICRS);
    mod.set_const("N_Types", Muvw::N_Types);
    mod.set_const("DEFAULT", Muvw::DEFAULT);
    mod.set_const("AZELNE ", Muvw::AZELNE );
    mod.set_const("AZELNEGEO", Muvw::AZELNEGEO);
}