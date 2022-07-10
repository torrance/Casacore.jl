#include <casacore/casa/Containers/Record.h>
#include <casacore/tables/Tables/TableProxy.h>
#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

using namespace casacore;

/* Following the Boost.Python implementation, we want to provide conversions for
 * all the fundamental CasaCore types */

/* This includes
- Bools, Ints, Floats, and Complex, String, Vector   -> What you'd expect
- Record                                             -> Dict
*/

JLCXX_MODULE define_julia_module(jlcxx::Module &mod) {
  // casacore Strings
  mod.add_type<String>("String").constructor<const std::string &>();

  // Record Field Ids
  mod.add_type<RecordFieldId>("RecordFieldId")
      // These can be either ints or strings
      .constructor<int>()
      .constructor<const String &>()
      .method("field_number", &RecordFieldId::fieldNumber)
      .method("field_name", &RecordFieldId::fieldName)
      .method("by_name", &RecordFieldId::byName);

  // Record description (Describes the structure of a record)
  mod.add_type<RecordDesc>("RecordDesc")
      .constructor<>()
      .method("add_field", &RecordDesc::addField);

  mod.add_type<Record>("Record")
      // Default constructor
      .constructor<>()
      // Methods
      .method("comment", &Record::comment)
      .method("set_comment", &Record::setComment);

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