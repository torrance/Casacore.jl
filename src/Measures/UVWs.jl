module UVWs

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..Measures.Baselines: Baseline
using ..Measures.Directions: Direction
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
end

# Defaults
const DEFAULT=ITRF
# Synonyms
const AZELNE=AZEL
const AZELNEGEO=AZELGEO

mutable struct UVW <: AbstractMeasure
    type::Types
    m::LibCasacore.MuvwAllocated
    mv::LibCasacore.MVuvwAllocated
    cache::Vector{Float64}
end

function UVW(type::Types, u::U.Length, v::U.Length, w::U.Length, measures::AbstractMeasure...; offset::Union{Nothing, UVW}=nothing)
    ref = LibCasacore.Muvw!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    value = LibCasacore.MVuvw(
        ustrip(Float64, U.m, u), ustrip(Float64, U.m, v), ustrip(Float64, U.m, w)
    )
    measure = LibCasacore.Muvw(value, ref)

    return UVW(type, measure, value, zeros(3))
end

Base.zero(::Type{UVW}) = UVW(DEFAULT, 0 * U.m, 0 * U.m, 0 * U.m)

# REMOVED: This is an expensive method to do what is just a matrix multiplication
# # Special constructor for uvw from a baseline and direction
# # Baseline and direction must be in the same frame as their values are used directly
# function UVW(type::Types, baseline::Baseline, dir::Direction, EW::Bool=false)
#     value = LibCasacore.MVuvw(
#        LibCasacore.getValue(baseline.m), LibCasacore.getValue(dir.m), EW
#     )
#     measure = LibCasacore.Muvw(value)
#     return UVW(type, measure, value, zeros(3))
# end

function Base.propertynames(x::UVW, private::Bool=false)
    return (:type, :u, :v, :w)
end

function Base.getproperty(x::UVW, name::Symbol)
    if name == :u
        return LibCasacore.getValue(x.m, 0)::Float64 * U.m
    elseif name == :v
        return LibCasacore.getValue(x.m, 1)::Float64 * U.m
    elseif name == :w
        return LibCasacore.getValue(x.m, 2)::Float64 * U.m
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::UVW, name::Symbol, v)
    if name == :u
        x.cache[1] = ustrip(Float64, U.m, v)
        x.cache[2] = ustrip(Float64, U.m, x.v)
        x.cache[3] = ustrip(Float64, U.m, x.w)
        _setdata!(x, x.cache)
    elseif name == :v
        x.cache[1] = ustrip(Float64, U.m, x.u)
        x.cache[2] = ustrip(Float64, U.m, v)
        x.cache[3] = ustrip(Float64, U.m, x.w)
        _setdata!(x, x.cache)
    elseif name == :w
        x.cache[1] = ustrip(Float64, U.m, x.u)
        x.cache[2] = ustrip(Float64, U.m, x.v)
        x.cache[3] = ustrip(Float64, U.m, v)
        _setdata!(x, x.cache)
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.Muvw!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.Muvw!Convert(Int(in), ref)
    )
end

function Converter(in::UVW, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.Muvw!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in.type, out, LibCasacore.Muvw!Convert(in.m, ref)
    )
end

end