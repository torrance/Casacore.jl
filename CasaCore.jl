module CasaCore

using jlcasacore_jll
using CxxWrap

@wrapmodule(libjlcasacore)

function __init__()
    @initcxx
end

end
