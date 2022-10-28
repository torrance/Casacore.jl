module RadialVelocities

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    LSRK
    LSRD
    BARY
    GEO
    TOPO
    GALACTO
    LGROUP
    CMB
    N_Types
end

# Defaults
const DEFAULT=LSRK
# Synonyms
const LSR=LSRK

mutable struct RadialVelocity <: AbstractMeasure
    type::Types
    m::LibCasacore.MRadialVelocityAllocated
    mv::LibCasacore.MVRadialVelocityAllocated
    cache::Vector{Float64}
end

function RadialVelocity(type::Types, v::U.Velocity, measures::AbstractMeasure...; offset::Union{Nothing, RadialVelocity}=nothing)
    ref = LibCasacore.MRadialVelocity!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.m)
    end

    value = LibCasacore.MVRadialVelocity(ustrip(Float64, U.m / U.s, v))
    measure = LibCasacore.MRadialVelocity(value, ref)

    return RadialVelocity(type, measure, value, zeros(1))
end

Base.zero(::Type{RadialVelocity}) = RadialVelocity(DEFAULT, 0 * U.m / U.s)

function Base.propertynames(x::RadialVelocity, private::Bool=false)
    return (:type, :velocity)
end

function Base.getproperty(x::RadialVelocity, name::Symbol)
    if name == :velocity
        return LibCasacore.getValue(x.m, 0)::Float64 * (U.m / U.s)
    else
        return getfield(x, name)
    end
end

function Base.setproperty!(x::RadialVelocity, name::Symbol, v)
    if name == :velocity
        x.cache[] = ustrip(Float64, U.m / U.s, v)
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
    ref = LibCasacore.MRadialVelocity!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MRadialVelocity!Convert(Int(in), ref)
    )
end

function Converter(in::RadialVelocity, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MRadialVelocity!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in.type, out, LibCasacore.MRadialVelocity!Convert(in.m, ref)
    )
end

end