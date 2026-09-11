using SciMLLogging, BenchmarkTools

const SUITE = BenchmarkGroup()

@verbosity_specifier BenchVerbosity begin
    toggles = (:convergence, :progress, :diagnostics)
    presets = (
        Standard = (
            convergence = InfoLevel,
            progress = WarnLevel,
            diagnostics = Silent,
        ),
        None = (
            convergence = Silent,
            progress = Silent,
            diagnostics = Silent,
        ),
        All = (
            convergence = InfoLevel,
            progress = InfoLevel,
            diagnostics = InfoLevel,
        ),
    )
    groups = (solver = (:convergence, :progress),)
end

# =============================================================================
# Verbosity construction
# =============================================================================

SUITE["construction"] = BenchmarkGroup()

SUITE["construction"]["preset_standard"] = @benchmarkable BenchVerbosity(Standard())
SUITE["construction"]["preset_none"] = @benchmarkable BenchVerbosity(preset = None())
SUITE["construction"]["preset_all"] = @benchmarkable BenchVerbosity(preset = All())
SUITE["construction"]["keyword"] = @benchmarkable BenchVerbosity(
    convergence = WarnLevel
)
SUITE["construction"]["logger"] = @benchmarkable SciMLLogger()
SUITE["construction"]["level_convert"] = @benchmarkable verbosity_to_int(WarnLevel)

# =============================================================================
# Message emission paths
# =============================================================================

SUITE["message"] = BenchmarkGroup()

verbose_none = BenchVerbosity(preset = None())
verbose_all = BenchVerbosity(preset = All())

# Messages on a disabled specifier should be nearly free
SUITE["message"]["suppressed"] = @benchmarkable @SciMLMessage(
    "suppressed", $verbose_none, :convergence
)

# Emitted message (goes through the logging backend)
SUITE["message"]["emitted"] = @benchmarkable @SciMLMessage(
    "emitted", $verbose_all, :convergence
)

# Bool verbosity path
SUITE["message"]["bool_true"] = @benchmarkable @SciMLMessage("emitted", true)
SUITE["message"]["bool_false"] = @benchmarkable @SciMLMessage("suppressed", false)

const counter = Ref(0)
function emit_lazy()
    return @SciMLMessage(verbose_none, :convergence) do
        counter[] += 1
        "computed"
    end
end
SUITE["message"]["lazy_block"] = @benchmarkable emit_lazy()
