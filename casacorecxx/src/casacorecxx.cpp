#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

#include <casacore/casa/Utilities.h>
#include <casacore/tables/Tables.h>
#include <casacore/tables/TaQL.h>

using namespace casacore;

// Define super types to allow upcasting, which in turn allows class hierarchies
namespace jlcxx {
    template<typename T> struct SuperType<ScalarColumnDesc<T>> { typedef BaseColumnDesc type; };
    template<typename T> struct SuperType<ArrayColumnDesc<T>> { typedef BaseColumnDesc type; };
}

JLCXX_MODULE define_julia_module(jlcxx::Module &mod) {
    // Order matters: types must be declared before they are used (or returned),
    // or else Julia will error during load.

    /*
     * UTILITIES
     */

    mod.add_bits<DataType>("DataType", jlcxx::julia_type("CppEnum"));
    mod.set_const("TpBool", TpBool);
    mod.set_const("TpChar", TpChar);
    mod.set_const("TpUChar", TpUChar);
    mod.set_const("TpShort", TpShort);
    mod.set_const("TpUShort", TpUShort);
    mod.set_const("TpInt", TpInt);
    mod.set_const("TpUInt", TpUInt);
    mod.set_const("TpFloat", TpFloat);
    mod.set_const("TpDouble", TpDouble);
    mod.set_const("TpComplex", TpComplex);
    mod.set_const("TpDComplex", TpDComplex);
    mod.set_const("TpString", TpString);
    mod.set_const("TpTable", TpTable);
    mod.set_const("TpArrayBool", TpArrayBool);
    mod.set_const("TpArrayChar", TpArrayChar);
    mod.set_const("TpArrayUChar", TpArrayUChar);
    mod.set_const("TpArrayShort", TpArrayShort);
    mod.set_const("TpArrayUShort", TpArrayUShort);
    mod.set_const("TpArrayInt", TpArrayInt);
    mod.set_const("TpArrayUInt", TpArrayUInt);
    mod.set_const("TpArrayFloat", TpArrayFloat);
    mod.set_const("TpArrayDouble", TpArrayDouble);
    mod.set_const("TpArrayComplex", TpArrayComplex);
    mod.set_const("TpArrayDComplex", TpArrayDComplex);
    mod.set_const("TpArrayString", TpArrayString);
    mod.set_const("TpRecord", TpRecord);
    mod.set_const("TpOther", TpOther);
    mod.set_const("TpQuantity", TpQuantity);
    mod.set_const("TpArrayQuantity", TpArrayQuantity);
    mod.set_const("TpInt64", TpInt64);
    mod.set_const("TpArrayInt64", TpArrayInt64);
    // mod.set_const("TpNumberOfType", TpNumberOfType);

    mod.add_type<String>("String")
        .constructor<const std::string &>()
        .method("c_str", &String::c_str);

    /*
     * ARRAYS
     */

    mod.add_type<IPosition>("IPosition")
        .constructor<size_t>()
        .constructor<size_t, ssize_t>()
        .constructor<size_t, ssize_t, ssize_t>()
        .constructor<size_t, ssize_t, ssize_t, ssize_t>()
        .constructor<size_t, ssize_t, ssize_t, ssize_t, ssize_t>()
        .method("size", &IPosition::size)
        .method("getindex", static_cast<ssize_t (IPosition::*)(size_t) const>(&IPosition::operator[]));

    mod.add_bits<Slicer::LengthOrLast>("LengthOrLast", jlcxx::julia_type("CppEnum"));
    mod.set_const("endIsLength", Slicer::endIsLength);
    mod.set_const("endIsLast", Slicer::endIsLast);

    mod.add_type<Slicer>("Slicer")
        .constructor<const IPosition &, const IPosition &, const IPosition &, Slicer::LengthOrLast>();

    mod.add_bits<StorageInitPolicy>("StorageInitPolicy", jlcxx::julia_type("CppEnum"));
    mod.set_const("COPY", COPY);
    mod.set_const("TAKE_OVER", TAKE_OVER);
    mod.set_const("SHARE", SHARE);

    mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("Vector")
        .apply<
            Vector<Bool>,
            Vector<Char>,
            Vector<uChar>,
            Vector<Short>,
            Vector<uShort>,
            Vector<Int>,
            Vector<uInt>,
            Vector<Int64>,
            Vector<Float>,
            Vector<Double>,
            Vector<Complex>,
            Vector<DComplex>,
            Vector<String>
        >([](auto wrapped) {
            typedef typename decltype(wrapped)::type WrappedT;
            typedef typename WrappedT::value_type T;
            wrapped.template constructor();
            wrapped.template constructor<const IPosition &>();
            wrapped.template constructor<const IPosition &, T*, StorageInitPolicy>();
            wrapped.method("shape", &Array<T>::shape);
            wrapped.method("getindex", static_cast<const T & (WrappedT::*)(size_t) const >(&WrappedT::operator[]));
            wrapped.method("tovector", static_cast<std::vector<T> (WrappedT::*)(void) const>(&Array<T>::tovector));
            wrapped.method("getStorage", static_cast<const T * (WrappedT::*)(bool &) const>(&WrappedT::getStorage));
            wrapped.method("freeStorage", &WrappedT::freeStorage);
        });

    mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("Array")
        .apply<
            Array<Bool>,
            Array<Char>,
            Array<uChar>,
            Array<Short>,
            Array<uShort>,
            Array<Int>,
            Array<uInt>,
            Array<Int64>,
            Array<Float>,
            Array<Double>,
            Array<Complex>,
            Array<DComplex>,
            Array<String>
        >([](auto wrapped) {
            typedef typename decltype(wrapped)::type WrappedT;
            typedef typename WrappedT::value_type T;
            wrapped.template constructor();
            wrapped.template constructor<const IPosition &>();
            wrapped.template constructor<const IPosition &, T*, StorageInitPolicy>();
            wrapped.method("shape", &WrappedT::shape);
            wrapped.method("getindex", static_cast<WrappedT (WrappedT::*)(size_t) const >(&WrappedT::operator[]));
            wrapped.method("getindex", static_cast<const T & (WrappedT::*)(const IPosition &) const>(&WrappedT::operator()));
            wrapped.method("tovector", static_cast<std::vector<T> (WrappedT::*)(void) const>(&WrappedT::tovector));
            wrapped.method("getStorage", static_cast<const T * (WrappedT::*)(bool &) const>(&WrappedT::getStorage));
            wrapped.method("freeStorage", &WrappedT::freeStorage);
        });


mod.add_bits<ColumnDesc::Option>("ColumnOption");
mod.set_const("ColumnDirect", ColumnDesc::Direct);
mod.set_const("ColumnUndefined", ColumnDesc::Undefined);
mod.set_const("ColumnFixedShape", ColumnDesc::FixedShape);

mod.add_type<BaseColumnDesc>("BaseColumnDesc");

mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("ScalarColumnDesc", jlcxx::julia_base_type<BaseColumnDesc>())
    .apply<
        ScalarColumnDesc<Bool>,
        ScalarColumnDesc<Char>,
        ScalarColumnDesc<uChar>,
        ScalarColumnDesc<Short>,
        ScalarColumnDesc<uShort>,
        ScalarColumnDesc<Int>,
        ScalarColumnDesc<uInt>,
        ScalarColumnDesc<Int64>,
        ScalarColumnDesc<Float>,
        ScalarColumnDesc<Double>,
        ScalarColumnDesc<Complex>,
        ScalarColumnDesc<DComplex>,
        ScalarColumnDesc<String>
    >([](auto wrapped) {
        typedef typename decltype(wrapped)::type WrappedT;
        wrapped.template constructor<const String &, int>();
        wrapped.template constructor<const String &, const String &, int>();
        wrapped.method("setDefault", &WrappedT::setDefault);
    });

mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("ArrayColumnDesc", jlcxx::julia_base_type<BaseColumnDesc>())
    .apply<
        ArrayColumnDesc<Bool>,
        ArrayColumnDesc<Char>,
        ArrayColumnDesc<uChar>,
        ArrayColumnDesc<Short>,
        ArrayColumnDesc<uShort>,
        ArrayColumnDesc<Int>,
        ArrayColumnDesc<uInt>,
        ArrayColumnDesc<Int64>,
        ArrayColumnDesc<Float>,
        ArrayColumnDesc<Double>,
        ArrayColumnDesc<Complex>,
        ArrayColumnDesc<DComplex>,
        ArrayColumnDesc<String>
    >([](auto wrapped) {
        wrapped.template constructor<const String &, Int, int>();
        wrapped.template constructor<const String &, const String &, Int, int>();
        wrapped.template constructor<const String &, const IPosition &, int>();
        wrapped.template constructor<const String &, const String &, const IPosition &, int>();
    });

    /*
     * TABLES
     */

    mod.add_type<ColumnDesc>("ColumnDesc")
        .constructor()
        .constructor<const BaseColumnDesc &>()
        .method("name", &ColumnDesc::name)
        .method("dataType", &ColumnDesc::dataType)
        .method("trueDataType", &ColumnDesc::trueDataType)
        .method("shape", &ColumnDesc::shape)
        .method("ndim", &ColumnDesc::ndim)
        .method("isArray", &ColumnDesc::isArray)
        .method("isScalar", &ColumnDesc::isScalar)
        .method("isFixedShape", &ColumnDesc::isFixedShape);

    mod.add_type<ColumnDescSet>("ColumnDescSet")
        .method("getindex", static_cast<const ColumnDesc & (ColumnDescSet::*)(uInt) const>(&ColumnDescSet::operator[]))
        .method("ncolumn", &ColumnDescSet::ncolumn);

    mod.add_type<RecordFieldId>("RecordFieldId")
        .constructor<String &>()
        .constructor<Int>();

    mod.add_type<TableRecord>("TableRecord")
        .method("name", &TableRecord::name)
        .method("type", &TableRecord::type)
        .method("size", &TableRecord::size);

    mod.add_type<TSMOption>("TSMOption");

    mod.add_type<TableLock>("TableLock")
        .constructor<const TableLock &>();

    mod.add_bits<Table::TableOption>("TableOption", jlcxx::julia_type("CppEnum"));
    mod.set_const("Old", Table::Old);
    mod.set_const("New", Table::New);
    mod.set_const("NewNoReplace", Table::NewNoReplace);
    mod.set_const("Scratch", Table::Scratch);
    mod.set_const("Update", Table::Update);
    mod.set_const("Delete", Table::Delete);

    mod.add_type<TableDesc>("TableDesc")
        .constructor()
        .method("columnNames", &TableDesc::columnNames)
        .method("ncolumn", &TableDesc::ncolumn)
        .method("columnDesc", static_cast<const ColumnDesc & (TableDesc::*)(const String &) const>(&TableDesc::columnDesc))
        .method("columnDescSet", &TableDesc::columnDescSet);

    mod.add_type<Table>("Table")
        .constructor()
        .constructor<const Table &>()
        .constructor<const String &>()
        .constructor<const String &, Table::TableOption>()
        .constructor<const String &, Table::TableOption, const TSMOption &>()
        .constructor<const String &, const TableLock &, Table::TableOption, const TSMOption &>()
        .method("nrow", &Table::nrow)
        .method("tableDesc", &Table::tableDesc)
        .method("flush", &Table::flush)
        .method("addColumn", static_cast<void (Table::*)(const ColumnDesc &, Bool)>(&Table::addColumn))
        .method("removeColumn", static_cast<void (Table::*)(const String &)>(&Table::removeColumn))
        .method("keywordSet", &Table::keywordSet);

    // Add TableRecord::asTable here, due to dependency on Table
    mod.method("asTable", [](const TableRecord & rec, const RecordFieldId & id) {
        return rec.asTable(id);
    });

    mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("ScalarColumn")
        .apply<
            ScalarColumn<Bool>,
            ScalarColumn<Char>,
            ScalarColumn<uChar>,
            ScalarColumn<Short>,
            ScalarColumn<uShort>,
            ScalarColumn<Int>,
            ScalarColumn<uInt>,
            ScalarColumn<Int64>,
            ScalarColumn<Float>,
            ScalarColumn<Double>,
            ScalarColumn<Complex>,
            ScalarColumn<DComplex>,
            ScalarColumn<String>
        >([](auto wrapped) {
            typedef typename decltype(wrapped)::type WrappedT;
            typedef typename decltype( std::declval<WrappedT>().getColumn() )::value_type T;
            wrapped.template constructor();
            wrapped.template constructor<const Table &, const String &>();
            wrapped.method("nrow", &TableColumn::nrow);
            wrapped.method("shapeColumn", &TableColumn::shapeColumn);
            wrapped.method("getindex", &WrappedT::operator());
            wrapped.method("put", static_cast<void (WrappedT::*)(rownr_t, const T &)>(&WrappedT::put));
            wrapped.method("getColumn", [](const WrappedT & wrappedT) { return wrappedT.getColumn(); });
            wrapped.method(
                "getColumnRange",
                static_cast<Vector<T> (WrappedT::*)(const Slicer &) const>(&WrappedT::getColumnRange)
            );
            wrapped.method(
                "getColumnRange",
                static_cast<void (WrappedT::*)(const Slicer &, Vector<T> &, Bool) const>(&WrappedT::getColumnRange)
            );
            wrapped.method(
                "putColumnRange",
                static_cast<void (WrappedT::*)(const Slicer &, const Vector<T> &)>(&WrappedT::putColumnRange)
            );
        });

    mod.add_type<jlcxx::Parametric<jlcxx::TypeVar<1>>>("ArrayColumn")
        .apply<
            ArrayColumn<Bool>,
            ArrayColumn<Char>,
            ArrayColumn<uChar>,
            ArrayColumn<Short>,
            ArrayColumn<uShort>,
            ArrayColumn<Int>,
            ArrayColumn<uInt>,
            ArrayColumn<Int64>,
            ArrayColumn<Float>,
            ArrayColumn<Double>,
            ArrayColumn<Complex>,
            ArrayColumn<DComplex>,
            ArrayColumn<String>
        >([](auto wrapped) {
            typedef typename decltype(wrapped)::type WrappedT;
            typedef typename decltype( std::declval<WrappedT>().getColumn() )::value_type T;
            wrapped.template constructor();
            wrapped.template constructor<const Table &, const String &>();
            wrapped.method("nrow", &TableColumn::nrow);
            wrapped.method("ndim", &WrappedT::ndim);
            wrapped.method("isDefined", &TableColumn::isDefined);
            wrapped.method("shape", &WrappedT::shape);
            wrapped.method("shapeColumn", &TableColumn::shapeColumn);
            wrapped.method("get", static_cast<Array<T> (WrappedT::*)(rownr_t) const>(&WrappedT::get));
            wrapped.method("get", static_cast<void (WrappedT::*)(rownr_t, Array<T> &, Bool) const>(&WrappedT::get));
            wrapped.method("getColumn", [](const WrappedT & wrappedT) { return wrappedT.getColumn(); });
            wrapped.method(
                "getColumnRange",
                static_cast<Array<T> (WrappedT::*)(const Slicer &, const Slicer &) const>(&WrappedT::getColumnRange)
            );
            wrapped.method(
                "getColumnRange",
                static_cast<void (WrappedT::*)(const Slicer &, const Slicer &, Array<T> &, Bool) const>(&WrappedT::getColumnRange)
            );
            wrapped.method("put", static_cast<void (WrappedT::*)(rownr_t, const Array<T> &)>(&WrappedT::put));
            wrapped.method(
                "putColumnRange",
                static_cast<void (WrappedT::*)(const Slicer &, const Slicer &, const Array<T> &)>(&WrappedT::putColumnRange)
            );
        });

    mod.method("tableCommand", [](std::string command, std::vector<const Table*> tables) -> Table {
        return Table(tableCommand(String(command),  tables));
    });
}