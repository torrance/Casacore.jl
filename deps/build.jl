using Pkg.Artifacts

# This is the path to the Artifacts.toml we will manipulate
artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

# create_artifact() returns the content-hash of the artifact directory once we're finished creating it
measures_hash = create_artifact() do artifact_dir
    download("ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar", joinpath(artifact_dir, "WSRT_Measures.ztar"))
    cd(artifact_dir) do
        run(`tar -xzf WSRT_Measures.ztar`)
        rm("WSRT_Measures.ztar", force=true)
    end
end

# Now bind that hash within our `Artifacts.toml`. `force = true` means that if it already exists,
# just overwrite with the new content-hash (this will happen whenever the Measures are updated.)
bind_artifact!(artifact_toml, "measures", measures_hash, force=true)