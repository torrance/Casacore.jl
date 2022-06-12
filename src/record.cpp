#include <casacore/casa/Containers/Record.h>
#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

using namespace casacore;

// CasacoreWrapper.Records
// These will basically be dictionaries and we should create
// metods in julia that serde from Julia dicts
JLCXX_MODULE define_module_record(jlcxx::Module &mod) {
  // Create the table object and it's constructors
  mod.add_type<Record>("Record");
}