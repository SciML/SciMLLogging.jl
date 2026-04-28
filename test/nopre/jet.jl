using SciMLLogging
using SciMLLogging: @SciMLMessage, @verbosity_specifier,
    Silent, InfoLevel, WarnLevel, ErrorLevel,
    None, Standard
using JET
using Test

@verbosity_specifier JETTestVerbosity begin
    toggles = (:a, :b, :c)

    presets = (
        None = (
            a = Silent(),
            b = Silent(),
            c = Silent(),
        ),
        Standard = (
            a = WarnLevel(),
            b = InfoLevel(),
            c = ErrorLevel(),
        ),
    )

    groups = ()
end

function emit_all(verbose)
    @SciMLMessage("msg a", verbose, :a)
    @SciMLMessage("msg b", verbose, :b)
    @SciMLMessage(lazy"msg c", verbose, :c)
    return nothing
end

@testset "JET report_opt with None() preset" begin
    verbose = JETTestVerbosity(None())
    JET.@test_opt target_modules = (SciMLLogging,) emit_all(verbose)
end
