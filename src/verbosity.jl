"""
    MessageLevel

A concrete type representing a log message level, backed by an integer.

Higher integer values correspond to higher severity. The standard levels are
available as constants: `Silent`, `DebugLevel`, `InfoLevel`, `WarnLevel`, `ErrorLevel`.
Custom levels can be created with `MessageLevel(n)` for any integer `n`.
"""
struct MessageLevel
    level::Int
end

"""
    Silent

Log level that produces no output.
"""
const Silent = MessageLevel(0)

"""
    DebugLevel

Debug log level. Corresponds to `Logging.Debug` when using the Logging backend.
"""
const DebugLevel = MessageLevel(1)

"""
    InfoLevel

Informational log level. Corresponds to `Logging.Info` when using the Logging backend.
"""
const InfoLevel = MessageLevel(2)

"""
    WarnLevel

Warning log level. Corresponds to `Logging.Warn` when using the Logging backend.
"""
const WarnLevel = MessageLevel(3)

"""
    ErrorLevel

Error log level. Corresponds to `Logging.Error` when using the Logging backend.
"""
const ErrorLevel = MessageLevel(4)

"""
    CustomLevel(n::Int)

Construct a custom log level with integer value `n`. Corresponds to `Logging.LogLevel(n)`
when using the Logging backend.
"""
const CustomLevel = MessageLevel

# Allow calling level constants with no args for backward compatibility: Silent(), InfoLevel(), etc.
(m::MessageLevel)() = m

# Backward-compatible type alias
const AbstractMessageLevel = MessageLevel

"""
    AbstractVerbosityPreset

Abstract base type for predefined verbosity configurations.

Presets provide convenient ways for users to configure verbosity without
needing to specify individual message categories. Concrete subtypes include:
- `None`: Disable all verbosity
- `Minimal`: Only essential messages
- `Standard`: Balanced verbosity for typical use
- `Detailed`: Comprehensive verbosity for debugging
- `All`: Enable all message categories
"""
abstract type AbstractVerbosityPreset end

"""
    None <: AbstractVerbosityPreset

Preset that disables all verbosity. All message categories should be set to to `Silent`.
"""
struct None <: AbstractVerbosityPreset end

"""
    Minimal <: AbstractVerbosityPreset

Preset that shows only essential messages. Typically includes only warnings,
errors, and critical status information while suppressing routine progress
and debugging messages.

This verbosity preset should set messages related to critical failures and
errors that stop computation to `ErrorLevel`. Messages related to fatal issues
(e.g., convergence problems, solver exiting, etc.) should be set to `WarnLevel`.
All other messages should be set to `Silent`.
"""
struct Minimal <: AbstractVerbosityPreset end

"""
    Standard <: AbstractVerbosityPreset

Preset that provides balanced verbosity suitable for typical usage.
Shows important progress and status information without overwhelming
the user with details.

This verbosity preset should include the settings from `Minimal`, while also setting
messages such as non-fatal deprecations and critical warnings that require handling
to `InfoLevel`.
"""
struct Standard <: AbstractVerbosityPreset end

"""
    Detailed <: AbstractVerbosityPreset

Preset that provides comprehensive verbosity for debugging and detailed
analysis. Shows most or all available message categories to help with
troubleshooting and understanding program behavior.

This verbosity preset should include the settings from `Standard`, plus progress updates
(e.g., iteration counters, intermediate state), performance metrics
(e.g., timing information, memory usage), detailed diagnostics, and internal state information.
The only messages that should be `Silent` at this preset are very small details that would
clutter output even during debugging, and information that would be expensive to calculate.
"""
struct Detailed <: AbstractVerbosityPreset end

"""
    All <: AbstractVerbosityPreset

Preset that enables maximum verbosity. All message categories are typically
set to show informational messages or their appropriate levels.

This verbosity preset should include the settings from `Detailed`, plus even more details.
At this preset, no messages should be `Silent`.
"""
struct All <: AbstractVerbosityPreset end
