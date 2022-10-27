module Measures

using ..LibCasacore

abstract type AbstractMeasure end

function Base.show(io::IO, x::AbstractMeasure)
    write(io, "$(typeof(x))(")
    join(io, (":$(p)=$(getproperty(x, p))" for p in propertynames(x)), ", ")
    write(io, ")")
end

struct Converter{T, S}
    in::S
    out::S
    cxx_object::T
end

function mconvert!(out::AbstractMeasure, in::AbstractMeasure, c::Converter)
    @assert(c.in == in.type)
    LibCasacore.convert!(c.cxx_object, in.m, out.m)
    # m = c.cxx_object(LibCasacore.getValue(in.m))
    # LibCasacore.set(out.m, LibCasacore.getValue(m))
    out.type = c.out
end

function _setdata!(x::AbstractMeasure, data::AbstractVector{Float64})
    GC.@preserve data begin
        LibCasacore.putVector(x.mv, pointer(data), length(data))
        LibCasacore.set(x.m, x.mv)
    end
end

include("Measures/Baselines.jl")
include("Measures/Dopplers.jl")
include("Measures/Directions.jl")
include("Measures/EarthMagnetics.jl")
include("Measures/Epochs.jl")
include("Measures/Frequencies.jl")
include("Measures/Positions.jl")
include("Measures/RadialVelocities.jl")
include("Measures/UVWs.jl")

end


#=

using Casacore.Measures: Directions, Positions, Epochs, Converter, mconvert!
using BenchmarkTools
using Unitful

direction = Directions.Direction(Directions.J2000, (π)u"rad", (π/2)u"rad")
pos = Positions.Position(Positions.ITRF, 1000, 0, 0)
t = Epochs.Epoch(Epochs.UTC, 1234567u"d")
convert = Converter(Directions.J2000, Directions.AZEL, t, pos)

vals = eachcol(rand(2, 128*128))
@benchmark foreach(vals) do longlat
    direction.long = longlat[1] * Unitful.rad
    direction.lat = longlat[2] * Unitful.rad
    direction.type = Directions.J2000
    mconvert!(direction, direction, convert)
end

=#