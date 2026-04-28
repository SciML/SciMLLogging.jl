using Pkg
using Test
using SafeTestsets

const GROUP = get(ENV, "GROUP", "All")

function activate_env(dir)
    Pkg.activate(dir)
    Pkg.develop(PackageSpec(path = dirname(@__DIR__)))
    return Pkg.instantiate()
end

if GROUP == "Core" || GROUP == "All"
    @time @safetestset "Basic Tests" include("basics.jl")
    @time @safetestset "Verbosity Specifier Generation Tests" include("generation_test.jl")
    @time @safetestset "Explicit Imports" include("explicit_imports.jl")
end

if (GROUP == "NoPre" || GROUP == "All") && isempty(VERSION.prerelease)
    activate_env("nopre")
    @time @safetestset "JET" include("nopre/jet.jl")
end

if GROUP == "Downstream"
    activate_env("downstream")
    @time @safetestset "Downstream solve JET" include("downstream/solve_jet.jl")
end
