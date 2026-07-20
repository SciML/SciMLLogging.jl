using SciMLTesting, SciMLLogging, Test
using SciMLLogging: @SciMLMessage, @verbosity_specifier,
    Silent, InfoLevel, WarnLevel, ErrorLevel,
    None, Standard
using JET

run_qa(
    SciMLLogging;
    ei_kwargs = (;
        # SciMLLogging integrates with the standard logging stack via Base/Core
        # internals that are not (and cannot be made) public:
        #   Core.println; Base.CoreLogging.{current_logger_for_env,shouldlog,handle_message}
        # (src/utils.jl). `CoreLogging` is itself a non-public submodule of `Base`.
        all_qualified_accesses_are_public = (;
            ignore = (
                :CoreLogging, :current_logger_for_env, :handle_message,
                :println, :shouldlog,
            ),
        ),
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
