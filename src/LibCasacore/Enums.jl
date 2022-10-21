module TableOptions
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_tableoption)

    function __init__()
        @initcxx
    end
end

module BaselineTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mbaseline)

    function __init__()
        @initcxx
    end
end

module DirectionTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mdirection)

    function __init__()
        @initcxx
    end
end

module DopplerTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mdoppler)

    function __init__()
        @initcxx
    end
end

module EarthMagneticTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mearthmagnetic)

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

module FrequencyTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mfrequency)

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

module RadialVelocityTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_mradialvelocity)

    function __init__()
        @initcxx
    end
end

module UVWTypes
    using casacorecxx_jll
    using CxxWrap

    @wrapmodule(libcasacorecxx, :define_module_muvw)

    function __init__()
        @initcxx
    end
end