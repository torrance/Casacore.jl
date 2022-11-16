module Tables

export taql

using ..LibCasacore
using CEnum

@cenum TableOptions begin
    Old=1
    New
    NewNoReplace
    Scratch
    Update
    Delete
end

abstract type ColumnDesc{T} end

struct ScalarColumnDesc{T} <: ColumnDesc{T}
    comment::String
    datamanager::Symbol
    datagroup::Symbol
end

function ScalarColumnDesc{T}(
    ;comment="", datamanager=:StandardStMan, datagroup=Symbol()
) where T
    return ScalarColumnDesc{T}(comment, datamanager, datagroup)
end


# T denotes the element type; it must be a primitive type.
# N denotes the dimensionality of the cell, not the full column
#
# Valid states:
#   * Freeform array: N = 0; shape = nothing
#   * Fixed dimension, variable shape: N >= 1, shape = nothing
#   * Fixed dimension and shape: N >= 1, shape <: NTuple{N, Int}
struct ArrayColumnDesc{T, N} <: ColumnDesc{T}
    shape::Union{Nothing, NTuple{N, Int}}
    comment::String
    datamanager::Symbol
    datagroup::Symbol
end

# ArrayColumnDesc with no fixed dimension (or shape)
function ArrayColumnDesc{T}(
    ; comment="",  datamanager=:StandardStMan, datagroup=Symbol()
) where T
    return ArrayColumnDesc{T, 0}(nothing, comment, datamanager, datagroup)
end

# ArrayColumnDesc with fixed dimension
function ArrayColumnDesc{T, N}(
    shape=nothing; comment="",  datamanager=:StandardStMan, datagroup=Symbol()
) where {T, N}
    return ArrayColumnDesc{T, N}(shape, comment, datamanager, datagroup)
end

mutable struct Column{T, N, S}
    name::Symbol
    parent::LibCasacore.TableAllocated
    columnref::S
end

function Column(tableref::LibCasacore.Table, name::LibCasacore.String)
    tabledesc= LibCasacore.tableDesc(tableref)
    columndesc = LibCasacore.columnDesc(tabledesc, name)

    scalarT = (LibCasacore.getcxxtype ∘ LibCasacore.dataType)(columndesc)
    ndim = Int(LibCasacore.ndim(columndesc))
    if ndim == 0
        columnref = LibCasacore.ScalarColumn{scalarT}(tableref, name)
    else
        columnref = LibCasacore.ArrayColumn{scalarT}(tableref, name)
    end

    # If fixedshape == True, we treat this as a single multidimensional
    # array::Array{T, ndim + 1} and dimensions (size..., rows).
    # If fixedshape == False we treat this as a vector::Vector{T} of length rows with
    # values that are either scalars (if ndim == 0) or arrays (if ndim > 0).
    fixedshape = Bool(LibCasacore.isFixedShape(columndesc))
    scalarT = LibCasacore.getjuliatype(scalarT)

    if fixedshape || ndim == 0
        T = scalarT
        N = ndim + 1
    elseif ndim < 0
        # If ndim is negative, the dimension of cell arrays is unknown
        N = 1
        T = Array{scalarT}
    else
        N = 1
        T = Array{scalarT, ndim}
    end

    return Column{T, N, typeof(columnref)}(
        Symbol(name), tableref, columnref
    )
end

# Column: implements indexing
function Base.size(c::Column{T, N, S})::NTuple{N, Int} where {T, N, S <: LibCasacore.ArrayColumn}
    return (LibCasacore.shapeColumn(c.columnref)..., LibCasacore.nrow(c.columnref))
end

function Base.size(c::Column{T, 1, S})::NTuple{1, Int} where {T, S <: LibCasacore.ScalarColumn}
    return (LibCasacore.nrow(c.columnref),)
end

Base.length(c::Column) = reduce(*, size(c))

# Fill scalar column with value
function Base.fill!(c::Column{T, 1, S}, x) where {T, N, S <: LibCasacore.ScalarColumn}
    x = convert(LibCasacore.getcxxtype(T), x)
    LibCasacore.fillColumn(c.columnref, x)
    return c
end

# Fill array of arrays with array
function Base.fill!(c::Column{T, 1, S}, x) where {T <: Array, N, S <: LibCasacore.ArrayColumn}
    x = collect(LibCasacore.getcxxtype(eltype(T)), x)

    # If x is a scalar, collect() creates an 0-dimensional array.
    # But we need size() to report at least (1,)
    if ndims(x) == 0
        x = reshape(x, 1)
    end

    # Check dimensionality of x matches cell, if it is known
    celldims = LibCasacore.ndimColumn(c.columnref)
    if celldims != 0 && ndims(x) != celldims
        throw(DimensionMismatch("Expected fill!() value with $(celldims) dimensions, got $(ndims(x))"))
    end

    arr = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
        LibCasacore.IPosition(size(x))
    )
    LibCasacore.copy!(arr, append!(Any[], x))
    LibCasacore.fillColumn(c.columnref, arr)

    return c
end

# Fill fixed array column with value
function Base.fill!(c::Column{T, N, S}, x) where {T, N, S <: LibCasacore.ArrayColumn}
    x = convert(LibCasacore.getcxxtype(T), x)

    cellshape = tuple(LibCasacore.shapeColumn(c.columnref)...)
    arr = LibCasacore.Array{LibCasacore.getcxxtype(T)}(
        LibCasacore.IPosition(cellshape)
    )
    LibCasacore.set(arr, x)
    LibCasacore.fillColumn(c.columnref, arr)

    return c
end

@inline function checkbounds(x::Column{T, N}, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, N, M}
    if N != M
        throw(DimensionMismatch("Indexing into $(N)-dimensional Column with $(M) indices"))
    end

    Base.checkbounds_indices(Bool, axes(x), I) || throw(BoundsError(x, I))
end

# Row index on array of arrays
@inline function checkbounds(x::Column{T, 1, S}, i::Union{Int, Colon, OrdinalRange}) where {T, S <: LibCasacore.ArrayColumn}
    Base.checkbounds_indices(Bool, axes(x), (i,)) || throw(BoundsError(x, i))
end

# Multidim index into array of arrays
@inline function checkbounds(x::Column{T, 1, S}, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, S <: LibCasacore.ArrayColumn, M}
    # Base.ndims() is not defined is N is unset.
    function ndims(::Type{P}) where {T, N, P <: Array{T, N}}
        return N
    end
    function ndims(::Type{P}) where {T, P <: Array{T}}
        return -1
    end

    # Perform dimension check if dimension is set for column
    if ndims(T) >= 0 && ndims(T) + 1 != M
        throw(DimensionMismatch("Indexing into $(1 + ndims(T))-dimensional Column with $(M) indices"))
    end

    Base.checkbounds_indices(Bool, axes(x), (I[end],)) || throw(BoundsError(x, I))
end

# Required for to_indices() to work
Base.eachindex(::IndexLinear, A::Column) = (@inline; Base.oneto(length(A)))

# Scalar array indexing
function Base.getindex(c::Column{T, 1, S}, i::Union{Int, Colon, OrdinalRange}) where {T, S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    i = to_indices(c, (i,))

    # Create destination array
    shape = length.(Base.index_shape(i...))  # singleton dimensions are collapsed
    dest = Array{T}(undef, shape)

    # Create casacore::Vector which shares underlying memeory with dest
    shape = LibCasacore.IPosition(length.(i))  # retain singleton dimensions
    casacore_vector = LibCasacore.Vector{LibCasacore.getcxxtype(T)}(
        shape, convert(Ptr{Cvoid}, pointer(dest)), LibCasacore.SHARE
    )

    # Write into dest
    rowslicer = LibCasacore.Slicer(broadcast(.-, i, 1)...)
    LibCasacore.getColumnRange(c.columnref, rowslicer, casacore_vector, false)

    return zerodim_as_scalar(dest)
end

function Base.setindex!(c::Column{T, 1, S}, v, i::Union{Int, Colon, OrdinalRange}) where {T, S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))

    varray = collect(T, v)
    Base.setindex_shape_check(varray, length(i))

    GC.@preserve varray begin
        vectorslice = LibCasacore.Vector{LibCasacore.getcxxtype(T)}(
            LibCasacore.IPosition(Tuple(length(i))),
            convert(Ptr{Cvoid}, pointer(varray)),
            LibCasacore.SHARE
        )
        rowslicer = LibCasacore.Slicer(i .- 1)
        LibCasacore.putColumnRange(c.columnref, rowslicer, vectorslice)
    end

    return v
end

# Array of arrays indexing
function Base.getindex(c::Column{T, 1, S}, i::Int)::T where {T <: Array, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)

    # First check if row contains anything at all
    if LibCasacore.isDefined(c.columnref, i - 1) == 0
        # If dimensions of T are not set, return 0 length vector
        if T == Array{eltype(T)}
            return T(undef, 0)
        # Otherwise we return zero length N-dimensional vector
        else
           return T(undef, ntuple(zero, ndims(T)))
        end
    end

    # Create destination
    shape = LibCasacore.shape(c.columnref, i - 1)
    dest = T(undef, shape...)

    # Create casacore::Array which shares underlying memeory with dest
    casacore_array = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
        shape, convert(Ptr{Cvoid}, pointer(dest)), LibCasacore.SHARE
    )

    # Write into dest
    LibCasacore.get(c.columnref, i - 1, casacore_array, false)

    return dest
end

function Base.getindex(c::Column{T, 1, S}, i::Union{Colon, OrdinalRange})::Vector{T} where {T <: Array, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))
    return map(i) do i
        @inbounds c[i]
    end
end

function Base.setindex!(c::Column{T, 1, S}, v, i::Int)::T where {T <: Array, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)

    # Check dimensionality of value matches column
    celldims = LibCasacore.ndimColumn(c.columnref)
    if celldims != 0 && ndims(v) != celldims
        # Fixed dimension array
        throw(DimensionMismatch("Expected value with $(celldims) dimensions, got $(ndims(v))"))
    end

    varray = collect(eltype(T), v)
    GC.@preserve varray begin
        arrayslice = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
            LibCasacore.IPosition(size(varray)),
            convert(Ptr{Cvoid}, pointer(varray)),
            LibCasacore.SHARE
        )
        LibCasacore.put(c.columnref, i - 1, arrayslice)
    end
    return v
end

function Base.setindex!(c::Column{T, 1, S}, v, i::Union{Int, Colon, OrdinalRange}) where {T <: Array, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))
    broadcast(i, v) do idx, val
        @inbounds c[idx] = val
    end
    return v
end

# Multidimensional array indexing
function Base.getindex(c::Column{T, N, S}, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, N, M, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, I...)

    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        I = to_indices(c, I)
    end

    # Create destination
    shape = length.(Base.index_shape(I...))  # singleton dimensions are collapsed
    dest = Array{eltype(T)}(undef, shape)

    # Create casacore::Array which shares underlying memeory with dest
    shape = LibCasacore.IPosition(length.(I))  # retain singleton dimensions
    casacore_array = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
        shape, convert(Ptr{Cvoid}, pointer(dest)), LibCasacore.SHARE
    )

    # 0- to 1-based indexing
    I = broadcast(.-, I, 1)
    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)

    # Copy column slice into dest
    LibCasacore.getColumnRange(c.columnref, rowslicer, cellslicer, casacore_array, false)

    return zerodim_as_scalar(dest)
end

function Base.setindex!(c::Column{T, N, S}, v, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, N, M, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, I...)

    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        I = to_indices(c, I)
    end

    varray = collect(eltype(T), v)
    Base.setindex_shape_check(varray, length.(I)...)

    # 1- to 0-based indexing
    I = broadcast(.-, I, 1)
    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)

    GC.@preserve varray begin
        arrayslice = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
            LibCasacore.IPosition(length.(I)),
            convert(Ptr{Cvoid}, pointer(varray)),
            LibCasacore.SHARE
        )
        LibCasacore.putColumnRange(c.columnref, rowslicer, cellslicer, arrayslice)
    end

    return v
end

# Setindex and getindex! for String type
# This is special since it is not a primitive type and does not allow for simple bit coversions.

function Base.getindex(c::Column{String, 1, S}, i::Int) where {S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    return String(LibCasacore.getindex(c.columnref, i - 1))
end

function Base.getindex(c::Column{String, 1, S}, i::Union{Colon, OrdinalRange}) where {S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))
    return map(i) do idx
        @inbounds c[idx]
    end

    # Fetch data
    rowslicer = LibCasacore.Slicer(broadcast(.-, i, 1)...)
    casacore_vector = LibCasacore.getColumnRange(c.columnref, rowslicer)

    # Copy into dest and fix type and size
    dest = Any[]
    LibCasacore.copy!(dest, casacore_vector)

    # Correctly size output array and convert to Julia String
    shape = length.(Base.index_shape(i...))
    dest = map(String, reshape(dest, shape))

    return dest
end

function Base.setindex!(c::Column{String, 1, S}, v, i::Int) where {S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    LibCasacore.put(c.columnref, i - 1, LibCasacore.String(string(v)))
    return nothing
end

function Base.setindex!(c::Column{String, 1, S}, v, i::Union{Colon, OrdinalRange}) where {S <: LibCasacore.ScalarColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))

    varray = Vector{Any}(undef, length(v))
    map!(LibCasacore.String ∘ string, varray, v)
    Base.setindex_shape_check(varray, length(i))

    casacore_vector = LibCasacore.Vector{LibCasacore.String}(
        LibCasacore.IPosition(size(i))
    )
    LibCasacore.copy!(casacore_vector, varray)

    rowslicer = LibCasacore.Slicer(i .- 1)
    LibCasacore.putColumnRange(c.columnref, rowslicer, casacore_vector)

    return nothing
end

function Base.getindex(c::Column{T, 1, S}, i::Int) where {T <: Array{String}, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))

    # First check if row contains anything at all
    if LibCasacore.isDefined(c.columnref, i - 1) == 0
        # If dimensions of T are not set, return 0 length vector
        if T == Array{String}
            return T(undef, 0)
        # Otherwise we return zero length N-dimensional vector
        else
            return T(undef, ntuple(zero, ndims(T)))
        end
    end

    dest = Any[]  # Type Any is required for CxxWrap ArrayRef
    casacore_array = LibCasacore.get(c.columnref, i - 1)
    LibCasacore.copy!(dest, casacore_array)

    return map(String, reshape(dest, size(casacore_array)))
end

function Base.getindex(c::Column{T, 1, S}, i::Union{Colon, OrdinalRange}) where {T <: Array{String}, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))

    return map(i) do idx
        @inbounds c[idx]
    end
end

function Base.setindex!(c::Column{T, 1, S}, v, i::Int) where {T <: Array{String}, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)

    # Check dimensionality of value matches column
    celldims = LibCasacore.ndimColumn(c.columnref)
    if celldims != 0 && ndims(v) != celldims
        # Fixed dimension array
        throw(DimensionMismatch("Expected value with $(celldims) dimensions, got $(ndims(v))"))
    end

    varray = Vector{Any}(undef, length(v))  # Type Any is required for CxxWrap ArrayRef
    map!(LibCasacore.String ∘ string, varray, v)

    casacore_array = LibCasacore.Array{LibCasacore.String}(LibCasacore.IPosition(size(v)))
    LibCasacore.copy!(casacore_array, varray)
    LibCasacore.put(c.columnref, i - 1, casacore_array)

    return nothing
end

function Base.setindex!(c::Column{T, 1, S}, v, i::Union{Colon, OrdinalRange}) where {T <: Array{String}, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, i)
    i, = to_indices(c, (i,))

    broadcast(i, v) do idx, val
        @inbounds c[idx] = val
    end
    return nothing
end

function Base.getindex(c::Column{T, N, S}, I::Vararg{Union{Int, Colon, OrdinalRange}}) where {T <: Union{String, Array{String}}, N, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, I...)

    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        I = to_indices(c, I)
    end

    # 0- to 1-based indexing
    I = broadcast(.-, I, 1)
    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)

    # Retrieve column slice
    casacore_array = LibCasacore.getColumnRange(c.columnref, rowslicer, cellslicer)

    # Copy out data from array
    dest = Any[]
    LibCasacore.copy!(dest, casacore_array)

    # Transform dest to typed and correctly sized array
    shape = length.(Base.index_shape(I...))  # singleton dimensions are collapsed
    dest = map(String, reshape(dest, shape))

    return zerodim_as_scalar(dest)
end

function Base.setindex!(c::Column{T, N, S}, v::AbstractString, I::Vararg{Int}) where {T <: Union{String, Array{String}}, N, M, S <: LibCasacore.ArrayColumn}
    c[I...] = [string(v)]
end

function Base.setindex!(c::Column{T, N, S}, v, I::Vararg{Union{Int, Colon, OrdinalRange}}) where {T <: Union{String, Array{String}}, N, S <: LibCasacore.ArrayColumn}
    @boundscheck checkbounds(c, I...)

    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        I = to_indices(c, I)
    end

    varray = Vector{Any}(undef, length(v))
    map!(LibCasacore.String ∘ string, varray, v)
    Base.setindex_shape_check(varray, length.(I)...)

    # 1- to 0-based indexing
    I = broadcast(.-, I, 1)
    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)

    # Copy contents of varray into caacore array and then into the column
    casacore_array = LibCasacore.Array{LibCasacore.String}(LibCasacore.IPosition(length.(I)))
    LibCasacore.copy!(casacore_array, varray)
    LibCasacore.putColumnRange(c.columnref, rowslicer, cellslicer, casacore_array)

    return nothing
end

struct Table
    tableref::LibCasacore.TableAllocated
end

function Table(path::String, tableoption::TableOptions=Old)
    path = LibCasacore.String(path)

    if tableoption ∈ (Old, Update)
        # Open existing table
        tableref = LibCasacore.Table(path, Int(tableoption))
    elseif tableoption ∈ (
        New, NewNoReplace, Update, Scratch
    )
        # Create new table, possibly replacing old one
        tableref = LibCasacore.Table(LibCasacore.Plain)
        LibCasacore.rename(tableref, path, Int(tableoption))
    else
        throw(ArugmentError("Invalid TableOption argument"))
    end

    return Table(tableref)
end

# Constructor used in creating subtables
function Table()
    return Table(LibCasacore.Table(LibCasacore.Plain))
end

Base.size(x::Table)::Tuple{Int, Int} = (
    LibCasacore.nrow(x.tableref),
    LibCasacore.ncolumn(LibCasacore.tableDesc(x.tableref))
)

Base.size(x::Table, dim::Int) = size(x)[dim]

function Base.resize!(x::Table, n::Integer)
    nrows = size(x, 1)
    if n == nrows
        # We're good, do nothing
    elseif n > nrows
        # Add some rows, fill with default value
        LibCasacore.addRow(x.tableref, n - size(x, 1), true)
    else
        # Remove rows from end
        deleteat!(x, (n + 1):nrows)
    end

    return x
end

function Base.deleteat!(x::Table, inds)
    inds = collect(UInt64, inds)
    if inds ⊈ 1:size(x, 1)
        throw(BoundsError(x, inds))
    end

    # One to zero indexing
    inds .-= 1

    GC.@preserve inds begin
        rownrs = LibCasacore.RowNumbers(
            LibCasacore.Vector{LibCasacore.getcxxtype(UInt64)}(
                LibCasacore.IPosition(size(inds)),
                convert(Ptr{Cvoid}, pointer(inds)),
                LibCasacore.SHARE
            )
        )

        LibCasacore.removeRow(x.tableref, rownrs)
    end

    return x
end

function Base.getindex(x::Table, name::Symbol)
    if name in keys(x)
        return Column(x.tableref, LibCasacore.String(name))
    end
    throw(KeyError(name))
end

function Base.setindex!(x::Table, v::ScalarColumnDesc{T}, name::Symbol) where {T}
    if name in keys(x)
        delete!(x, name)
    end
    LibCasacore.addColumn(
        x.tableref,
        LibCasacore.ColumnDesc(
            LibCasacore.ScalarColumnDesc{LibCasacore.getcxxtype(T)}(
                LibCasacore.String(name),
                LibCasacore.String(v.comment),
                LibCasacore.String(v.datamanager),
                LibCasacore.String(v.datagroup),
            )
        ),
        true
    )
    return v
end

function Base.setindex!(x::Table, v::ArrayColumnDesc{T, N}, name::Symbol) where {T, N}
    if name in keys(x)
        delete!(x, name)
    end

    if v.shape == nothing
        # Non-fixed shape, possibly non-fixed dimesions (if N = 0)
        columndesc = LibCasacore.ArrayColumnDesc{LibCasacore.getcxxtype(T)}(
            LibCasacore.String(name),
            LibCasacore.String(v.comment),
            LibCasacore.String(v.datamanager),
            LibCasacore.String(v.datagroup),
            N
        )
    else
        # Fixed shape, and dimensions = length(shape)
        columndesc = LibCasacore.ArrayColumnDesc{LibCasacore.getcxxtype(T)}(
            LibCasacore.String(name),
            LibCasacore.String(v.comment),
            LibCasacore.String(v.datamanager),
            LibCasacore.String(v.datagroup),
            LibCasacore.IPosition(v.shape),
        )
    end

    LibCasacore.addColumn(
        x.tableref, LibCasacore.ColumnDesc(columndesc), true
    )
    return v
end

# Add scalar column
function Base.setindex!(x::Table, v::Vector{T}, name::Symbol) where {T}
    if size(x, 1) != length(v)
        throw(DimensionMismatch("Cannot assign column with $(length(v)) rows to table with $(size(x, 1)) rows"))
    end

    # Create column
    coldesc = ScalarColumnDesc{T}()
    x[name] = coldesc

    # Populate column with data from v
    x[name][:] = v

    return v
end

# Add fixed size array
function Base.setindex!(x::Table, v::Array{T, N}, name::Symbol) where {T, N}
    if size(x, 1) != size(v, N)
        throw(DimensionMismatch("Cannot assign column with $(size(v, N)) rows to table with $(size(x, 1)) rows"))
    end

    # Create column
    coldesc = ArrayColumnDesc{T, N - 1}(size(v)[1:end - 1])
    x[name] = coldesc

    # Populate column with data from v
    # TODO: implemnt copy() instead
    I = ntuple(_ -> :, N)
    x[name][I...] = v

    return v
end

# Add array of arrays column with known dimensionality
function Base.setindex!(x::Table, v::Vector{T}, name::Symbol) where {N, M, T <: Array{M, N}}
    if size(x, 1) != length(v)
        throw(DimensionMismatch("Cannot assign column with $(size(v, N)) rows to table with $(size(x, 1)) rows"))
    end

    # Create column
    coldesc = ArrayColumnDesc{eltype(T), N}()
    x[name] = coldesc

    # Populate column with data from v
    x[name][:] = v

    return v
end

# Add array of arrays column with unknown dimensionality
function Base.setindex!(x::Table, v::Vector{T}, name::Symbol) where {M, T <: Array{M}}
    if size(x, 1) != length(v)
        throw(DimensionMismatch("Cannot assign column with $(size(v, N)) rows to table with $(size(x, 1)) rows"))
    end

    # Create column
    coldesc = ArrayColumnDesc{eltype(T), 0}()
    x[name] = coldesc

    # Populate column with data from v
    x[name][:] = v

    return v
end

function Base.delete!(x::Table, name::Symbol)
    if name in keys(x)
        LibCasacore.removeColumn(x.tableref, LibCasacore.String(name))
        return
    end
    if name in propertynames(x)
        LibCasacore.deleteSubTable(x.tableref, LibCasacore.String(name), true)
        return
    end
    throw(KeyError(name))
end

function Base.keys(x::Table)::Vector{Symbol}
    tabledesc = LibCasacore.tableDesc(x.tableref)
    return map(Symbol, LibCasacore.columnNames(tabledesc))
end

function Base.propertynames(x::Table, private::Bool=false)
    subtables = private ? [fieldnames(Table)...] : Symbol[]

    keywords = LibCasacore.keywordSet(x.tableref)
    for i in range(0, LibCasacore.size(keywords) - 1)
        recordid = LibCasacore.RecordFieldId(i)
        if LibCasacore.type(keywords, i) == LibCasacore.TpTable
            push!(subtables, Symbol(LibCasacore.name(keywords, recordid)))
        end
    end

    return tuple(subtables...)
end

function Base.getproperty(x::Table, name::Symbol)
    if hasfield(Table, name)
        return getfield(x, name)
    end

    if name in propertynames(x)
        recordid = LibCasacore.RecordFieldId(LibCasacore.String(name))
        keywords = LibCasacore.keywordSet(x.tableref)
        return Table(LibCasacore.asTable(keywords, recordid))
    end

    return getfield(x, name)
end

function Base.setproperty!(parent::Table, name::Symbol, sub::Table)
    namestr = LibCasacore.String(name)
    pathstr = LibCasacore.String(
        joinpath(
            String(LibCasacore.tableName(parent.tableref)), String(name)
        )
    )

    # Columns, subtables (and others) share the same keyword namespace. We cannot add a
    # subtable with existing keyword name.
    idx = LibCasacore.fieldNumber(LibCasacore.keywordSet(parent.tableref), namestr)
    if idx > 0
        if LibCasacore.type(LibCasacore.keywordSet(parent.tableref), idx) != LibCasacore.TpTable
            throw(ErrorException("Subtable name $(name) duplicates existing keyword"))
        end

        # Otherwise delete existing table
        LibCasacore.deleteSubTable(parent.tableref, namestr, true)
    end

    # We do a copy, rather than a rename. This avoids mutating the sub, which is closer in
    # in line with the semantics of setproperty!().
    LibCasacore.deepCopy(sub.tableref, pathstr, Int(New))
    sub = LibCasacore.Table(pathstr, Int(Old))

    LibCasacore.defineTable(
        LibCasacore.rwKeywordSet(parent.tableref), LibCasacore.RecordFieldId(namestr), sub
    )

    return Table(sub)  # Or return the original sub table?
end

flush(x::Table; fsync=true, recursive=true) = LibCasacore.flush(x.tableref, fsync, recursive)

function taql(command::String, table::Table, tables::Vararg{Table})
    tablesvec = LibCasacore.StdVector{LibCasacore.ConstCxxPtr{LibCasacore.Table}}()
    for table in (table, tables...)
        push!(tablesvec, Ref(LibCasacore.ConstCxxPtr(table.tableref)))
    end

    GC.@preserve table tables begin
        return Table(LibCasacore.tableCommand(
            command,
            tablesvec
        ))
    end
end

function zerodim_as_scalar(x::Array{T, 0}) where T
    return x[]
end

function zerodim_as_scalar(x)
    return x
end

end