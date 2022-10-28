module Directions

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    J2000
    JMEAN
    JTRUE
    APP
    B1950
    B1950_VLA
    BMEAN
    BTRUE
    GALACTIC
    HADEC
    AZEL
    AZELSW
    AZELGEO
    AZELSWGEO
    JNAT
    ECLIPTIC
    MECLIPTIC
    TECLIPTIC
    SUPERGAL
    ITRF
    TOPO
    ICRS
    N_Types
    # Planets. First one should be Mercury
    MERCURY = 32
    VENUS
    MARS
    JUPITER
    SATURN
    URANUS
    NEPTUNE
    PLUTO
    SUN
    MOON
    # Comet or other table-described solar system body
    COMET
    N_Planets
    # All extra bits
    EXTRA = 32
end

# Defaults
const DEFAULT = J2000
# Synonyms
const AZELNE = AZEL
const AZELNEGEO = AZELGEO

mutable struct Direction <: AbstractMeasure
    type::Types
    m::LibCasacore.MDirectionAllocated
    mv::LibCasacore.MVDirectionAllocated
    cache::Vector{Float64}
end

function Direction(
    type::Types, long::U.DimensionlessQuantity, lat::U.DimensionlessQuantity, measures::AbstractMeasure...;
    offset::Union{Nothing, Direction}=nothing
)
    ref = LibCasacore.MDirection!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    value = LibCasacore.MVDirection(
        ustrip(Float64, U.rad, long), ustrip(Float64, U.rad, lat)
    )
    measure = LibCasacore.MDirection(value, ref)

    return Direction(type, measure, value, zeros(3))
end

Base.zero(::Type{Direction}) = Direction(DEFAULT, 0 * U.rad, 0 * U.rad)

function Base.propertynames(x::Direction, private::Bool=false)
    return (:type, :long, :lat)
end

function Base.getproperty(d::Direction, name::Symbol)
    if name === :long
        x = LibCasacore.getValue(d.m, 0)
        y = LibCasacore.getValue(d.m, 1)
        return atan(y, x)::Float64 * U.rad
    elseif name === :lat
        z = LibCasacore.getValue(d.m, 2)
        return asin(z)::Float64 * U.rad
    else
        return getfield(d, name)
    end
end

function Base.setproperty!(x::Direction, name::Symbol, v)
    if name === :long
        lat = ustrip(Float64, U.rad, x.lat)
        long = ustrip(Float64, U.rad, v)
        x.cache[1] = cos(lat) * cos(long)
        x.cache[2] = cos(lat) * sin(long)
        x.cache[3] = sin(lat)
        _setdata!(x, x.cache)
    elseif name === :lat
        long = ustrip(Float64, U.rad, x.long)
        lat = ustrip(Float64, U.rad, v)
        x.cache[1] = cos(lat) * cos(long)
        x.cache[2] = cos(lat) * sin(long)
        x.cache[3] = sin(lat)
        _setdata!(x, x.cache)
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MDirection!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MDirection!Convert(Int(in), ref)
    )
end

end