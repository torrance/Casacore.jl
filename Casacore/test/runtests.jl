using Casacore.Tables
using Casacore.Measures
using Test

using Unitful

@testset "Casacore.jl" begin
    @testset "Measures" begin
        pos = Measures.Position(Measures.PositionTypes.ITRF, 1u"km", 0u"rad", 0u"rad")
        time = Measures.Epoch(Measures.EpochTypes.UTC, 1234567u"d")
        direction = Measures.Direction(Measures.DirectionTypes.J2000, 0u"rad", 0u"rad")
        direction = mconvert(direction, Measures.DirectionTypes.AZEL, pos, time)
        @test typeof(direction) <: Measures.Direction
    end

    @testset "Tables" begin
        local table::Tables.Table

        @testset "Create table" begin
            table = Tables.Table(joinpath(mktempdir(), "test.ms"), Tables.TableOptions.Scratch)
            @test size(table) == (0, 0)
        end

        @testset "Add/remove rows" begin
            resize!(table, 10_000)
            @test size(table, 1) == 10_000

            deleteat!(table, 1:2:10_000)
            @test size(table, 1) == 5_000

            resize!(table, 1_000)
            @test size(table, 1) == 1_000
        end

        @testset "Add/remove subtables" begin
            # Create subtable with antenna poitions
            antennas = Tables.Table()
            resize!(antennas, 128)
            antennas[:ID] = collect(1:128)
            antennas[:X] = rand(128)
            antennas[:Y] = rand(128)
            antennas[:Z] = rand(128)

            table.ANTENNA = antennas
            @test :ANTENNA ∈ propertynames(table)
            @test typeof(table.ANTENNA[:ID]) <: Tables.Column{Int, 1}

            # This test fails with error:
            # "Cannot be deleted: table is still open in this process"
            @test_skip begin
                delete!(table, :ANTENNA)
                :ANTENNA ∉ propertynames(table)
            end
        end

        @testset "Scalar column" begin
            @testset "Add column" begin
                # Explicitly
                table[:SCALAR] = Tables.ScalarColumnDesc{Bool}(
                    comment="I am a scalar column"
                )
                @test :SCALAR ∈ keys(table)
                @test typeof(table[:SCALAR]) <: Tables.Column{Bool, 1}
                @test size(table[:SCALAR]) == (1_000,)
                @test length(table[:SCALAR]) == 1_000

                # Implcitly, and replace existing column
                table[:SCALAR] = rand(1_000)
                @test typeof(table[:SCALAR]) <: Tables.Column{Float64, 1}
            end

            @testset "Indexing" begin
                @testset "Single read/write" begin
                    column = table[:SCALAR]
                    @test typeof(column[1]) <: Float64
                    column[45] = 1.23456
                    @test column[45] == 1.23456
                    column[45] = 1::Int  # cast
                    @test column[45] == 1
                    @test_throws InexactError column[45] = 1 + 1im
                    @test_throws BoundsError column[2_000]
                    @test_throws MethodError column[3, 100]
                    @inferred column[1]
                end

                @testset "Range read/write" begin
                    column = table[:SCALAR]
                    column[200:299] = 1:100
                    @test column[200:299] == 1:100
                    @test_throws DimensionMismatch column[200:299] = 1:101
                    @test_throws BoundsError column[500:1_500]
                    @inferred column[10:20]
                end

                @testset "Colon read/write" begin
                    column = table[:SCALAR]
                    vals = rand(1_000)
                    column[:] = vals
                    @test column[:] == vals
                    @test_throws DimensionMismatch column[:] = 1:1001
                    @test_throws InexactError column[:] = rand(ComplexF64, 1_000)
                    @inferred column[:]
                end

                @testset "fill!()" begin
                    column = table[:SCALAR]
                    fill!(column, 2)
                    @test all(column[:] .== 2)
                    @test_throws MethodError fill!(column, [1, 2])
                end
            end
        end

        @testset "Array column with unknown dims" begin
            @testset "Add column" begin
                # Explicitly
                table[:ARR_UNKNOWN] = Tables.ArrayColumnDesc{UInt32}(
                    comment="I am a completely undefined column"
                )
                @test :ARR_UNKNOWN ∈ keys(table)
                @test typeof(table[:ARR_UNKNOWN]) <: Tables.Column{Array{UInt32}, 1}
                @test size(table[:ARR_UNKNOWN]) == (1_000,)
                @test length(table[:ARR_UNKNOWN]) == 1_000

                # Implicitly
                arr = Vector{Array{ComplexF64}}(undef, 1_000)
                fill!(arr, [])
                table[:ARR_UNKNOWN] = arr
                @test typeof(table[:ARR_UNKNOWN]) <: Tables.Column{Array{ComplexF64}, 1}
            end

            @testset "Indexing" begin
                @testset "Single read/write" begin
                    column = table[:ARR_UNKNOWN]
                    vals = rand(ComplexF64, 3)
                    column[45] = vals
                    @test column[45] == vals
                    vals = rand(Float64, 2, 3)
                    column[45] = vals # cast
                    @test column[45] == vals
                    column[45] = []
                    @test column[45] == []
                    @test_throws BoundsError column[1002]
                    @inferred Array{ComplexF64} column[32]
                end

                @testset "Range read/write" begin
                    column = table[:ARR_UNKNOWN]
                    vals = [rand(ComplexF64, rand([(3,), (2, 2), (1, 2, 1)])...) for _ in 1:100]
                    column[200:299] = vals
                    @test column[200:299] == vals
                    column[200:299] = [[i] for i in 1:100]
                    @test column[200:299] == [[i] for i in 1:100]
                    @test_throws DimensionMismatch column[200:299] = [[i] for i in 1:101]
                    @test_throws BoundsError column[500:1_500]
                    @inferred column[10:20]
                end

                @testset "Colon read/write" begin
                    column = table[:ARR_UNKNOWN]
                    vals = [rand(rand([(3,), (2, 2), (1, 2, 1)])...) for _ in 1:1000]
                    column[:] = vals
                    @test column[:] == vals
                    @test_throws DimensionMismatch column[:] = [rand(ComplexF64, rand([(3,), (2, 2), (1, 2, 1)])...) for _ in 1:100]
                    @inferred column[:]
                end

                @testset "fill!()" begin
                    column = table[:ARR_UNKNOWN]
                    fill!(column, [1, 2, 3])
                    @test all(column[:] .== ([1, 2, 3],))
                    fill!(column, 1)
                    @test all(column[:] .== ([1],))
                end

                @testset "Forced multidim index" begin
                    column = table[:ARR_UNKNOWN]
                    @test column[1, 500] == 1
                    @test typeof(column[1:1, :]) <: Array{ComplexF64, 2}
                    @test column[1:1, :] == ones(1, 1000)
                    @test_throws ArgumentError column[:, :]
                end
            end
        end

        @testset "Array column with unknown shape" begin
            @testset "Add column" begin
                # Explicitly
                table[:ARR_NOSHAPE] = Tables.ArrayColumnDesc{ComplexF64, 2}(
                    comment="I have 2 dimensions"
                )
                @test :ARR_NOSHAPE ∈ keys(table)
                @test typeof(table[:ARR_NOSHAPE]) <: Tables.Column{Array{ComplexF64, 2}, 1}
                @test size(table[:ARR_NOSHAPE]) == (1_000,)
                @test length(table[:ARR_NOSHAPE]) == 1_000

                # Implicitly
                arr = Vector{Array{Int32, 2}}(undef, 1_000)
                fill!(arr, ones(2, 2))
                table[:ARR_NOSHAPE] = arr
                @test typeof(table[:ARR_NOSHAPE]) <: Tables.Column{Array{Int32, 2}, 1}
            end

            @testset "Indexing" begin
                @testset "Single read/write" begin
                    column = table[:ARR_NOSHAPE]
                    vals = rand(Int32, 2, 2)
                    column[45] = vals
                    @test column[45] == vals
                    @test_throws BoundsError column[-2]
                    @test_throws DimensionMismatch column[45] = [1, 2, 3]
                    @test_throws DimensionMismatch column[2, 45]
                    @inferred column[32]
                end

                @testset "Range read/write" begin
                    column = table[:ARR_NOSHAPE]
                    vals = [rand(Int32, rand(0:6, 2)...) for _ in 1:100]
                    column[200:299] = vals
                    @test column[200:299] == vals
                    @test_throws DimensionMismatch column[200:299] = [rand(Int32, rand(0:6, 2)...) for _ in 1:101]
                    @test_throws DimensionMismatch column[200:299] = [rand(Int32, rand(0:6, 1)...) for _ in 1:100]
                    @test_throws InexactError column[200:299] = [rand(Float32, rand(0:6, 2)...) for _ in 1:100]
                    @test_throws BoundsError column[500:1_500]
                    @inferred column[10:20]
                end

                @testset "Colon read/write" begin
                    column = table[:ARR_NOSHAPE]
                    vals = [rand(Int32, rand(0:6, 2)...) for _ in 1:1000]
                    column[:] = vals
                    @test column[:] == vals
                    @test_throws DimensionMismatch column[:] = [rand(Int32, rand(0:6, 2)...) for _ in 1:100]
                    @inferred column[:]
                end

                @testset "fill!()" begin
                    column = table[:ARR_NOSHAPE]
                    fill!(column, [1 2; 3 4])
                    @test all(column[:] .== [[1 2; 3 4]])
                    @test_throws DimensionMismatch fill!(column, [1, 2, 3, 4])
                end

                @testset "Forced multidim index" begin
                    column = table[:ARR_NOSHAPE]
                    @test column[1, 2, 34] == 2
                    @test typeof(column[1:1, 1:2, :]) <: Array{Int32, 3}
                    @test all(eachslice(column[1:1, 1:2, :], dims=3) .== [[1 2]])
                    @test_throws DimensionMismatch column[:, :]
                end
            end
        end

        @testset "Array column with fixed shape" begin
            @testset "Add column" begin
                # Explicitly
                table[:ARR] = Tables.ArrayColumnDesc{Float32, 2}(
                    (2, 3), comment="I have 2 dimensions"
                )
                @test :ARR ∈ keys(table)
                @test typeof(table[:ARR]) <: Tables.Column{Float32, 3}
                @test size(table[:ARR]) == (2, 3, 1_000)
                @test length(table[:ARR]) == 2 * 3 * 1_000

                # Implicitly
                table[:ARR] = rand(Int16, 3, 4, 1_000)
                @test typeof(table[:ARR]) <: Tables.Column{Int16, 3}
                @test size(table[:ARR]) == (3, 4, 1_000)
            end

            @testset "Indexing" begin
                @testset "Single read/write" begin
                    column = table[:ARR]
                    column[2, 3, 45] = 3
                    @test column[2, 3, 45] == 3
                    @test_throws BoundsError column[4, 3, 45] = 2
                    @test_throws DimensionMismatch column[2, 3, 45] = [2, 3]
                    @test_throws DimensionMismatch column[3, 45]
                    @inferred column[2, 3, 32]
                end

                @testset "Range read/write" begin
                    column = table[:ARR]
                    vals = rand(Int16, 2, 2, 100)
                    column[2:3, 1:2, 1:100] = vals
                    @test column[2:3, 1:2, 1:100] == vals
                    @test_throws DimensionMismatch column[200:299]
                    @test_throws BoundsError column[2:4, 1:2, 1:100]
                    @test_throws DimensionMismatch column[2:3, 1:2, 1:100] = rand(Int16, 3, 2, 100)
                    @test_throws InexactError column[2:3, 1:2, 1:100] = rand(2, 2, 100)
                    @inferred column[2:3, 1:2, 1:100]
                end

                @testset "Colon read/write" begin
                    column = table[:ARR]
                    vals = rand(Int16, 3, 4, 10)
                    column[:, :, 1:10] = vals
                    @test column[:, :, 1:10] == vals
                    vals = rand(Int16, 1, 4, 1_000)
                    column[2, :, :] = vals
                    @test size(column[2, :, :]) == size(vals[1, :, :])
                    @test column[2, :, :] == vals[1, :, :]
                    @test_throws DimensionMismatch column[:]
                    @test_throws DimensionMismatch column[2, 3:4, :] = rand(Int16, 1_0000)
                    @inferred column[:, 2, :]
                end

                @testset "fill!()" begin
                    column = table[:ARR]
                    fill!(column, 3)
                    @test all(column[:, :, :] .== 3)
                    fill!(column, ones(3, 4))
                    @test all(column[:, :, :] .== 1)
                    @test_throws DimensionMismatch fill!(column, [1, 2, 3, 4])
                end
            end
        end

        @testset "Delete columns" begin
            for colname in [:SCALAR, :ARR_UNKNOWN, :ARR_NOSHAPE, :ARR]
                @test colname ∈ keys(table)
                delete!(table, colname)
                @test colname ∉ keys(table)
            end
        end
    end
end

# Force GC of table objects and their associated flush() to disk
# before tempdirs are removed
GC.gc(true)
