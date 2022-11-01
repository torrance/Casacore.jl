module Positions

using CEnum
using Unitful: Unitful as U, ustrip

using ..Measures: AbstractMeasure, _setdata!, Converter
using ..LibCasacore

@cenum Types begin
    ITRF
    WGS84
    N_Types
end

const DEFAULT = ITRF

mutable struct Position <: AbstractMeasure
    type::Types
    m::LibCasacore.MPositionAllocated
    mv::LibCasacore.MVPositionAllocated
    cache::Vector{Float64}
end

function Position(type::Types, x::U.Length, y::U.Length, z::U.Length, measures::AbstractMeasure...; offset::Union{Nothing, Position}=nothing)
    ref = LibCasacore.MPosition!Ref(
        Int(type), LibCasacore.MeasFrame((m.m for m in measures)...)
    )
    if offset !== nothing
        LibCasacore.set(ref, offset.m)
    end

    value = LibCasacore.MVPosition(
        ustrip(Float64, U.m, x), ustrip(Float64, U.m, y), ustrip(Float64, U.m, z)
    )
    measure = LibCasacore.MPosition(value, ref)

    return Position(type, measure, value, zeros(3))
end

function Position(
    type::Types, r::U.Length, long::U.DimensionlessQuantity, lat::U.DimensionlessQuantity, measures::AbstractMeasure...;
    offset::Union{Nothing, Position}=nothing
)
    return Position(
        type, r * cos(lat) * cos(long), r * cos(lat) * sin(long), r * sin(lat), measures...;
        offset
    )
end

Base.zero(::Type{Position}) = Position(DEFAULT, 0 * U.m, 0 * U.m, 0 * U.m)

function Base.propertynames(x::Position, private::Bool=false)
    return (:type, :x, :y, :z)
end

function Base.getproperty(x::Position, name::Symbol)
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

function Base.setproperty!(x::Position, name::Symbol, v)
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
    elseif name === :type
        setfield!(x, :type, v)
        LibCasacore.setType(x.m, Int(v))
    else
        setfield!(x, name, v)
    end
    return nothing
end

function radius(d::Position)
    return hypot(LibCasacore.getValue.((d.m,), (0, 1, 2))...) * U.m
end

function long(d::Position)
    x, y = LibCasacore.getValue(d.m, 0), LibCasacore.getValue(d.m, 1)
    return atan(y, x) * U.rad
end

function lat(d::Position)
    x, y, z = LibCasacore.getValue.((d.m,), (0, 1, 2))
    return asin(z / hypot(x, y, z)) * U.rad
end

function Converter(in::Types, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MPosition!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in, out, LibCasacore.MPosition!Convert(Int(in), ref)
    )
end

function Converter(in::Position, out::Types, measures::AbstractMeasure...)
    ref = LibCasacore.MPosition!Ref(
        Int(out), LibCasacore.MeasFrame((m.m for m in measures)...)
    )

    return Converter(
        in.type, out, LibCasacore.MPosition!Convert(in.m, ref)
    )
end

end