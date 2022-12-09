using Casacore.Tables
using Casacore.Measures
using Casacore.LibCasacore
using Test

using Unitful

@testset "Casacore.jl" begin
    @testset "Measures" begin
        @testset "Direction conversion J2000 to AZEL (and back again)" begin
            direction = Measures.Direction(Measures.Directions.J2000, (π)u"rad", π/2u"rad")
            show(devnull, direction)

            # Getters/setters
            @test (direction.long -= π/4u"rad") ≈ 3π/4u"rad"
            @test direction.long ≈ 3π/4u"rad"
            @test (direction.lat -= π/2u"rad") ≈ 0u"rad"
            @test direction.lat ≈ 0u"rad"

            # Create reference frame measures
            pos = Measures.Position(Measures.Positions.ITRF, 1000u"m", 0u"m", 0u"m")
            t = Measures.Epoch(Measures.Epochs.UTC, 1234567u"d")

            show(devnull, t)
            show(devnull, pos)

            # Getters/setters
            @test (pos.x += 1u"km") == 2000u"m"
            @test pos.x == 2u"km"
            @test (pos.y += 3u"m") == 3u"m"
            @test pos.y == 3u"m"
            @test (pos.z += 5u"m") == 5u"m"
            @test pos.z == 5u"m"

            @test (t.time += 1u"d") == 1234568u"d"
            @test t.time == 1234568u"d"

            directionAZEL = mconvert(Measures.Directions.AZEL, direction, t, pos)
            @test directionAZEL.type == Measures.Directions.AZEL
            @test !isapprox(directionAZEL.lat , 0u"rad", atol=1e-4)  # Check that the conversion does something
            @test !isapprox(directionAZEL.long, 3π/4u"rad", atol=1e-4)

            @test isapprox(direction, mconvert(Measures.Directions.J2000, directionAZEL, t, pos), atol=1e-6)

            direction.type = Measures.Directions.B1950
            @test direction.type == Measures.Directions.B1950
            @test LibCasacore.getType(LibCasacore.getRef(direction.m)) == Int(Measures.Directions.B1950)
        end

        @testset "Frequency conversion REST to LSRD" begin
            freq = Measures.Frequency(Measures.Frequencies.REST, 1_420_405_752u"Hz")
            show(devnull, freq)

            @test (freq.freq +=1u"Hz") == 1_420_405_753u"Hz"
            @test freq.freq == 1_420_405_753u"Hz"

            direction = Measures.Direction(Measures.Directions.J2000, 0u"rad", π/2u"rad")
            velocity = Measures.RadialVelocity(Measures.RadialVelocities.LSRD, 20_000u"km/s", direction)
            show(devnull, velocity)

            @test (velocity.velocity += 1u"m/s") == 20_000_001u"m/s"
            @test velocity.velocity == 20_000_001u"m/s"

            freqLSRD = mconvert(Measures.Frequencies.LSRD, freq, velocity, direction)
            @test freqLSRD.freq != 1_420_405_753u"Hz"  # Check that the conversion does something

            @test freq ≈ mconvert(Measures.Frequencies.REST, freqLSRD, velocity, direction)
        end

        @testset "EarthMagnetic conversion ITRF to AZEL" begin
            # Load position by observatory name
            @test :MWA32T ∈ Measures.Positions.observatories()
            pos = Measures.Position(:MWA32T)
            @test pos.type == Measures.Positions.WGS84
            time = Measures.Epoch(Measures.Epochs.DEFAULT, 59857u"d")

            bfield = Measures.EarthMagnetic(Measures.EarthMagnetics.DEFAULT, -1u"T", -1u"T", -1u"T")

            @test (bfield.x += 1u"T") == 0u"T"
            @test bfield.x == 0u"T"
            @test (bfield.y += 2u"T") == 1u"T"
            @test bfield.y == 1u"T"
            @test (bfield.z += 5u"T") == 4u"T"
            @test bfield.z == 4u"T"

            bfield = mconvert(Measures.EarthMagnetics.AZEL, bfield, pos, time)
            @test 10_000u"nT" < hypot(bfield.x, bfield.y, bfield.z) < 100_000u"nT"  # A reasonable range
        end

        @testset "Baseline conversion from ITRF to J2000 to UVW" begin
            # Use alternative (r, long, lat) constructor for Position
            refpos = Measures.Position(Measures.Positions.ITRF, 6378.1u"km", 37u"°", -23u"°")
            @test radius(refpos) ≈ 6378.1u"km"
            @test long(refpos) ≈ 37u"°"
            @test lat(refpos) ≈ -23u"°"

            time = Measures.Epoch(Measures.Epochs.DEFAULT, 59857u"d")
            refdirection = Measures.Direction(Measures.Directions.J2000, 27u"°", 25u"°")

            baseline = Measures.Baseline(Measures.Baselines.ITRF, 1u"km", 1u"km", 1u"km")

            @test (baseline.x += 2u"km") == 3u"km"
            @test baseline.x == 3u"km"
            @test (baseline.y += 1u"km") == 2u"km"
            @test baseline.y == 2u"km"
            @test (baseline.z -= 2u"km") == -1u"km"
            @test baseline.z == -1u"km"

            length = hypot(baseline.x, baseline.y, baseline.z)

            # Why is refdirection needed for Baseline conversion? It has no effect.
            baseline = mconvert(Measures.Baselines.J2000, baseline, refdirection, refpos, time)
            @test hypot(baseline.x, baseline.y, baseline.z) ≈ length

            uvw = Measures.UVW(Measures.UVWs.J2000, baseline, refdirection)
        end

        @testset "Doppler conversions" begin
            doppler = Measures.Doppler(Measures.Dopplers.RADIO, 20_000u"km/s")
            @test (doppler.doppler = 2) == 2
            @test doppler.doppler == 2

            doppler = Measures.Doppler(Measures.Dopplers.Z, 0.023)
            doppler = mconvert(Measures.Dopplers.RADIO, doppler)
            @test doppler.doppler == 1 - 1/(0.023 + 1)
            doppler = mconvert(Measures.Dopplers.BETA, doppler)

            # Doppler <-> Frequency
            freq = Measures.Frequency(Measures.Frequencies.LSRD, doppler, 1420u"MHz")
            @test LibCasacore.getType(LibCasacore.getRef(freq.m)) == Int(freq.type)
            doppleragain = Measures.Doppler(freq, 1420u"MHz")
            @test LibCasacore.getType(LibCasacore.getRef(doppleragain.m)) == Int(doppleragain.type)
            @test doppler ≈ doppleragain

            # Doppler <-> RadialVelocity
            rv = Measures.RadialVelocity(Measures.RadialVelocities.LSRD, doppler)
            @test rv.type == Measures.RadialVelocities.LSRD
            doppleragain = Measures.Doppler(rv)
            @test doppler ≈ doppleragain
        end
    end

    @testset "Tables" begin
        local table::Tables.Table

        @testset "Create table" begin
            table = Tables.Table(joinpath(mktempdir(), "test.ms"), Tables.Scratch)
            @test size(table) == (0, 0)
        end

        @testset "Add/remove rows" begin
            resize!(table, 10_000)
            @test size(table, 1) == 10_000

            deleteat!(table, 1:2:10_000)
            @test size(table, 1) == 5_000

            deleteat!(table, 1)
            @test size(table, 1) == 4_999

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

                @testset "Empty index" begin
                    column = table[:SCALAR]
                    @test column[] == column[:]
                    vals = rand(1_000)
                    column[] = vals
                    @test column[] == vals
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

                @testset "Empty index" begin
                    column = table[:ARR_UNKNOWN]
                    @test column[] == column[:]
                    vals = fill(rand(ComplexF64, 2, 3), 1_000)
                    column[] = vals
                    @test column[] == vals
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

                @testset "Empty index" begin
                    column = table[:ARR_NOSHAPE]
                    @test column[] == column[:]
                    vals = fill(rand(Int32, 2, 2), 1_000)
                    column[] = vals
                    @test column[] == vals
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

                @testset "Empty index" begin
                    column = table[:ARR]
                    @test column[] == column[:, :, :]
                    vals = rand(Int16, 3, 4, 1_000)
                    column[] = vals
                    @test column[] == vals
                end

                @testset "fill!()" begin
                    column = table[:ARR]
                    fill!(column, 3)
                    @test all(column[:, :, :] .== 3)
                    @test_throws MethodError fill!(column, ones(3, 4))
                    @test_throws MethodError fill!(column, [1, 2, 3, 4])
                end
            end
        end

        @testset "Cxx <-> Julia type conversions" begin
            @testset "Bool" begin
                table[:BOOL] = Tables.ArrayColumnDesc{Bool, 2}()
                column = table[:BOOL]
                fill!(column, [true false; true false])
                @test column[33] == [true false; true false]
                column[33] = [false false; false true]
                @test column[33] == [false false; false true]
            end

            @testset "Int64" begin
                table[:INT64] = Tables.ArrayColumnDesc{Int64, 2}((2, 3))
                column = table[:INT64]
                fill!(column, 6)
                @test column[1, 3, 33] == 6
                val = rand(Int64, 2, 3)
                column[:, :, 33] = val
                @test column[:, :, 33] == val
            end
        end

        @testset "Strings" begin
            @testset "Scalar columns" begin
                table[:STRING] = fill("Oh hi there", 1_000)::Vector{String}
                column = table[:STRING]
                @test column[4] == "Oh hi there"
                column[4] = "Goodbye"
                @test column[4] == "Goodbye"
                column[50:149] = collect("Well well well" for _ in 1:100)
                @test column[50:149] == collect("Well well well" for _ in 1:100)
                fill!(column, "How are you?")
                column[:] == fill("How are you?", 100)
                @test begin
                    vals = fill("How are you", 1_000)
                    column[] = vals
                    column[] == vals
                end
            end

            @testset "Unknown dimension columns" begin
                table[:STRING] = rand([["Oh";;], ["Hi";;;]], 1_000)::Vector{Array{String}}
                column = table[:STRING]
                @test column[4] == ["Oh";;] || column[4] == ["Hi";;;]
                column[4] = ["Goodbye"]
                @test column[4] == ["Goodbye"]
                column[4] = fill("Oh hi", 3, 2)
                @test column[4] == fill("Oh hi", 3, 2)
                column[50:149] = (["Well well well", "And here they come"] for _ in 1:100)
                @test column[50:149] == fill(["Well well well", "And here they come"], 100)
                @test column[1, 50:149] == fill("Well well well", 100)
                fill!(column, ["I'm" "just"; "fine" "thanks"])
                @test all(column[:] .== [["I'm" "just"; "fine" "thanks"]])
                @test begin
                    vals = fill(["How are you";;], 1_000)
                    column[] = vals
                    column[] == vals
                end
            end

            @testset "Known dimension columns" begin
                table[:STRING] = fill(["Oh" "hi"; "there" "dear"], 1_000)::Vector{Matrix{String}}
                column = table[:STRING]
                @test column[4] == ["Oh" "hi"; "there" "dear"]
                @test_throws DimensionMismatch column[4] = ["Goodbye"]
                column[4] = ["Goodbye" "we"; "never" "were"]
                @test column[4] == ["Goodbye" "we"; "never" "were"]
                vals = fill(["The" "Very"; "Last" "End"], 100)
                column[50:149] = vals
                @test column[50:149] == vals
                @test all(column[2, 1:2, 50:149] .== ["Last"; "End";;])
                fill!(column, ["I'm" "just"; "fine" "thanks"])
                @test all(column[:] .== [["I'm" "just"; "fine" "thanks"]])
                @test begin
                    vals = fill(["Oh" "how"; "are" "you"], 1_000)
                    column[] = vals
                    column[] == vals
                end
            end

            @testset "Fixed array columns" begin
                table[:STRING] = fill("Hi", 3, 2, 1_000)
                column = table[:STRING]
                @test column[:, :, 4] == fill("Hi", 3, 2)
                @test_throws DimensionMismatch column[:, :, 4] = ["Goodbye"]
                column[:, :, 4] = ["Goodbye" "we"; "never" "were"; "really" "here"]
                @test column[:, :, 4] == ["Goodbye" "we"; "never" "were"; "really" "here"]
                @test column[:, 1, 4] == ["Goodbye", "never", "really"]
                fill!(column, "Boop")
                @test all(column[:, :, :] .== fill("Boop", 1, 1, 1))
                @test begin
                    vals = fill("Bye bye bye", 3, 2, 1_000)
                    column[] = vals
                    column[] == vals
                end
            end
        end

        @testset "Delete columns" begin
            for colname in [:SCALAR, :ARR_UNKNOWN, :ARR_NOSHAPE, :ARR, :STRING]
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
