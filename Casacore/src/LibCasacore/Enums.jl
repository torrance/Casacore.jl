module DirectionTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mdirection)

    function __init__()
        @initcxx
    end
end

module PositionTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mposition)

    function __init__()
        @initcxx
    end
end

module EpochTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mepoch)

    function __init__()
        @initcxx
    end
end