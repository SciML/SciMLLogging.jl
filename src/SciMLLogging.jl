"""
    SciMLLogging

Verbosity control for the SciML ecosystem.

SciMLLogging.jl replaces a single `verbose = true` switch with a *verbosity specifier*: a
struct whose fields each name one category of message a package can emit, and whose value
per category is a message level (`Silent`, `DebugLevel`, `InfoLevel`, `WarnLevel`,
`ErrorLevel`). Because the enabled/disabled state lives in the specifier's type
parameters, a silenced category compiles away rather than being branched over at runtime.

Users of a package that has adopted SciMLLogging pass one of its presets, or set
categories individually, and hand the result to the solver:

```julia
using SciMLLogging
solve(prob, alg; verbose = MyPackageVerbosity(Standard()))
solve(prob, alg; verbose = MyPackageVerbosity(progress = Silent, diagnostics = WarnLevel))
```

Package authors declare the specifier type with `@verbosity_specifier`, which generates
the struct, its constructors and the presets (`None`, `Minimal`, `Standard`, `Detailed`,
`All`) in one declaration, then emit messages through `@SciMLMessage`. Output goes to
Julia's standard logging by default; `set_logging_backend` selects an alternative.

See the [SciMLLogging documentation](https://docs.sciml.ai/SciMLLogging/stable/) for the
full interface.
"""
module SciMLLogging

import Logging
using Logging: NullLogger, current_logger
using LoggingExtras: EarlyFilteredLogger, FileLogger, TeeLogger
using Preferences: @load_preference, @set_preferences!

include("verbosity.jl")
include("utils.jl")
include("verbspec_generation_macro.jl")

# Export public API
export AbstractVerbositySpecifier, AbstractVerbosityPreset, MessageLevel
export DebugLevel, InfoLevel, WarnLevel, ErrorLevel, Silent
export @SciMLMessage
export verbosity_to_int, verbosity_to_bool
export SciMLLogger
export set_logging_backend, get_logging_backend
export None, Minimal, Standard, Detailed, All
export @verbosity_specifier

end
