module Tables

using ..LibCasacore

mutable struct Column{T, N, S}
    name::Symbol
    parent::LibCasacore.TableAllocated
    columnref::S
end

function Column(tableref::LibCasacore.Table, name::LibCasacore.String)
    tabledesc= LibCasacore.tableDesc(tableref)
    columndesc = LibCasacore.columnDesc(tabledesc, name)

    scalarT = (LibCasacore.gettype ∘ LibCasacore.dataType)(columndesc)
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
    if fixedshape || ndim == 0
        T = scalarT
        N = ndim + 1
    else
        N = 1
        T = Array{scalarT, ndim}
    end

    slice = Tuple(fill(:, N))

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

# Required for to_indices() to work
Base.eachindex(::IndexLinear, A::Column) = (@inline; Base.oneto(length(A)))

# Scalar array indexing
function Base.getindex(c::Column{T, 1, S}, i::Int)::T where {T, S <: LibCasacore.ScalarColumn}
    return LibCasacore.getindex(c.columnref, i)
end

# Array of arrays indexing
function Base.getindex(c::Column{T, 1, S}, i::Int)::T where {T, S <: LibCasacore.ArrayColumn}
    arrayslice = LibCasacore.getindex(c.columnref, i)
    shape = Tuple(LibCasacore.shape(arrayslice)...)
    LibCasacore.asarray(arrayslice, length.(shape))
end

# Multidimensional array indexing
function Base.getindex(c::Column{T, N, S}, I::Vararg{Int, N})::T where {T, N, S <: LibCasacore.ArrayColumn}
    Irow, Icell... = I .- 1
    array = LibCasacore.getindex(c.columnref, Irow)

    Icell = LibCasacore.IPosition(Icell)
    return LibCasacore.getindex(array, Icell)[]
end

# Scalar array slicing
function Base.getindex(c::Column{T, 1, S}, i::Union{Colon, OrdinalRange}) where {T, S <: LibCasacore.ScalarColumn}
    i = to_indices(c, (i,))[1] .- 1
    shape = Base.index_shape(i)

    rowslicer = LibCasacore.Slicer(i)
    arrayslice = LibCasacore.getColumnRange(c.columnref, rowslicer)

    LibCasacore.asarray(arrayslice, length.(shape))
end

# Array of arrays slicing
function Base.getindex(c::Column{T, 1, S}, i::Union{Colon, OrdinalRange}) where {T, S <: LibCasacore.ArrayColumn}
    i = to_indices(c, (i,))[1] .- 1
    return getindex.((c,), i)
end

# Multimdimensional array slicing
function Base.getindex(c::Column{T, N, S}, I::Vararg{Union{Int, Colon, OrdinalRange}, N}) where {T, N, S <: LibCasacore.ArrayColumn}
    I = map(x -> x .- 1, to_indices(c, I))
    shape = Base.index_shape(I...)

    @show I shape

    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)
    arrayslice = LibCasacore.getColumnRange(c.columnref, rowslicer, cellslicer)

    LibCasacore.asarray(arrayslice, length.(shape))
end

# Forced multimdimensional slicing on column without fixed size
# Colon indexing is not an option here since we don't know ahead of time the size of cells
function Base.getindex(
    c::Column{T, 1, S},
    i1::Union{Int, Colon, OrdinalRange},
    i2::Union{Int, Colon, OrdinalRange},
    I::Vararg{Union{Int, Colon, OrdinalRange}, N}
) where {T, N, S <: LibCasacore.ArrayColumn}
    I = (i1, i2, I...)

    if Colon() in I[1:(end - 1)]
        throw(ArgumentError("A column with no fixed size cannot be indexed with ':' except along the rows."))
    end

    I = map(x -> x .- 1, to_indices(c, I))
    shape = Base.index_shape(I...)

    rowslicer = LibCasacore.Slicer(I[end])
    cellslicer = LibCasacore.Slicer(I[1:(end - 1)]...)
    arrayslice = LibCasacore.getColumnRange(c.columnref, rowslicer, cellslicer)

    LibCasacore.asarray(arrayslice, length.(shape))
end

mutable struct Table
    tableref::LibCasacore.TableAllocated
    columns::Vector{Column}

    function Table(path)
        path = LibCasacore.String(path)
        tableref = LibCasacore.Table(path)

        # Add columns
        tabledesc = LibCasacore.tableDesc(tableref)
        columnnames = LibCasacore.columnNames(tabledesc)
        columns = [Column(tableref, columnname[]) for columnname in columnnames]

        table = new(tableref, columns)
        return table
    end
end

function Base.getindex(x::Table, name::Symbol)
    for column in x.columns
        if column.name == name
            return column
        end
    end
    throw(KeyError(name))
end

Base.keys(x::Table) = [col.name for col in x.columns]

end