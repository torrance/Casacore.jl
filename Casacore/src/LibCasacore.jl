module LibCasacore

using CxxWrap
using jlcasacore_jll

@wrapmodule(libjlcasacore)

function __init__()
    @initcxx
end

end