using SciMLTesting, SciMLLogging, Test
using SciMLLogging: @SciMLMessage, @verbosity_specifier,
    Silent, InfoLevel, WarnLevel, ErrorLevel,
    None, Standard
using JET

# ExplicitImports only sees an extension module once its trigger package is loaded,
# so load every weakdep here to bring SciMLLoggingTracyExt into the QA scan.
using Tracy

# ExplicitImports silently skips an extension that fails to load, so assert the
# extension modules actually exist rather than trusting a green run_qa.
@testset "Extensions loaded" begin
    @test Base.get_extension(SciMLLogging, :SciMLLoggingTracyExt) !== nothing
end

run_qa(
    SciMLLogging;
    ei_kwargs = (;
        # SciMLLogging: `emit_tracy_message` is the backend hook stub declared in
        # `src/utils.jl` for `SciMLLoggingTracyExt` to add a method to. It is internal
        # plumbing rather than user API, so it is deliberately not public, and an
        # extension has no other way to extend it.
        all_qualified_accesses_are_public = (; ignore = (:emit_tracy_message,)),
    )
)

# Functional inference regression test: emitting messages under a `None()` preset
# must stay type-stable / allocation-free (no fallback to the dynamic logging path).
@verbosity_specifier JETTestVerbosity begin
    toggles = (:a, :b, :c)

    presets = (
        None = (
            a = Silent,
            b = Silent,
            c = Silent,
        ),
        Standard = (
            a = WarnLevel,
            b = InfoLevel,
            c = ErrorLevel,
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
