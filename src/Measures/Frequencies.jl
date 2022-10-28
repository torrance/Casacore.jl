module Frequencies

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    REST
    LSRK
    LSRD
    BARY
    GEO
    TOPO
    GALACTO
    LGROUP
    CMB
    N_Types
    Undefined = 64
    N_Other
end

# all extra bits
const EXTRA = 64
# Defaults
const DEFAULT=LSRK
# Synonyms
const LSR=LSRK

mutable struct Frequency <: AbstractMeasure
    type::Types
    m::LibCasacore.MFrequencyAllocated
    mv::LibCasacore.MVFrequencyAllocated
    cache::Vector{Float64}
end

function Frequency(type::Types, f::U.Frequency, measures::AbstractMeasure...; offset::Union{Nothing, Frequency}=nothing)
    ref = LibCasacore.MFrequency!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.m)
    end

    value = LibCasacore.MVFrequency(ustrip(Float64, U.Hz, f))
    measure = LibCasacore.MFrequency(value, ref)

    return Frequency(type, measure, value, zeros(1))
end

Base.zero(::Type{Frequency}) = Frequency(DEFAULT, 0 * U.Hz)

function Base.propertynames(x::Frequency, private::Bool=false)
    return (:type, :freq)
end

function Base.getproperty(x::Frequency, name::Symbol)
    if name == :freq
        return LibCasacore.getValue(x.m, 0)::Float64 * U.Hz
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::Frequency, name::Symbol, v)
    if name == :freq
        x.cache[] = ustrip(Float64, U.Hz, v)
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
    ref = LibCasacore.MFrequency!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MFrequency!Convert(Int(in), ref)
    )
end

function Converter(in::Frequency, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MFrequency!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in.type, out, LibCasacore.MFrequency!Convert(in.m, ref)
    )
end

end