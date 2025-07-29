using SciMLVerbosity
using SciMLVerbosity: @match, Verbosity, AbstractVerbositySpecifier, @SciMLMessage
using Logging
using Test

# Structs for testing package
mutable struct TestOptionsVerbosity
    test1::Verbosity.Type
    test2::Verbosity.Type
    test3::Verbosity.Type
    test4::Verbosity.Type

    function TestOptionsVerbosity(;
            test1 = Verbosity.Warn(),
            test2 = Verbosity.Info(),
            test3 = Verbosity.Error(),
            test4 = Verbosity.None()
    )
        new(test1, test2, test3, test4)
    end

    function TestOptionsVerbosity(verbose::Verbosity.Type)
        @match verbose begin
            Verbosity.None() => new(fill(
                Verbosity.None(), length(fieldnames(TestOptionsVerbosity)))...)
            Verbosity.Info() => new(fill(
                Verbosity.Info(), length(fieldnames(TestOptionsVerbosity)))...)
            Verbosity.Warn() => new(fill(
                Verbosity.Warn(), length(fieldnames(TestOptionsVerbosity)))...)
            Verbosity.Error() => new(fill(
                Verbosity.Error(), length(fieldnames(TestOptionsVerbosity)))...)
            Verbosity.Default() => TestOptionsVerbosity()
            Verbosity.Edge() => TestOptionsVerbosity(
                test1 = Verbosity.Info(),
                test2 = Verbosity.Info(),
                test3 = Verbosity.Info(),
                test4 = Verbosity.Info()
            )
            _ => @error "Not a valid choice for verbosity."
        end
    end
end

struct TestVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::TestOptionsVerbosity
end

# Tests 

@testset "Basic tests" begin
    verbose = TestVerbosity{true}(TestOptionsVerbosity())

    @test_logs (:warn, "Test1") @SciMLMessage("Test1", verbose, :test1, :options)
    @test_logs (:info, "Test2") @SciMLMessage("Test2", verbose, :test2, :options)
    @test_logs (:error, "Test3") @SciMLMessage("Test3", verbose, :test3, :options)
    @test_logs min_level=Logging.Debug @SciMLMessage("Test4", verbose, :test4, :options)

    x = 30
    y = 30

    @test_logs (:warn, "Test1: 60") @SciMLMessage(verbose, :test1, :options) do
        z = x + y
        "Test1: $z"
    end
end
