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
        wrapped.method("shape", &WrappedT::shape);
        wrapped.method("getindex", static_cast<WrappedT (WrappedT::*)(size_t) const >(&WrappedT::operator[]));
        wrapped.method("getindex", static_cast<const T & (WrappedT::*)(const IPosition &) const>(&WrappedT::operator()));
        wrapped.method("tovector", static_cast<std::vector<T> (WrappedT::*)(void) const>(&WrappedT::tovector));
        wrapped.method("getStorage", static_cast<const T * (WrappedT::*)(bool &) const>(&WrappedT::getStorage));
        wrapped.method("freeStorage", &WrappedT::freeStorage);
    });