using Test
using SafeTestsets

@time @safetestset "Basic Tests" include("basics.jl")
@time @safetestset "Verbosity Specifier Generation Tests" include("generation_test.jl")
@time @safetestset "Explicit Imports" include("explicit_imports.jl")
