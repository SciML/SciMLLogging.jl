module SciMLLogging

import Logging
using Logging: NullLogger, current_logger
using LoggingExtras: EarlyFilteredLogger, FileLogger, TeeLogger
using PrecompileTools: @compile_workload
using Preferences: @load_preference, @set_preferences!

include("verbosity.jl")
include("utils.jl")
include("verbspec_generation_macro.jl")
include("precompile.jl")

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
