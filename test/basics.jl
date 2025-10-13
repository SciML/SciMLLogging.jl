using SciMLLogging
using SciMLLogging: SciMLLogging, AbstractVerbositySpecifier, @SciMLMessage, AbstractVerbosityPreset, AbstractMessageLevel, WarnLevel, InfoLevel, ErrorLevel, Silent, None, All, Minimal
using Logging
using Test

# Structs for testing package - simplified structure
struct TestVerbosity <: AbstractVerbositySpecifier
    test1
    test2
    test3
    test4

    function TestVerbosity(;
            test1 = WarnLevel(),
            test2 = InfoLevel(),
            test3 = ErrorLevel(),
            test4 = Silent())
        new(test1, test2, test3, test4)
    end
end

function TestVerbosity(preset::AbstractVerbosityPreset)
    if preset isa SciMLLogging.None
        TestVerbosity(
            test1 = Silent(),
            test2 = Silent(),
            test3 = Silent(),
            test4 = Silent()
        )
    elseif preset isa SciMLLogging.All
        TestVerbosity(
            test1 = InfoLevel(),
            test2 = InfoLevel(),
            test3 = InfoLevel(),
            test4 = InfoLevel()
        )
    elseif preset isa Minimal
        TestVerbosity(
            test1 = ErrorLevel(),
            test2 = Silent(),
            test3 = ErrorLevel(),
            test4 = Silent()
        )
    else
        TestVerbosity()
    end
end

# Tests 

@testset "Basic tests" begin
    verbose = TestVerbosity()

    @test_logs (:warn, "Test1") @SciMLMessage("Test1", verbose, :test1)
    @test_logs (:info, "Test2") @SciMLMessage("Test2", verbose, :test2)
    @test_logs (:error, "Test3") @test_throws "Test3" begin
         @SciMLMessage("Test3", verbose, :test3)
    end
    @test_logs min_level = Logging.Debug @SciMLMessage("Test4", verbose, :test4)

    x = 30
    y = 30

    @test_logs (:warn, "Test1: 60") @SciMLMessage(verbose, :test1) do
        z = x + y
        "Test1: $z"
    end
end

@testset "Verbosity presets" begin
    # Test with different presets
    verbose_all = TestVerbosity(All())
    verbose_minimal = TestVerbosity(Minimal())
    verbose_none = TestVerbosity(None())

    # All preset should log info level messages
    @test_logs (:info, "All preset test") @SciMLMessage("All preset test", verbose_all, :test1)

    # Minimal preset should only log errors and throw for error messages
    @test_logs (:error, "Minimal preset test") @test_throws ErrorException("Minimal preset test") begin
       @SciMLMessage("Minimal preset test", verbose_minimal, :test1)
    end

    # Test that minimal preset throws for test3 (which is ErrorLevel)
    @test_logs (:error, "Minimal error on test3") @test_throws ErrorException("Minimal error on test3") begin
        @SciMLMessage("Minimal error on test3", verbose_minimal, :test3)
    end

    # None preset should not log anything
    @test_logs min_level = Logging.Debug @SciMLMessage("None preset test", verbose_none, :test1)
end

@testset "Disabled verbosity" begin
    verbose_off = TestVerbosity(
        test1 = Silent(),
        test2 = Silent(),
        test3 = Silent(),
        test4 = Silent()
    )

    # Should not log anything when all categories are silent
    @test_logs min_level = Logging.Debug @SciMLMessage("Should not appear", verbose_off, :test1)
    @test_logs min_level = Logging.Debug @SciMLMessage("Should not appear", verbose_off, :test2)
end

@testset "Nested @SciMLMessage macros" begin
    verbose = TestVerbosity()

    # Test that @SciMLMessage can be called inside another @SciMLMessage function block
    @test_logs (:warn, "Inner message from nested call") (:info, "Outer message with nested result") begin
        result = @SciMLMessage(verbose, :test2) do
            @SciMLMessage("Inner message from nested call", verbose, :test1)
            "Outer message with nested result"
        end
    end

    # Test nested with both function-based inner and outer
    counter = 0
    @test_logs (:info, "Inner computation: 5") (:warn, "Outer result: 5") begin
        @SciMLMessage(verbose, :test1) do
            inner_result = @SciMLMessage(verbose, :test2) do
                counter = 5
                "Inner computation: $counter"
            end
            "Outer result: $counter"
        end
    end
end