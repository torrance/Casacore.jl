# Casacore.jl

[![CI](https://github.com/torrance/Casacore.jl/actions/workflows/main.yml/badge.svg)](https://github.com/torrance/Casacore.jl/actions/workflows/main.yml)

This package provides a high-level interface to use Casacore from Julia.

[Casacore](https://casacore.github.io) is a popular library used primarily in radio astronomy. Amongst other things, its tables functionality is used to store and manipulate visibility data, whilst its measures interface allows for conversion between different reference frames based on ephemeris data.

This package uses [casacorecxx](https://github.com/torrance/casacorecxx) which uses [CxxWrap](https://github.com/JuliaInterop/CxxWrap.jl) to wrap the C++ Casacore codebase. These raw objects and methods are available in `Casacore.LibCasacore`.

Casacore is a very large package, and this Julia interface has been developed with specific usecases in mind, limited by the authors own experience. Please open an issue to discuss extending this package in ways that are more suitable to your own usecase.

## Installation

Casacore.jl is installable in the usual way:

```julia
] add Casacore
```

Casacore will install all its own dependencies including Casacore itself.

Casacore only works on Linux x86_64 due to the current supported architectures of `casacore_jll`.

## Updating the ephermis data

When installing Casacore.jl, the build step downloads and installs the latest ephermis data used in `Casacore.Measures`. To update this dataset with a later version, the build step can be manually rerun:

```julia
] build Casacore
```

## Casacore.Tables

### Opening and creating new tables

Tables can be opened as such:

```julia
using Casacore.Tables: Table, TableOptions

# Open existing table, read only
table = Table("/path/to/my/table.ms", TableOptions.Old)

# Open existing table, read/write
table = Table("/path/to/my/table.ms", TableOptions.Update)

# Create a new, empty table
table = Table("/path/to/my/table.ms", TableOptions.New)
```

Other TableOptions are listed below:

| TableOptions | Description                                             |
| ------------ | ------------------------------------------------------- |
| Old          | Open existing table read only                           |
| Update       | Open existing table read/write                           |
| New          | Create new table                                        |
| NewNoReplace | Create new table but error if it already exists         |
| Scratch      | Create new table, but delete when it falls out of scope |

A table contains certain metadata about its size, columns and subtables:

```julia
# Get table size
size(table) == (260000, 25)  # rows x columns
# list of columns
keys(table) == (:UVW, :DATA, ...)
# list of subtables
propertynames(table) == (:ANTENNA, :FIELD, ...)
```

### Adding/removing rows

Table rows can be added or removed using the `resize!()` function:

```julia
size(table) == (260000, 25)

# Expand total rows to 300,000
# New rows will be filled with default values
resize!(table, 300000)
size(table) == (300000, 25)

# Truncate number of rows
resize!(table, 100000)
size(table) == (100000, 25)
```

Additionally, specific rows may be deleted using `deleteat!()`:

```julia
# Delete row 100
deleteat!(table, 100)

# Delete every second row
deleteat!(table, 1:2:size(table, 1))
```

### Subtables

Subtables can be accessed as properties of the the `Table` object:

```julia
propertynames(table)  # => (:ANTENNA, :FIELD, ...)

subtable = table.ANTENNA
```

Subtables are opened with the same locking and write attributes as their parents.

New subtables can be added by simply assigning a new table object:

```julia
subtable = Table()  # with no path, creates a temporary table
resize!(subtable, 128)  # set rows to 128

# Add some columns to our table
subtable[:ID] = 1:128
subtable[:X] = rand(128)
subtable[:Y] = rand(128)
subtable[:Z] = rand(128)

# Finally, set our table as a subtable
table.ANTENNA = subtable  # this results in a copy
```

Note that the subtable is copied into the parent table, and future modifications to the `subtable` object in the example above will not affect `table.ANTENNA`.

Subtables can be deleted using `delete!()`:

```julia
delete!(table, :ANTENNA)
```

### Columns

Columns are accessed as keys on `Table` objects:

```julia
keys(table)  # => [:UVW, :WEIGHT, :DATA, ...]

# Load a column
uvwcol = table[:UVW]  # <: Column{Float32, 2}
```

Like native `Array{T, N}` types, columns also store their element type and dimensionality as `Column{T, N}`.

Casacore allows for a range of column types, including some degenerative array columns with unknown shape or even unknown dimensionality. The below table lists these different types and their representation in Casacore.jl:

| Name   | Description | Type |
| ------ | ----------- | ---- |
| Scalar | Simple vector column | `Column{T, 1}` |
| Fixed array | Array column with known dimension and size | `Column{T, N}` |
| Fixed dimension | Array column with fixed dimension but variable size per row | `Column{Array{T, N - 1}, 1}`|
| Free array | Array column unknown dimension and size | `Column{Array{T}, 1}`|

### Column Indexing

Columns may be indexed to retrieve or set their data:

```julia
# Retrieve data from column as Julia array
data = uvwcol[:, 1:100]  # Get the first 100 rows

# Write to column
uvwcol[:, 1:100] = rand(Float32, 3, 100)
```

Indexing operations are limited to single values, unit ranges (e.g. `3:300`), and colons. More complicated indexes such as with strided ranges (e.g. `1:2:100`) or with bitmasks are not supported.

A note on performance: whilst the `Column{T, N}` object provides an indexing interface, this is an expensive operation that involves searching and reading from the disk. We do not provide an iterable or AbstractArray interface to this object to discourage its use in this way. Instead, it is recommended to index from a `Column{T, N}` object infrequently, loading large amounts of data at a time, possibly using batching operations to manage memory usage.

For scalar columns and arrays with a fixed size, indexing operations and the resulting array types will be intuitive. For example:

```julia
flags = table[:FLAG_ROW]  # <: Column{Bool, 1}
size(flags) == (260000,)
flags[:] <: Vector{Bool}

corrected = table[:CORRECTED_DATA]  # <: Column{ComplexF64, 3}
size(corrected) == (4, 768, 260000)
corrected[1:4, 1:192, :] <: Array{ComplexF64, 3}
```

Columns that do not have a fixed size will be typed as providing arrays of arrays. For example:

```julia
# No fixed size, but known dimemsion per cell
weightcol = table[:WEIGHT]  # <: Column{Vector{Float64}, 1}
size(weightcol) == (260000,)
row = weightcol[2] <: Vector{Float64}
size(row) == (4,)
```

These small array allocations for every row are not great for performance, but are required since we cannot know the size (and sometimes the dimension) of the rows ahead of time.

#### Forced multidimensional indexing

If you _know_ that that your column with no fixed size actually contains constant-sized arrays, you can force Casacore to attempt to load these as one contiguous array:

```julia
data = weightcol[1:4, :]::Matrix{Float64}
```

In this example, we are telling Casacore that weightcol is 2-dimensional, and contains at least 4 values in each row. If these assumptions are not true, this will fail.

### Adding/removing columns

#### Explicit construction

Columns may be added in two ways. The first is by construction of a `ColumnDesc` object. When we assign this to the `Table` object, we cause the column to be created:

```julia
# Create scalar column
coldesc = ScalarColumnDesc{Float64}(comment="My special data")
table[:NEWCOL] = coldesc
typeof(table[:NEWCOL]) <: Column{Float64, 1}

# Create array column, with each cell having 2 dimensions
# and fixed shape
coldesc = ArrayColumnDesc{Int, 2}((4, 768))
table[:NEWCOL] = coldesc
typeof(table[:NEWCOL]) <: Column{Int, 3}
```

Note that the dimesionality `N` of the `ArrayColumnDesc{T, N}` refers to the dimensionality of the cell. The dimesionality of the column additionally includes the rows.

The degenerate column types may also be created in this way:

```julia
# Unknown size, known dimension
coldesc = ArrayColumnDesc{ComplexF64, 2}()
table[:NEWCOL] = coldesc
typeof(table[:NEWCOL]) <: Column{Array{ComplexF64, 2}, 1}

# Unknown dimesion and size
coldesc = ArrayColumnDesc{Int16}()
table[:NEWCOL] = coldesc
typeof(table[:NEWCOL]) <: Column{Array{Int16}, 1}
```

Explicit column construction in this way allows adding comments to the column as well as controlling the storage manager and storage groups.

#### Implicit construction

Columns may also be added by simply assiging an array to your table where the type of the array will determine the type of the column. This will additionally populate the column with the contents of the array.

For example:

```julia
size(table) = (1000, 4)  # has 1,000 rows

table[:NEWCOL] = zeros(Int, 1000)::Vector{Int}
typeof(table[:NEWCOL]) <: Column{Int, 1}

table[:NEWCOL] = zeros(Int, 3, 1000)::Array{Int, 3}
typeof(table[:NEWCOL]) <: Column{Int, 3}

# No fixed sized
table[:NEWCOL] = [rand(rand(UInt8, 2)...) for _ in 1:1000]::Vector{Matrix{Float64}}
typeof(table[:NEWCOL]) <: Column{Matrix{Float64}, 1}

# No fixed dimension or size
table[:NEWCOL] = [rand(rand(UInt8, rand([1, 2, 3]))...) for _ in 1:1000]::Vector{Array{Float64}}
typeof(table[:NEWCOL]) <: Column{Array{Float64}, 1}
```

Note that the table row length must match last dimension of the array being assigned.

#### Deletion

Columns may be deleted using the `delete!()` function. For example:

```julia
delete!(table, :NEWCOL)
```

### TaQL

Casascore implements a query language that allows selecting, sorting, filtering and joining tables to produce derived tables, as described in [Note 199](https://casacore.github.io/casacore-notes/199.html). With the exception of `CALC` operations, this is available by calling `taql(command, table1, [table2, ...])`. For example:

```julia
derived = taql(
    raw"SELECT max(ANTENNA1, ANTENNA2) as MAXANT FROM $1 WHERE ANTENNA1 <> ANTENNA2 AND NOT FLAG_ROW",
    table
)

size(derived[:MAXANT]) == (228780,)
```

Command accepts a standard Julia `String`, however note that in this case we've prefixed the string with `raw"..."` which stops Julia attempting to interpolate the `$1` table identifier. If you use a standard string literal, ensure such identifiers are properly escaped.

### Measures

Measures allow constructing objects that contain a value with respect to a particular reference frame. Examples include: an Altitude/Azimuth frame with respect to a particular location and time on Earth; a Right Ascension/Declination on the sky with respect to the J2000 system; or a time in UTC timezone.

In Casacore, Measures are primarily implemented to allow conversions between frames and in Julia this is the primary usecase for which we have designed their use.

```julia
using Casacore.Measures
using Unitful  # provides @str_u macro for units, e.g. 1u"m"

# We want to convert this RA/Dec direction to Azimuth/Elevation
direction = Measures.Direction(Measures.DirectionTypes.J2000, 0u"rad", 0u"rad")

# A local Az/El requires knowledge of our position on Earth and the time
pos = Measures.Position(Measures.PositionTypes.ITRF, 1u"km", 0u"rad", 0u"rad")
time = Measures.Epoch(Measures.EpochTypes.UTC, 1234567u"d")

# Perform conversion by passing in desired type, as well as
# any additional measures required for the conversion
# newdirection = mconvert(olddirection, newtype, [measures...])
direction = Measures.mconvert(direction, Measures.DirectionTypes.AZEL, pos, time)

long(direction), lat(direction)  # -1.2469808464138252 rad, 0.48889373998953756 rad
```

## Still to do

* Utility function: create empty measurement set
* Table keywords (?)
* Additional measures
* Observatories