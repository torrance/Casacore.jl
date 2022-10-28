module Baselines

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
    N_Type
end

# Defaults
const DEFAULT=ITRF
# Synonyms
const AZELNE=AZEL
const AZELNEGEO=AZELGEO

mutable struct Baseline <: AbstractMeasure
    type::Types
    m::LibCasacore.MBaselineAllocated
    mv::LibCasacore.MVBaselineAllocated
    cache::Vector{Float64}
end

function Baseline(type::Types, x::U.Length, y::U.Length, z::U.Length, measures::AbstractMeasure...; offset::Union{Nothing, Baseline}=nothing)
    ref = LibCasacore.MBaseline!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    value = LibCasacore.MVBaseline(
        ustrip(Float64, U.m, x), ustrip(Float64, U.m, y), ustrip(Float64, U.m, z)
    )
    measure = LibCasacore.MBaseline(value, ref)

    return Baseline(type, measure, value, zeros(3))
end

Base.zero(::Type{Baseline}) = Baseline(DEFAULT, 0 * U.m, 0 * U.m, 0 * U.m)

function Base.propertynames(x::Baseline, private::Bool=false)
    return (:type, :x, :y, :z)
end

function Base.getproperty(x::Baseline, name::Symbol)
    if name == :x
        return LibCasacore.getValue(x.m, 0)::Float64 * U.m
    elseif name == :y
        return LibCasacore.getValue(x.m, 1)::Float64 * U.m
    elseif name == :z
        return LibCasacore.getValue(x.m, 2)::Float64 * U.m
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::Baseline, name::Symbol, v)
    if name == :x
        x.cache[1] = ustrip(Float64, U.m, v)
        x.cache[2] = ustrip(Float64, U.m, x.y)
        x.cache[3] = ustrip(Float64, U.m, x.z)
        _setdata!(x, x.cache)
    elseif name == :y
        x.cache[1] = ustrip(Float64, U.m, x.x)
        x.cache[2] = ustrip(Float64, U.m, v)
        x.cache[3] = ustrip(Float64, U.m, x.z)
        _setdata!(x, x.cache)
    elseif name == :z
        x.cache[1] = ustrip(Float64, U.m, x.x)
        x.cache[2] = ustrip(Float64, U.m, x.y)
        x.cache[3] = ustrip(Float64, U.m, v)
        _setdata!(x, x.cache)
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MBaseline!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MBaseline!Convert(Int(in), ref)
    )
end

end