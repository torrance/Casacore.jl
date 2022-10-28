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

function mconvert(in::AbstractMeasure, out, measures::AbstractMeasure...)
    c = Converter(in.type, out, measures...)
    return mconvert(in, c)
end

function mconvert(in::T, c::Converter) where {T <: AbstractMeasure}
    out = zero(T)
    mconvert!(out, in, c)
    return out
end

function mconvert!(out::AbstractMeasure, in::AbstractMeasure, c::Converter)
    @assert(c.in == in.type)
    LibCasacore.convert!(c.cxx_object, in.m, out.m)
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

# Import primary types into Measures
using .Baselines: Baseline
using .Dopplers: Doppler
using .Directions: Direction
using .EarthMagnetics: EarthMagnetic
using .Epochs: Epoch
using .Frequencies: Frequency
using .Positions: Position
using .RadialVelocities: RadialVelocity
using .UVWs: UVW

export mconvert, mconvert!

end