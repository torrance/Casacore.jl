#include <casacore/casa/Containers/Record.h>
#include <casacore/tables/Tables/TableProxy.h>
#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

using namespace casacore;

// CasacoreWrapper.Tables
JLCXX_MODULE define_module_tables(jlcxx::Module &mod) {
  // Create the table object and it's constructors
  mod.add_type<TableProxy>("Table")
      // Default constructor
      .constructor<>()
      // Copy constructor
      .constructor<const TableProxy &>()
      // Table query command
      .constructor<const String &, const std::vector<TableProxy>>()
      // Open single table
      .constructor<const String &, const Record &, int>()
      .constructor<const String &, const Record &, const String &,
                   const String &, int, const Record &, const Record &>()
      // Methods
      .method("close", &TableProxy::close);

  // Allow vectors of TableProxys to be made
  jlcxx::stl::apply_stl<TableProxy *>(mod);
}