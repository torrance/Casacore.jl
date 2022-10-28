module Epochs

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    # Local Apparent Sidereal Time
    LAST
    # Local Mean Sidereal Time
    LMST
    # Greenwich Mean ST1
    GMST1
    # Greenwich Apparent ST
    GAST
    UT1
    UT2
    UTC
    TAI
    TDT
    TCG
    TDB
    TCB
    # Number of types
    N_Types
    # Reduce result to integer days
    RAZE = 32
end

# All extra bits
const EXTRA = RAZE
# Synonyms
const IAT = TAI
const GMST = GMST1
const TT = TDT
const UT = UT1
const ET = TT
# Default
const DEFAULT = UTC

mutable struct Epoch <: AbstractMeasure
    type::Types
    m::LibCasacore.MEpochAllocated
    mv::LibCasacore.MVEpochAllocated
    cache::Vector{Float64}
end

function Epoch(type::Types, t::U.Time, measures::AbstractMeasure...; offset::Union{Nothing, Epoch}=nothing)
    ref = LibCasacore.MEpoch!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    value = LibCasacore.MVEpoch(ustrip(Float64, U.d, t))
    measure = LibCasacore.MEpoch(value, ref)

    return Epoch(type, measure, value, zeros(1))
end

Base.zero(::Type{Epoch}) = Epoch(DEFAULT, 0 * U.s)

function Base.propertynames(x::Epoch, private::Bool=false)
    return (:type, :time)
end

function Base.getproperty(x::Epoch, name::Symbol)
    if name == :time
        return LibCasacore.getValue(x.m, 0)::Float64 * U.d
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::Epoch, name::Symbol, v)
    if name == :time
        x.cache[] = ustrip(Float64, U.d, v)
        _setdata!(x, x.cache)
    elseif name === :type
        setfield!(x, :type, v)
        LibCasacore.setType(x.m, Int(v))
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MEpoch!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MEpoch!Convert(Int(in), ref)
    )
end

function Converter(in::Epoch, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MEpoch!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in.type, out, LibCasacore.MEpoch!Convert(in.m, ref)
    )
end

end