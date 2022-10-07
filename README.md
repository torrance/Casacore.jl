# Casacore.jl

This package provides Casacore for using in Julia. All dependencies are installed automatically using BinaryBuilder and Pkg.Artifacts.

Previous work on Casacore integration has been packaged as [Cassacore.jl](https://github.com/kiranshila/CasaCore.jl) which provides a bespoke C wrapper. This present module differs by using CxxWrap to wrap the C++ methods of Casacore to provide low level access to Casacore internals, and well as a more intuitive high level interface.

## Usage

### Tables

Read/write access to tables and columns:

```julia
using Casacore.Tables: Table

table = Table("/path/to/my/table.ms", readonly=false)

size(table) == (260000, 25)  # rows x columns
```

### Subtables

Access subtables as properties of the the `Table` object:

```julia
propertynames(table)  # => (:ANTENNA, :DATA_DESCRIPTION, ...)

subtable = table.ANTENNA
```

Subtables are opened with the same locking and write attributes as their parents.

### Columns

Access columns as keys on the `Table` objects:

```julia
keys(table)  # => [:UVW, :WEIGHT, :DATA, ...]

# Load a column
uvwcol = table[:UVW]  # <: Column{Float32, 2}

# Retrieve data from column as Julia array
data = uvwcol[:, 1:100]  # Get the first 100 rows

# Write to column
uvwcol[:, 1:100] = rand(Float32, 3, 100)
```

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
weightcol = table[:WEIGHT]  # <: Column{Vector{Float64}, 1}
size(weightcol) == (260000,)
row = weightcol[2] <: Vector{Float64}
size(row) == (4,)
```

These small array allocations for every row are not great for performance, but are required since we cannot know the size the rows ahead of time.

However, if you _know_ that that your column with no fixed size actually contains constant-sized arrays, you can force Casacore to attempt to load these as one contiguous array:

```julia
data = weightcol[1:4, :] <: Matrix{Float64}
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

# Perform conversion by passing in additional measures
# newdirection = Direction(newtype, olddirection, [measures...])
direction = Measures.Direction(Measures.DirectionTypes.AZEL, direction, pos, time)

long(direction), lat(direction)  # -1.2469808464138252 rad, 0.48889373998953756 rad
```

## Still to do

* Allow memory reuse when indexing into columns (e.g. copy!(), maybe with view())
* Create table
* Create columns from arrays or other columns
* Add/delete rows functionality
* Table keywords (?)
* Additional measures
* Observatories
