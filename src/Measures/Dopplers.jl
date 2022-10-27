module Dopplers

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    RADIO
    Z
    RATIO
    BETA
    GAMMA
    N_Types
end

const OPTICAL=Z
const RELATIVISTIC=BETA
const DEFAULT=RADIO

mutable struct Doppler <: AbstractMeasure
    type::Types
    m::LibCasacore.MDopplerAllocated
    mv::LibCasacore.MVDopplerAllocated
    cache::Vector{Float64}
end

function Doppler(
    type::Types, v::Union{U.Velocity, Real}, measures::AbstractMeasure...;
    offset::Union{Nothing, Doppler}=nothing
)
    ref = LibCasacore.MDoppler!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.cxx_wrap)
    end

    # Doppler value may either be a fraction of c, or a velocity.
    # Internal value is a fraction of c.
    if typeof(v) <: U.Velocity
        v = ustrip(Float64, (U.m/U.s) / (U.m/U.s), v / U.c0)
    end

    value = LibCasacore.MVDoppler(v)
    measure = LibCasacore.MDoppler(value, ref)

    return Doppler(type, measure, value, zeros(1))
end

function Base.propertynames(x::Doppler, private::Bool=false)
    return (:type, :doppler)
end

function Base.getproperty(x::Doppler, name::Symbol)
    if name == :doppler
        return LibCasacore.getValue(x.m, 0)::Float64
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::Doppler, name::Symbol, v)
    if name == :doppler
        if typeof(v) <: U.Velocity
            v = ustrip(Float64, (U.m/U.s) / (U.m/U.s), v / U.c0)
        end
        x.cache[] = v
        _setdata!(x, x.cache)
    else
        setfield!(x, name, v)
    end
    return nothing
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MDoppler!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MDoppler!Convert(Int(in), ref)
    )
end

end