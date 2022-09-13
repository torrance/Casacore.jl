mod.add_type<ColumnDesc>("ColumnDesc")
    .constructor()
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
    .constructor<const String &, Table::TableOption, const TSMOption &>()
    .constructor<const String &, const TableLock &, Table::TableOption, const TSMOption &>()
    .method("nrow", &Table::nrow)
    .method("tableDesc", &Table::tableDesc)
    .method("flush", &Table::flush);

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
        wrapped.template constructor();
        wrapped.template constructor<const Table &, const String &>();
        wrapped.method("nrow", &TableColumn::nrow);
        wrapped.method("shapeColumn", &TableColumn::shapeColumn);
        wrapped.method("getindex", &WrappedT::operator());
        wrapped.method("getColumn", [](const WrappedT & wrappedT) { return wrappedT.getColumn(); });
        wrapped.method(
            "getColumnRange",
            [](const WrappedT & wrappedT, const Slicer & rowRange) {
                return wrappedT.getColumnRange(rowRange);
            }
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
        wrapped.template constructor();
        wrapped.template constructor<const Table &, const String &>();
        wrapped.method("nrow", &TableColumn::nrow);
        wrapped.method("shapeColumn", &TableColumn::shapeColumn);
        wrapped.method("getindex", &WrappedT::operator());
        wrapped.method("getColumn", [](const WrappedT & wrappedT) { return wrappedT.getColumn(); });
        wrapped.method(
            "getColumnRange",
            [](const WrappedT & wrappedT, const Slicer & rowRange, const Slicer & arraySection) {
                return wrappedT.getColumnRange(rowRange, arraySection);
            }
        );
    });