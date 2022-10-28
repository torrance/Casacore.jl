module EarthMagnetics

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
    # Models. First one should be IGRF
    IGRF = 32
    N_Models
    # All extra bits (for internal use only)
    EXTRA = 32
end

# Defaults
const DEFAULT=IGRF
# Synonyms
const AZELNE=AZEL
const AZELNEGEO=AZELGEO

mutable struct EarthMagnetic <: AbstractMeasure
    type::Types
    m::LibCasacore.MEarthMagneticAllocated
    mv::LibCasacore.MVEarthMagneticAllocated
    cache::Vector{Float64}
end

function EarthMagnetic(type::Types, x::U.BField, y::U.BField, z::U.BField, measures::AbstractMeasure...; offset::Union{Nothing, EarthMagnetic}=nothing)
    ref = LibCasacore.MEarthMagnetic!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    value = LibCasacore.MVEarthMagnetic(
        ustrip(Float64, U.nT, x), ustrip(Float64, U.nT, y), ustrip(Float64, U.nT, z)
    )
    measure = LibCasacore.MEarthMagnetic(value, ref)

    return EarthMagnetic(type, measure, value, zeros(3))
end

Base.zero(::Type{EarthMagnetic}) = EarthMagnetic(DEFAULT, 0 * U.T, 0 * U.T, 0 * U.T)

function Base.propertynames(x::EarthMagnetic, private::Bool=false)
    return (:type, :x, :y, :z)
end

function Base.getproperty(x::EarthMagnetic, name::Symbol)
    if name == :x
        return LibCasacore.getValue(x.m, 0)::Float64 * U.nT
    elseif name == :y
        return LibCasacore.getValue(x.m, 1)::Float64 * U.nT
    elseif name == :z
        return LibCasacore.getValue(x.m, 2)::Float64 * U.nT
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::EarthMagnetic, name::Symbol, v)
    if name == :x
        x.cache[1] = ustrip(Float64, U.nT, v)
        x.cache[2] = ustrip(Float64, U.nT, x.y)
        x.cache[3] = ustrip(Float64, U.nT, x.z)
        _setdata!(x, x.cache)
    elseif name == :y
        x.cache[1] = ustrip(Float64, U.nT, x.x)
        x.cache[2] = ustrip(Float64, U.nT, v)
        x.cache[3] = ustrip(Float64, U.nT, x.z)
        _setdata!(x, x.cache)
    elseif name == :z
        x.cache[1] = ustrip(Float64, U.nT, x.x)
        x.cache[2] = ustrip(Float64, U.nT, x.y)
        x.cache[3] = ustrip(Float64, U.nT, v)
        _setdata!(x, x.cache)
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MEarthMagnetic!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MEarthMagnetic!Convert(Int(in), ref)
    )
end

end