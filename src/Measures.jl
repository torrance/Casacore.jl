module Measures

export mconvert, mconvert!, radius, long, lat

using Unitful: Unitful as U, ustrip

using ..LibCasacore

abstract type AbstractMeasure end

function Base.zero(::T) where {T <: AbstractMeasure}
    return zero(T)
end

function Base.:(==)(a::T, b::T) where {T <: AbstractMeasure}
    return all(propertynames(a)) do p
        getproperty(a, p) == getproperty(b, p)
    end
end

function Base.isapprox(a::T, b::T; kwargs...) where {T <: AbstractMeasure}
    return all(propertynames(a)) do p
        if p === :type
            getproperty(a, :type) == getproperty(b, :type)
        else
            isapprox(getproperty(a, p), getproperty(b, p); kwargs...)
        end
    end
end

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

function mconvert(outtype, in::AbstractMeasure, measures::AbstractMeasure...)
    out = zero(in)
    out.type = outtype
    return mconvert!(out, in, measures...)
end

function mconvert!(out::T, in::T, measures::AbstractMeasure...) where {T <: AbstractMeasure}
    c = Converter(in, out.type, measures...)
    return mconvert!(out, in, c)
end

function mconvert!(out::T, in::T, c::Converter) where {T <: AbstractMeasure}
    @assert(c.in == in.type)
    LibCasacore.convert!(c.cxx_object, in.m, out.m)
    out.type = c.out
    return out
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
using .Positions: Position, radius, long, lat
using .RadialVelocities: RadialVelocity
using .UVWs: UVW

# Define some adhoc constructors for Measures that need to be defined late to avoid cyclic
# type dependencies
import .Dopplers
import .Frequencies
import .RadialVelocities

function Dopplers.Doppler(rv::RadialVelocity)
    return Doppler(
        Dopplers.BETA,
        LibCasacore.toDoppler(rv.m),
        LibCasacore.MVDoppler(0),
        zeros(1)
    )
end

function Dopplers.Doppler(freq::Frequency, rest::U.Frequency)
    return Doppler(
        Dopplers.BETA,
        LibCasacore.toDoppler(freq.m, LibCasacore.MVFrequency(ustrip(Float64, U.Hz, rest))),
        LibCasacore.MVDoppler(0),
        zeros(1),
    )
end

function Frequencies.Frequency(type::Frequencies.Types, doppler::Doppler, rest::U.Frequency)
    return Frequency(
        type,
        LibCasacore.fromDoppler(
            doppler.m,
            LibCasacore.MVFrequency(ustrip(Float64, U.Hz, rest)),
            Int(type)
        ),
        LibCasacore.MVFrequency(0),
        zeros(1)
    )
end

function RadialVelocities.RadialVelocity(type::RadialVelocities.Types, doppler::Doppler)
    return RadialVelocity(
        type,
        LibCasacore.fromDoppler(doppler.m, Int(type)),
        LibCasacore.MVRadialVelocity(0),
        zeros(1)
    )
end

function UVWs.UVW(type::UVWs.Types, baseline::Baseline, dir::Direction, EW::Bool=false)
    value = LibCasacore.MVuvw(
       LibCasacore.getValue(baseline.m), LibCasacore.getValue(dir.m), EW
    )
    measure = LibCasacore.Muvw(value, Int(type))
    return UVW(type, measure, value, zeros(3))
end

end