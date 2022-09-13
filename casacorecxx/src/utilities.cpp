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