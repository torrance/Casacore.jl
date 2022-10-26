#include <jlcxx/jlcxx.hpp>
#include <jlcxx/stl.hpp>

#include <casacore/casa/Quanta.h>
#include <casacore/casa/System/AppState.h>
#include <casacore/casa/Utilities.h>
#include <casacore/measures/Measures.h>
#include <casacore/measures/Measures/MCBaseline.h>
#include <casacore/measures/Measures/MCDirection.h>
#include <casacore/measures/Measures/MCDoppler.h>
#include <casacore/measures/Measures/MCEarthMagnetic.h>
#include <casacore/measures/Measures/MCEpoch.h>
#include <casacore/measures/Measures/MCFrequency.h>
#include <casacore/measures/Measures/MCPosition.h>
#include <casacore/measures/Measures/MCRadialVelocity.h>
#include <casacore/measures/Measures/MCuvw.h>
#include <casacore/measures/Measures/MeasConvert.h>
#include <casacore/measures/Measures/MBaseline.h>
#include <casacore/measures/Measures/MDirection.h>
#include <casacore/measures/Measures/MDoppler.h>
#include <casacore/measures/Measures/MEarthMagnetic.h>
#include <casacore/measures/Measures/MEpoch.h>
#include <casacore/measures/Measures/MFrequency.h>
#include <casacore/measures/Measures/MPosition.h>
#include <casacore/measures/Measures/MRadialVelocity.h>
#include <casacore/measures/Measures/Muvw.h>
#include <casacore/tables/Tables.h>
#include <casacore/tables/TaQL.h>

using namespace casacore;

class JuliaState: public AppState {
public:
    JuliaState(std::string measuresDir) : _measuresDir(measuresDir) {}

    std::string measuresDir() const {
        return _measuresDir;
    }

    bool initialized() const {
        return true;
    }

private:
    std::string _measuresDir;
};

// This function is called repeatedly when adding Measures.
// We add measures by their base names rather than as parametric types of Measure class.
// This is due to circular type dependencies in signatures that cause errors in Julia.
template<typename T, typename TV>
void addmeasure(jlcxx::Module & mod, std::string mname) {
    mod.template add_bits<typename T::Types>(mname + "!Types", jlcxx::julia_type("CppEnum"));

    mod.template add_type<typename T::Ref>(mname + "!Ref")
        .template constructor<const typename T::Types, const MeasFrame &>();

    mod.template add_type<T>(mname, jlcxx::julia_base_type<Measure>())
        .template constructor<const T &>()  // copy()
        .template constructor<const TV &>()
        .template constructor<const TV &, typename T::Types>()
        .template constructor<const TV &, const typename T::Ref &>()
        .method("setOffset", &T::setOffset)
        .method("getValue", &T::getValue)
        .method("getRef", &T::getRef)
        .method("getRefString", &T::getRefString)
        .method("tellMe", &T::tellMe)
        .method("set", static_cast<void (T::*)(const TV &)>(&T::set))
        .method("getValue", [](T & m, size_t i) {
            // This is a cheeky convenience method that avoids allocations in Julia.
            return m.getValue().getVector()[i];
        });

    mod.template add_type<typename T::Convert>(mname + "!Convert")
        .template constructor<const T &, const typename T::Ref &>()
        .template constructor<typename T::Types, const typename T::Ref &>()
        .template constructor<const typename T::Ref &, const typename T::Ref &>()
        .method(static_cast<const T & (T::Convert::*)(void)>(&T::Convert::operator()))
        .method(static_cast<const T & (T::Convert::*)(const T &)>(&T::Convert::operator()))
        .method(static_cast<const T & (T::Convert::*)(const TV &)>(&T::Convert::operator()))
        .method(static_cast<const T & (T::Convert::*)(const Vector<Double> &)>(&T::Convert::operator()))
        .method("setModel", &T::Convert::setModel)
        .method("setOut", static_cast<void (T::Convert::*)(const typename T::Ref &)>(&T::Convert::setOut))
        .method("convert!", [](typename T::Convert & c, T & min, T & mout) {
            mout.set(c(min.getValue()).getValue());
        });

    // Add T::Ref::set() here as we need T to have been defined
    mod.method("set", [](typename T::Ref & ref, const T & offset){
        return ref.set(offset);
    });

    // Add a modified putVector to avoid temporary Julia allocations of IPosition and Vector
    mod.method("putVector", [](TV & mv, double * ptr, ssize_t length) {
        IPosition ipos{length};
        Vector<double> vec{ipos, ptr, SHARE};
        mv.putVector(vec);
    });
}

// Define super types to allow upcasting, which in turn allows class hierarchies
namespace jlcxx {
    template<> struct SuperType<JuliaState> { typedef AppState type; };
    template<typename T> struct SuperType<ScalarColumnDesc<T>> { typedef BaseColumnDesc type; };
    template<typename T> struct SuperType<ArrayColumnDesc<T>> { typedef BaseColumnDesc type; };
    template<> struct SuperType<MBaseline> { typedef Measure type; };
    template<> struct SuperType<MDirection> { typedef Measure type; };
    template<> struct SuperType<MDoppler> { typedef Measure type; };
    template<> struct SuperType<MEarthMagnetic> { typedef Measure type; };
    template<> struct SuperType<MEpoch> { typedef Measure type; };
    template<> struct SuperType<MFrequency> { typedef Measure type; };
    template<> struct SuperType<MPosition> { typedef Measure type; };
    template<> struct SuperType<MRadialVelocity> { typedef Measure type; };
    template<> struct SuperType<Muvw> { typedef Measure type; };
}

JLCXX_MODULE define_julia_module(jlcxx::Module &mod) {
    // Order matters: types must be declared before they are used (or returned),
    // or else Julia will error during load.

    /**
     * CONFIG
     */

    mod.add_type<AppState>("AppState");

    mod.add_type<JuliaState>("JuliaState", jlcxx::julia_base_type<AppState>())
        .constructor<std::string>();

    mod.add_type<AppStateSource>("AppStateSource")
        .method("initialize", &AppStateSource::initialize);

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
            Vector<String>,
            Vector<rownr_t> // used in RowNumbers constructor
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

    /*
     * TABLES
     */

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
            wrapped.template constructor<const String &, const String &, const String &, const String &>();
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
            typedef typename decltype(wrapped)::type WrappedT;

            wrapped.template constructor<const String &, Int, int>();
            wrapped.template constructor<const String &, const String &, Int, int>();
            wrapped.template constructor<const String &, const IPosition &, int>();
            wrapped.template constructor<const String &, const String &, const IPosition &, int>();
            // Non-fixed shape
            wrapped.template constructor<const String &, const String &, const String &, const String &, int>();
            // Fixed shape
            wrapped.template constructor<const String &, const String &, const String &, const String &, const IPosition &>();

        });

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

    mod.add_type<RowNumbers>("RowNumbers")
        .constructor<const Vector<rownr_t> &>();

    mod.add_type<TableRecord>("TableRecord")
        .method("name", &TableRecord::name)
        .method("type", &TableRecord::type)
        .method("size", &TableRecord::size)
        .method("fieldNumber", &TableRecord::fieldNumber);

    mod.add_type<TSMOption>("TSMOption");

    mod.add_bits<Table::TableOption>("TableOption", jlcxx::julia_type("CppEnum"));

    mod.add_type<TableLock>("TableLock")
        .constructor<const TableLock &>();

    mod.add_bits<Table::TableType>("TableType", jlcxx::julia_type("CppEnum"));
    mod.set_const("Plain", Table::Plain);
    mod.set_const("Memory", Table::Memory);

    mod.add_type<TableDesc>("TableDesc")
        .constructor()
        .method("columnNames", &TableDesc::columnNames)
        .method("ncolumn", &TableDesc::ncolumn)
        .method("columnDesc", static_cast<const ColumnDesc & (TableDesc::*)(const String &) const>(&TableDesc::columnDesc))
        .method("columnDescSet", &TableDesc::columnDescSet);

    mod.add_type<Table>("Table")
        .constructor()
        .constructor<const Table &>() // copy
        .constructor<Table::TableType>()
        .constructor<const String &>()
        .constructor<const String &, Table::TableOption>()
        .constructor<const String &, Table::TableOption, const TSMOption &>()
        .constructor<const String &, const TableLock &, Table::TableOption, const TSMOption &>()
        .method("reopenRW", &Table::reopenRW)
        .method("rename", &Table::rename)
        .method("nrow", &Table::nrow)
        .method("tableName", &Table::tableName)
        .method("tableDesc", &Table::tableDesc)
        .method("flush", &Table::flush)
        .method("unlock", &Table::unlock)
        .method("addColumn", static_cast<void (Table::*)(const ColumnDesc &, Bool)>(&Table::addColumn))
        .method("removeColumn", static_cast<void (Table::*)(const String &)>(&Table::removeColumn))
        .method("addRow", &Table::addRow)
        .method("removeRow", static_cast<void (Table::*)(rownr_t)>(&Table::removeRow))
        .method("removeRow", static_cast<void (Table::*)(const RowNumbers &)>(&Table::removeRow))
        .method("keywordSet", &Table::keywordSet)
        .method("rwKeywordSet", &Table::rwKeywordSet)
        .method("deepCopy", [](const Table & table, const String & name, Table::TableOption opt) {
            return table.deepCopy(name, opt);
        });

    // Add TableRecord methods that have dependencies on Table
    mod.method("asTable", [](const TableRecord & rec, const RecordFieldId & id) {
        return rec.asTable(id);
    });
    mod.method("defineTable", [](TableRecord& rec, const RecordFieldId& id, const Table& table) {
        return rec.defineTable(id, table);
    });

    mod.method("deleteSubTable", &TableUtil::deleteSubTable);

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
            wrapped.method("fillColumn", &WrappedT::fillColumn);
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
            wrapped.method("putColumn", static_cast<void (WrappedT::*)(const Vector<T> &)>(&WrappedT::putColumn));
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
            wrapped.method("ndimColumn", &TableColumn::ndimColumn);
            wrapped.method("isDefined", &TableColumn::isDefined);
            wrapped.method("shape", &WrappedT::shape);
            wrapped.method("shapeColumn", &TableColumn::shapeColumn);
            wrapped.method("fillColumn", &WrappedT::fillColumn);
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
            wrapped.method("putColumn", static_cast<void (WrappedT::*)(const Array<T> &)>(&WrappedT::putColumn));
            wrapped.method(
                "putColumnRange",
                static_cast<void (WrappedT::*)(const Slicer &, const Slicer &, const Array<T> &)>(&WrappedT::putColumnRange)
            );
        });

    mod.method("tableCommand", [](std::string command, std::vector<const Table*> tables) -> Table {
        return Table(tableCommand(String(command),  tables));
    });

    /**
     * MEASURES
     */

    mod.add_type<Unit>("Unit")
        .constructor<String>();

    mod.add_type<Quantity>("Quantity")
        .constructor<Double, String>()
        .constructor<Double, Unit>()
        .method("qconvert", static_cast<void (Quantity::*)(const Unit &)>(&Quantity::convert))
        .method("getValue", static_cast<double & (Quantity::*)(void)>(&Quantity::getValue));

    mod.add_type<Measure>("Measure");

    mod.add_type<MeasFrame>("MeasFrame")
        .constructor()
        .constructor<const Measure &>()
        .constructor<const Measure &, const Measure &>()
        .constructor<const Measure &, const Measure &, const Measure &>();

    mod.add_type<MVBaseline>("MVBaseline")
        .constructor<double, double, double>() // Units: m
        .method("getValue", static_cast<const Vector<double> & (MVBaseline::*)(void) const>(&MVBaseline::getValue))
        .method("getVector", &MVBaseline::getVector)
        .method("putVector", &MVBaseline::putVector);

    mod.add_type<MVDirection>("MVDirection")
        .constructor<const Quantity &, const Quantity &>()
        .constructor<double, double>() // direction cosines
        .constructor<double, double, double>() // xyz, Units: m
        .method("getLong", static_cast<Double (MVDirection::*)(void) const>(&MVDirection::getLong))
        .method("getLat", static_cast<Double (MVDirection::*)(void) const>(&MVDirection::getLat))
        .method("setAngle", &MVDirection::setAngle)
        .method("getValue", &MVDirection::getValue)
        .method("getVector", &MVDirection::getVector)
        .method("putVector", &MVDirection::putVector);

    mod.add_type<MVDoppler>("MVDoppler")
        .constructor<double>() // dimensionless
        .constructor<Quantity>() // velocity, will be divided by c
        .method("getValue", &MVDoppler::getValue)
        .method("putVector", &MVDoppler::putVector);

    mod.add_type<MVEarthMagnetic>("MVEarthMagnetic")
        .constructor<double, double, double>() // x,y,z vector in Tesla
        .method("getValue", static_cast<const Vector<double> & (MVEarthMagnetic::*)(void) const>(&MVEarthMagnetic::getValue))
        .method("getVector", &MVEarthMagnetic::getVector)
        .method("putVector", &MVEarthMagnetic::putVector);

    mod.add_type<MVEpoch>("MVEpoch")
        .constructor<const Quantity &>()
        .constructor<double>()  // Units: days
        .method("get", &MVEpoch::get)
        .method("getVector", &MVEpoch::getVector)
        .method("putVector", &MVEpoch::putVector);

    mod.add_type<MVFrequency>("MVFrequency")
        .constructor<double>()  // Hz
        .method("getValue", &MVFrequency::getValue)
        .method("getVector", &MVFrequency::getVector)
        .method("putVector", &MVFrequency::putVector);

    mod.add_type<MVPosition>("MVPosition")
        // Can be supplied as (radial length, longitude, latitude)
        .constructor<const Quantity &, const Quantity &, const Quantity &>()
        // or x, y, z (m)
        .constructor<double, double, double>()
        .method("getLength", static_cast<Quantity (MVPosition::*)(const Unit &) const>(&MVPosition::getLength))
        .method("getLong", static_cast<Double (MVPosition::*)(void) const>(&MVPosition::getLong))
        .method("getLat", static_cast<Double (MVPosition::*)(void) const>(&MVPosition::getLat))
        .method("getValue", &MVPosition::getValue)
        .method("getVector", &MVPosition::getVector)
        .method("putVector", &MVPosition::putVector);

    mod.add_type<MVRadialVelocity>("MVRadialVelocity")
        .constructor<double>() // Unit: m/s
        .method("getValue", &MVRadialVelocity::getValue)
        .method("getVector", &MVRadialVelocity::getVector)
        .method("putVector", &MVRadialVelocity::putVector);

    mod.add_type<MVuvw>("MVuvw")
        .constructor<double, double, double>() // Units: m
        .method("getValue", static_cast<const Vector<double> & (MVuvw::*)(void) const>(&MVuvw::getValue))
        .method("getVector", &MVuvw::getVector)
        .method("putVector", &MVuvw::putVector);

    addmeasure<MBaseline, MVBaseline>(mod, "MBaseline");
    addmeasure<MDirection, MVDirection>(mod, "MDirection");
    addmeasure<MDoppler, MVDoppler>(mod, "MDoppler");
    addmeasure<MEarthMagnetic, MVEarthMagnetic>(mod, "MEarthMagnetic");
    addmeasure<MEpoch, MVEpoch>(mod, "MEpoch");
    addmeasure<MFrequency, MVFrequency>(mod, "MFrequency");
    addmeasure<MPosition, MVPosition>(mod, "MPosition");
    addmeasure<MRadialVelocity, MVRadialVelocity>(mod, "MRadialVelocity");
    addmeasure<Muvw, MVuvw>(mod, "Muvw");
}