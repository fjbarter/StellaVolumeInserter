# Shared I/O and independent checks; experimental parameters stay in each run.jl.
using Stella, Random, LinearAlgebra, Printf, TOML, WriteVTK, StaticArrays
import StellaGmsh as G
include("validation/geometry.jl")
include("tables.jl")
include("exports.jl")
include("geometry.jl")
include("execution.jl")
include("points.jl")
