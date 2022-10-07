module Measures

using Unitful

using ..LibCasacore
using ..LibCasacore.DirectionTypes
using ..LibCasacore.EpochTypes
using ..LibCasacore.PositionTypes

export long, lat, radius, days

abstract type Measure end

struct Direction <: Measure
    cxx_object::LibCasacore.MDirectionAllocated
end

function Direction(
    type::DirectionTypes.Types, angle1::Quantity, angle2::Quantity;
    offset::Union{Nothing, Direction}=nothing
)
    mdirection = LibCasacore.MDirection(
        LibCasacore.MVDirection(
            LibCasacore.Quantity(
                ustrip(u"rad", angle1), LibCasacore.String("rad")
            ),
            LibCasacore.Quantity(
                ustrip(u"rad", angle2), LibCasacore.String("rad")
            )
        ),
        type
    )

    if offset !== nothing
        mdirection.setOffset(offset.mdirection)
    end

    return Direction(mdirection)
end

long(x::Direction) = LibCasacore.getLong(LibCasacore.getValue(x.cxx_object)) * Unitful.rad
lat(x::Direction) = LibCasacore.getLat(LibCasacore.getValue(x.cxx_object)) * Unitful.rad

function Base.show(io::IO, x::Direction)
    write(io, "Direction($(reference(x)), $(long(x)), $(lat(x)))")
end

struct Epoch <: Measure
    cxx_object::LibCasacore.MEpochAllocated
end

function Epoch(
    type::EpochTypes.Types, duration::Quantity;
    offset::Union{Nothing, Epoch}=nothing
)
    mepoch = LibCasacore.MEpoch(
        LibCasacore.MVEpoch(
            LibCasacore.Quantity(
                ustrip(u"d", duration), LibCasacore.String("d")
            )
        ),
        type
    )

    if offset !== nothing
        mepoch.setOffset(offset.cxx_object)
    end

    return Epoch(mepoch)
end

days(x::Epoch) = LibCasacore.get(LibCasacore.getValue(x.cxx_object)) * Unitful.d

function Base.show(io::IO, x::Epoch)
    write(io, "Epoch($(reference(x)), $(days(x)))")
end

struct Position <: Measure
    cxx_object::LibCasacore.MPositionAllocated
end

function Position(
    type::PositionTypes.Types, r::Quantity, long::Quantity, lat::Quantity;
    offset::Union{Nothing, Position}=nothing
)
    mposition = LibCasacore.MPosition(
        LibCasacore.MVPosition(
            LibCasacore.Quantity(
                ustrip(u"m", r), LibCasacore.String("m")
            ),
            LibCasacore.Quantity(
                ustrip(u"rad", long), LibCasacore.String("rad")
            ),
            LibCasacore.Quantity(
                ustrip(u"rad", lat), LibCasacore.String("rad")
            ),
        ),
        type
    )

    if offset !== nothing
        mposition.setOffset(offset.cxx_object)
    end

    return Position(mposition)
end

radius(x::Position) = LibCasacore.getValue(
    LibCasacore.getLength(
        LibCasacore.getValue(x.cxx_object),
        LibCasacore.Unit(LibCasacore.String("m"))
))[] * Unitful.m
long(x::Position) = LibCasacore.getLong(LibCasacore.getValue(x.cxx_object)) * Unitful.rad
lat(x::Position) = LibCasacore.getLat(LibCasacore.getValue(x.cxx_object)) * Unitful.rad

function Base.show(io::IO, x::Position)
    write(io, "Position($(reference(x)), $(radius(x)), $(long(x)), $(lat(x)))")
end

for m in (:Direction, :Epoch, :Position)
    mtype = Symbol(m, "Types")
    mconvert = Symbol("M", m, "!Convert")
    mref = Symbol("M", m, "!Ref")

    @eval begin
        reference(x::$m) = Symbol(LibCasacore.getRefString(x.cxx_object))

        function $m(type::$mtype.Types, direction::$m, measures::Vararg{Measure})
            return $m(
                copy(
                    LibCasacore.$mconvert(
                        direction.cxx_object,
                        LibCasacore.$mref(
                            type,
                            LibCasacore.MeasFrame((m.cxx_object for m in measures)...)
                        )
                    )()
                )
            )
        end
    end
end

end