using ExplicitImports
using SciMLLogging
using Test

@testset "ExplicitImports" begin
    @test check_no_implicit_imports(SciMLLogging) === nothing
    @test check_no_stale_explicit_imports(SciMLLogging) === nothing
end
