# Casacore.jl

[![CI](https://github.com/torrance/Casacore.jl/actions/workflows/main.yml/badge.svg)](https://github.com/torrance/Casacore.jl/actions/workflows/main.yml)

This package provides a high-level interface to use Casacore from Julia.

[Casacore](https://casacore.github.io) is a popular library used primarily in radio astronomy. Amongst other things, its tables functionality is used to store and manipulate visibility data, whilst its measures interface allows for conversion between different reference frames based on ephemeris data.

This package uses [casacorecxx](https://github.com/torrance/casacorecxx) which uses [CxxWrap](https://github.com/JuliaInterop/CxxWrap.jl) to wrap the C++ Casacore codebase. These raw objects and methods are available in `Casacore.LibCasacore`.

This package is under active development. Casacore is a very large package, and this Julia interface has been developed with specific usecases in mind, limited by the author's own experience. Issues and pull requests are very welcome to help expand on functionality and use cases.

## Installation

Casacore.jl is installable in the usual way:

```julia
] add Casacore
```

Casacore.jl will install all of its own dependencies including Casacore itself.

Casacore.jl is limited to the currently supported architectures of `casacore_jll`.

## Updating the ephemeris data

When installing Casacore.jl, the build step downloads and installs the latest ephermis data for use in `Casacore.Measures`. To update this dataset with a later version, the build step can be manually rerun:

```julia
] build Casacore
```

## Casacore.Tables

### Opening and creating new tables

Tables can be opened or created in the following way:

```julia
using Casacore.Tables: Tables, Table

# Open existing table, read only
table = Table("/path/to/my/table.ms", Tables.Old)

# Open existing table, read/write
table = Table("/path/to/my/table.ms", Tables.Update)

# Create a new, empty table
table = Table("/path/to/my/table.ms", Tables.New)
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
corrected[:, 1:192, :] <: Array{ComplexF64, 3}
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

# Unknown dimension and size
coldesc = ArrayColumnDesc{Int16}()
table[:NEWCOL] = coldesc
typeof(table[:NEWCOL]) <: Column{Array{Int16}, 1}
```

Explicit column construction in this way allows adding comments to the column as well as controlling the storage manager and storage groups.

#### Implicit construction

Columns may also be added by simply assigning an array to your table where the type of the array will determine the type of the column. This will additionally populate the column with the contents of the array.

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

## Casacore.Measures

Measures allow constructing objects that contain a value with respect to a particular reference frame. Examples include: an Altitude/Azimuth frame with respect to a particular location and time on Earth; a Right Ascension/Declination on the sky with respect to the J2000 system; or a time in UTC timezone.

In Casacore, Measures are primarily implemented to allow conversions between types, and in Casacore.jl this is the primary usecase for which we have designed their use.

### Examples

An example converting a Direction from J2000 to local Aziumth/Elevation:

```julia
using Casacore.Measures
using Unitful  # provides @str_u macro for units, e.g. 1u"m"

# We want to convert this RA/Dec direction to Azimuth/Elevation
direction = Measures.Direction(
    Measures.Directions.J2000, 0u"rad", 0u"rad"
)

# A local Az/El requires knowledge of our position on Earth and the time
pos = Measures.Position(
    Measures.Positions.ITRF, 5000u"km", 1000u"km", 100u"km"
)
time = Measures.Epoch(Measures.Epochs.UTC, 1234567u"d")

# Perform conversion by passing in desired type, as well as
# any additional measures as a reference frame required for the conversion
# newdirection = mconvert(newtype, olddirection, [measures...])
direction = mconvert(
    Measures.Directions.AZEL, direction, pos, time
)

direction.long, direction.lat  # -1.2469808464138252 rad, 0.48889373998953756 rad
```

An example converting a frequency from its REST frame to observed frequency based on additional information about its radial velocity:

```julia
# Create radial velocity measure with a direction
direction = Measures.Direction(Measures.Directions.J2000, 45u"°", 20u"°")
# Provide additional frame information for a measure as additional measures
# during construction.
# e.g. RadialVelocity(::Type, ::Unitful.Velocity, ::AbstractMeasure...)
rv = Measures.RadialVelocity(
    Measures.RadialVelocities.LSRD, 20_000u"km/s", direction
)

freq = Measures.Frequency(
    Measures.Frequencies.REST, 1420u"MHz", direction
)

# Now calculate the redshifted frequency
freqshifted = mconvert(Measures.Frequencies.LSRD, freq, rv)
freqshifted.freq  # 1328 MHz
```

### Measure Construction

In general, a Measure is constructed in the following way

```julia
Measure(::Type, initval..., ::AbstractMeasures...; offset)
```

Here the `initval` differs between specific Measures. For example, for `Direction` it consists two angle values; for `Epoch` it is a single time value. See below for full list.

The optional list of `AbstractMeasures` will be added as a reference frame for the Measure, and the optional `offset` can be entered as an origin point for the Measure. These concepts map directly to the underlying Casacore library.

The supported Measures and their properties are:

| Measure        | Properties   | Quantity            |
| -------------- | ------------ | ------------------- |
| Baseline       | `:x :y :z`   | `Unitful.Length`    |
| Direction      | `:long :lat` | `Unitful.Angle`     |
| Doppler        | `:doppler`   | `Union{Float64, Unitful.Velocity}` |
| EarthMagnetic  | `:x :y :z`   | `Unitful.Bfield`    |
| Epoch          | `:time`      | `Unitful.Time`      |
| Frequency      | `:freq`      | `Unitful.Frequency` |
| Position       | `:x :y :z`   | `Unitful.Length`    |
| RadialVelocity | `velocity`   | `Unitful.Velocity`  |
| UVW            | `:u :v :w`   | `Unitful.Length`    |

As an example, we might construct an EarthMagnetic vector in the following way:

```julia
# Pass in each of x, y, z vector components in milli Tesla
em = Measures.EarthMagnetic(
    Measures.EarthMagnetics.AZEL, 1u"mT", 2u"mT", 3u"mT"
)

em.y == 0.002u"T"
```

A more complicated example might be to provide a direction with respect to Jupiter at a particular time:

```julia
# Set up frame
time = Measures.Epoch(Measures.Epochs.UTC, 60_000u"d")

# Create Jupiter direction with addtional Epoch
jupiter = mconvert(
    Measures.Directions.J2000,
    Measures.Direction(Measures.Directions.JUPITER, 0u"°", 0u"°", time)
)

# Create direction offset from Jupiter
direction = Measures.Direction(
    Measures.Directions.J2000, 5u"°", 10u"°"; offset=jupiter
)
```

### Conversions

Conversions between types can be handled by the `mconvert()` function:

```julia
# Direction conversions
mconvert(
    type::Directions.Types, dir::Direction, measures::AbstractMeasures...
)
```

This will convert `dir` to the type `type`, with optional measures provided as part of the reference frame that might be necessary for the conversion.

For large numbers of conversions of the same type, using the same reference frame, it is recommended to reuse Measure and Conversion objects for maximal performance, as the construction of these objects has some overhead. This can be done using `mconvert!() which has the signature:

```julia
mconvert!(in::T, out::T, c:Converter) where {T <: AbstractMeasure}
```

 For example:

```julia

# Set up 100,000 random RA/Dec coordinates to transform to AZEL
radecs = rand(2, 100_000) * Unitful.rad

# Reference frame
time = Measures.Epoch(Measures.Epochs.UTC, 60000u"d")
pos = Measures.Position(
    Measures.Positions.ITRF, 6000u"km", 0u"km", 0u"km"
)

# Create conversion engine just once and reuse
# Converter(in::type, out::type, measures::AbstractMeasures...)
c = Measures.Converter(
    Measures.Directions.J2000, Measures.Directions.AZEL, time, pos
)

# Create template direction which we will mutate for each conversion
dir = zero(Measures.Direction)

azels = map(eachcol(radecs)) do (ra, dec)
    dir.type = Measures.Directions.J2000
    dir.long = ra
    dir.lat = dec
    mconvert!(dir, dir, c)
    return dir.long, dir.lat
end
```

## Casacore.LibCasacore

All objects and methods that are exposed by CxxWrap are available in LibCasacore. This is not a stable API and may be subject to change.

## Still to do

* Utility function: create empty measurement set
* Table keywords (?)
* Doppler/frequency/radial velocity conversions
* Observatories