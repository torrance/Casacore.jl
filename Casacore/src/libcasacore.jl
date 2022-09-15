module LibCasacore
import Base

using CxxWrap
using casacorecxx_jll

@wrapmodule(libcasacorecxx)

function __init__()
    @initcxx
end

# Vector: implements iteration, indexing
Base.length(x::Vector)::Int = reduce(*, Base.size(x))
Base.size(x::Vector)::Tuple{Int} = Tuple(shape(x)...)
Base.getindex(x::Vector, i) = getindex(x, i - 1)
Base.firstindex(::Vector) = 1
Base.lastindex(x::Vector) = length(x)
Base.eltype(x::Vector) = typeof(x[1])

function Base.iterate(x::Vector)
    if length(x) == 0
        return nothing
    end
    return x[1], 1
end

function Base.iterate(x::Vector, i)
    i += 1
    if i > length(x)
        return nothing
    end
    return x[i], i
end

# Array
Base.length(x::Array)::Int = reduce(*, Base.size(x))
Base.size(x::Array) = Tuple(shape(x)...)

# IPosition: implements indexing, iteration
IPosition(is::NTuple{N, Int}) where N = IPosition(N, is...)
Base.length(x::IPosition)::Int = size(x)
Base.getindex(x::IPosition, i) = getindex(x, i - 1)
Base.firstindex(::IPosition) = 1
Base.lastindex(x::IPosition) = length(x)

function Base.iterate(x::IPosition)
    if length(x) == 0
        return nothing
    end
    return x[1], 1
end

function Base.iterate(x::IPosition, i)
    i += 1
    if i > length(x)
        return nothing
    end
    return x[i], i
end

# ColumnDescSet: implements iteration, indexing
Base.length(x::ColumnDescSet)::Int = ncolumn(x)
Base.getindex(x::ColumnDescSet, i) = getindex(x, i - 1)
Base.firstindex(::ColumnDescSet) = 1
Base.lastindex(x::ColumnDescSet) = length(x)

function Base.iterate(x::ColumnDescSet)
    if length(x) == 0
        return nothing
    end
    return x[1], 1
end

function Base.iterate(x::ColumnDescSet, i)
    i += 1
    if i > length(x)
        return nothing
    end
    return x[i], i
end

function gettype(x::DataType)
    typemap = (
        TpBool => CxxBool,
        TpChar => CxxChar,
        TpUChar => CxxUChar,
        TpShort => Int16,
        TpUShort => UInt16,
        TpInt => Int32,
        TpUInt => UInt32,
        TpInt64 => Int64,
        TpFloat => Float32,
        TpDouble => Float64,
        TpComplex => ComplexF32,
        TpDComplex => ComplexF64,
        TpString => String,
    )

    for (key, value) in typemap
        if key == x
            return value
        end
    end

    throw(KeyError(typeof(x)))
end

Base.Symbol(x::String) = (Symbol ∘ unsafe_string ∘ LibCasacore.c_str)(x)
String(x::Symbol) = (String ∘ Base.String)(x)

function Slicer(is::Vararg{Union{Int, OrdinalRange}, N}) where N
    _step(::Int) = 1 # This little function lets us treat indices as ranges
    _step(x) = step(x)

    return Slicer(
        IPosition(N, first.(is)...),
        IPosition(N, last.(is)...),
        IPosition(N, _step.(is)...),
        endIsLast
    )
end

function asarray(
    x::Union{VectorAllocated{T}, ArrayAllocated{T}}, dims::NTuple{N, Int}=Base.size(x)
)::Base.Array{T, N} where {T, N}
    deleteIt = Ref{UInt8}()
    ptr = getStorage(x, deleteIt)
    dest = unsafe_wrap(Base.Array, ptr.cpp_object, dims, own=false)::Base.Array{T, N}

    # This finalizer closure keeps x in scope to avoid its destruction so long as the
    # wrapping array is alive. It is also responsible for freeing storage if x
    # is non-contiguous and getStorage() resulted in a copy.
    finalizer(dest) do _
        # For some reason (I don't understand why) we occasionally see these pointers
        # already set to NULL when this finalizer runs. For now, to avoid use after free
        # errors, we check first that they contain valid addresses.
        if ptr.cpp_object != C_NULL && x.cpp_object != C_NULL
            freeStorage(x, ptr, Bool(deleteIt[]))
        end
    end
end

end