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

    @test_logs (:warn, r"Test1") @SciMLMessage("Test1", verbose, :test1)
    @test_logs (:info, r"Test2") @SciMLMessage("Test2", verbose, :test2)
    @test_logs (:error, r"Test3") @test_throws "Test3" begin
         @SciMLMessage("Test3", verbose, :test3)
    end
    @test_logs min_level = Logging.Debug @SciMLMessage("Test4", verbose, :test4)

    x = 30
    y = 30

    @test_logs (:warn, r"Test1: 60") @SciMLMessage(verbose, :test1) do
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
    @test_logs (:info, r"All preset test") @SciMLMessage("All preset test", verbose_all, :test1)

    # Minimal preset should only log errors and throw for error messages
    @test_logs (:error, r"Minimal preset test") @test_throws ErrorException("Verbosity toggle: test1 \n Minimal preset test") begin
       @SciMLMessage("Minimal preset test", verbose_minimal, :test1)
    end

    # Test that minimal preset throws for test3 (which is ErrorLevel)
    @test_logs (:error, r"Minimal error on test3") @test_throws ErrorException("Verbosity toggle: test3 \n Minimal error on test3") begin
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
    @test_logs (:warn, r"Inner message from nested call") (:info, r"Outer message with nested result") begin
        result = @SciMLMessage(verbose, :test2) do
            @SciMLMessage("Inner message from nested call", verbose, :test1)
            "Outer message with nested result"
        end
    end

    # Test nested with both function-based inner and outer
    counter = 0
    @test_logs (:info, r"Inner computation: 5") (:warn, r"Outer result: 5") begin
        @SciMLMessage(verbose, :test1) do
            inner_result = @SciMLMessage(verbose, :test2) do
                counter = 5
                "Inner computation: $counter"
            end
            "Outer result: $counter"
        end
    end
end

@testset "Boolean verbosity" begin
    # Test with true - should emit at WarnLevel (three-arg form)
    @test_logs (:warn, r"Message with verbose=true") @SciMLMessage("Message with verbose=true", true, :ignored)

    # Test with false - should not emit anything (three-arg form)
    @test_logs min_level = Logging.Debug @SciMLMessage("Message with verbose=false", false, :ignored)

    # Test with function form and true (three-arg form)
    @test_logs (:warn, r"Computed message: 42") @SciMLMessage(true, :ignored) do
        x = 40 + 2
        "Computed message: $x"
    end

    # Test with function form and false - should not compute or emit (three-arg form)
    computation_ran = false
    @test_logs min_level = Logging.Debug @SciMLMessage(false, :ignored) do
        computation_ran = true
        "This should not be computed"
    end
    @test !computation_ran  # Verify function was never called when verbose=false

    # Test two-argument form with true
    @test_logs (:warn, r"Two-arg form with true") @SciMLMessage("Two-arg form with true", true)

    # Test two-argument form with false
    @test_logs min_level = Logging.Debug @SciMLMessage("Two-arg form with false", false)

    # Test two-argument form with function and true
    @test_logs (:warn, r"Two-arg computed: 100") @SciMLMessage(true) do
        y = 50 * 2
        "Two-arg computed: $y"
    end

    # Test two-argument form with function and false
    computation_ran_2arg = false
    @test_logs min_level = Logging.Debug @SciMLMessage(false) do
        computation_ran_2arg = true
        "This should not be computed either"
    end
    @test !computation_ran_2arg  # Verify function was never called when verbose=false
end

@testset "Varargs support" begin
    verbose = TestVerbosity()

    x = 10
    y = 20

    # Test with bare symbols - message should be emitted with kwargs
    @test_logs (:warn, r"With bare symbols") @SciMLMessage(
        "With bare symbols", verbose, :test1, x, y)

    # Test with keyword arguments
    @test_logs (:warn, r"With kwargs") @SciMLMessage(
        "With kwargs", verbose, :test1, a = 1, b = 2)

    # Test with mixed bare symbols and kwargs
    @test_logs (:warn, r"With mixed") @SciMLMessage(
        "With mixed", verbose, :test1, x, extra = "info")

    # Test with expression as value
    @test_logs (:warn, r"With expression") @SciMLMessage(
        "With expression", verbose, :test1, sum = x + y)

    # Test that silent still skips emission even with varargs
    verbose_silent = TestVerbosity(test1 = Silent())
    @test_logs min_level = Logging.Debug @SciMLMessage(
        "Should not appear", verbose_silent, :test1, x, y)

    # Test varargs with boolean verbosity
    @test_logs (:warn, r"Boolean with varargs") @SciMLMessage(
        "Boolean with varargs", true, :_, x, y)

    @test_logs min_level = Logging.Debug @SciMLMessage(
        "Boolean false with varargs", false, :_, x, y)
end