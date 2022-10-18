module Tables

export taql

using ..LibCasacore
using ..LibCasacore: TableOptions

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
#
# Valid states:
#   * Freeform array: N = -1; shape = nothing
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
    return ArrayColumnDesc{T, -1}(nothing, comment, datamanager, datagroup)
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
    x = convert(T, x)
    LibCasacore.fillColumn(c.columnref, x)
    return c
end

# Fill array column with array
function Base.fill!(c::Column{T, N, S}, x) where {T, N, S <: LibCasacore.ArrayColumn}
    x = collect(eltype(T), x)

    celldims = LibCasacore.ndimColumn(c.columnref)
    cellshape = tuple(LibCasacore.shapeColumn(c.columnref)...)

    # Special case: allow filling fixed array with single value
    # We need to expand this value to an array
    if N > 1 && length(x) == 1 && cellshape != ()
        x = fill(x[], cellshape)
    end

    # Check dimensionality of fill value matches column
    if cellshape != () && size(x) != cellshape
        # Fixed size array
        throw(DimensionMismatch("Expected fill!() value with size $(cellshape), got $(size(x))"))
    elseif celldims != 0 && ndims(x) != celldims
        # Fixed dimesion array
        throw(DimensionMismatch("Expected fill!() value with $(celldims) dimensions, got $(ndims(x))"))
    else
        # No set dimension or size of cells! Anything goes...
    end

    GC.@preserve x begin
        arr = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
            LibCasacore.IPosition(size(x)),
            convert(Ptr{Cvoid}, pointer(x)),
            LibCasacore.SHARE,
        )
        LibCasacore.fillColumn(c.columnref, arr)
    end

    return c
end

@inline function checkbounds(x::Column{T, N}, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, N, M}
    if N != M
        throw(DimensionMismatch("Indexing into $(N)-dimensional Column with $(M) indices"))
    end

    Base.checkbounds_indices(Bool, axes(x), I) || throw(BoundsError(x, I))
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

    varray = collect(eltype(T), v)
    GC.@preserve varray begin
        arrayslice = LibCasacore.Array{LibCasacore.getcxxtype(eltype(T))}(
            LibCasacore.IPosition(size(v)),
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
    for (idx, val) in zip(i, v)
        @inbounds c[idx] = val
    end
    return v
end

# Multidimensional array indexing
function Base.getindex(c::Column{T, N, S}, I::Vararg{Union{Int, Colon, OrdinalRange}, M}) where {T, N, M, S <: LibCasacore.ArrayColumn}
    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]
        @boundscheck checkbounds(c, Irow)

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        @boundscheck checkbounds(c, I...)
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
    # We have to do a little extra work if we are forcing a multidim index
    # into an array with no fixed size
    if N == 1 && T <: Array
        Icell, Irow = I[begin:end - 1], I[end]
        @boundscheck checkbounds(c, Irow)

        Irow, = to_indices(c, (Irow,))
        if Colon() in Icell
            throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
        end

        I =  (Icell..., Irow)
    else
        @boundscheck checkbounds(c, I...)
        I = to_indices(c, I)
    end

    varray = collect(eltype(T), v)
    Base.setindex_shape_check(varray, length.(I)...)

    # 1- to 0-based indexing
    I = map(x -> x .- 1, I)
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

struct Table
    tableref::LibCasacore.TableAllocated
end

function Table(path::String, tableoption::TableOptions.TableOption=TableOptions.Old)
    path = LibCasacore.String(path)

    if tableoption ∈ (TableOptions.Old, TableOptions.Update)
        # Open existing table
        tableref = LibCasacore.Table(path, tableoption)
    elseif tableoption ∈ (
        TableOptions.New, TableOptions.NewNoReplace, TableOptions.Update, TableOptions.Scratch
    )
        # Create new table, possibly replacing old one
        tableref = LibCasacore.Table(LibCasacore.Plain)
        LibCasacore.rename(tableref, path, tableoption)
    else
        throw(ArugmentError("Invalid TableOption argument"))
    end

    return Table(tableref)
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
        # Non-fixed shape, possibly non-fixed dimesions (if N = -1)
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

function Base.delete!(x::Table, name::Symbol)
    if name in keys(x)
        LibCasacore.removeColumn(x.tableref, LibCasacore.String(name))
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