"""
    Verbosity

A sum type representing different verbosity levels for the SciML logging system.

# Variants
- `None`: No output will be generated
- `Info`: Informational messages (maps to `Logging.Info`)
- `Warn`: Warning messages (maps to `Logging.Warn`)
- `Error`: Error messages (maps to `Logging.Error`)
- `Level(Int)`: Custom log level with specified integer (maps to `Logging.LogLevel(n)`)
- `Edge`: Special verbosity for edge cases
- `All`: Maximum verbosity level
- `Default`: Use default verbosity settings
- `Code(Expr)`: Execute custom code instead of logging

# Examples
```julia
# Set different verbosity levels
verbose_info = Verbosity.Info()
verbose_warn = Verbosity.Warn()
verbose_custom = Verbosity.Level(-1000)  # Debug level
verbose_none = Verbosity.None()          # Silent
```
"""
@data Verbosity begin
    None
    Info
    Warn
    Error
    Level(Int)
    Edge
    All
    Default
    Code(Expr)
end

"""
    AbstractVerbositySpecifier{T}

Abstract base type for all verbosity specifiers in the SciML logging system.

The type parameter `T` is a boolean that determines whether verbosity is enabled:
- `T = true`: Verbosity is enabled, messages will be processed and potentially emitted
- `T = false`: Verbosity is disabled, messages are compiled away with zero runtime cost

# Implementation
Custom verbosity types should inherit from this type and contain fields that group
related verbosity options. Each field should typically be a mutable struct containing
`Verbosity.Type` fields for individual options.

# Examples
```julia
# Define custom verbosity options
mutable struct MyOptions
    algorithm::Verbosity.Type
    progress::Verbosity.Type
end

# Define custom verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end

# Create enabled verbosity
verbose = MyVerbosity{true}(MyOptions(Verbosity.Info(), Verbosity.Warn()))

# Create disabled verbosity (zero runtime cost)
silent = MyVerbosity{false}(MyOptions(Verbosity.None(), Verbosity.None()))
```
"""
abstract type AbstractVerbositySpecifier{T} end

# Utilities 

function message_level(verbose::AbstractVerbositySpecifier{true}, option, group)
    group = getproperty(verbose, group)
    opt_level = getproperty(group, option)

    @match opt_level begin
        Verbosity.Code(expr) => expr
        Verbosity.None() => nothing
        Verbosity.Info() => Logging.Info
        Verbosity.Warn() => Logging.Warn
        Verbosity.Error() => Logging.Error
        Verbosity.Level(i) => Logging.LogLevel(i)
    end
end

function emit_message(
        f::Function, verbose::V, option, group, file, line,
        _module) where {V <: AbstractVerbositySpecifier{true}}
    level = message_level(
        verbose, option, group)

    if level isa Expr
        level
    elseif !isnothing(level)
        message = f()
        Base.@logmsg level message _file=file _line=line _module=_module
    end
end

function emit_message(message::String, verbose::V,
        option, group, file, line, _module) where {V <: AbstractVerbositySpecifier{true}}
    level = message_level(verbose, option, group)

    if !isnothing(level)
        Base.@logmsg level message _file=file _line=line _module=_module _group=group
    end
end

function emit_message(
        f, verbose::AbstractVerbositySpecifier{false}, option, group, file, line, _module)
end

"""
    @SciMLMessage(message_or_function, verbose, option, group)
    @SciMLMessage(verbose, option, group) do ... end

A macro that emits a log message based on the verbosity settings specified in the 
`AbstractVerbositySpecifier` instance.

# Arguments
- `message_or_function`: Either a string message or a 0-argument function that returns a string
- `verbose`: An instance of `AbstractVerbositySpecifier` that controls verbosity
- `option`: A symbol identifying the specific verbosity option (e.g., `:progress`)
- `group`: A symbol identifying the group containing the option (e.g., `:options`)

# Behavior
The macro will:
1. Check if verbosity is enabled (`T = true` in the verbosity type)
2. Access the specified group and option from the verbosity instance
3. Map the verbosity level to a Julia logging level
4. Emit the message through Julia's logging system if appropriate
5. If verbosity is disabled (`T = false`), compile to nothing (zero runtime cost)

# Examples
```julia
# Simple string message
@SciMLMessage("Starting computation", verbose, :startup, :init)

# Dynamic message with function (lazy evaluation)
@SciMLMessage(verbose, :progress, :compute) do
    percentage = current_step / total_steps * 100
    "Progress: \$(round(percentage, digits=1))%"
end

# Using variables from surrounding scope
x = 10
y = 20
@SciMLMessage(verbose, :result, :output) do
    z = x + y
    "Computation result: x + y = \$z"
end
```

# Performance
- When verbosity is disabled (`T = false`), the entire macro call is compiled away
- Function form ensures expensive message generation only happens when needed
- Integrates with Julia's logging system for efficient message handling
"""
macro SciMLMessage(f_or_message, verb, option, group)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    return :(emit_message(
        $(esc(f_or_message)), $(esc(verb)), $option, $group, $file, $line, $_module))
end

"""
    verbosity_to_int(verb::Verbosity.Type) -> Int

Convert a `Verbosity.Type` to an integer value for compatibility with packages that use 
integer-based verbosity levels.

# Arguments
- `verb::Verbosity.Type`: The verbosity level to convert

# Returns
- `Int`: The corresponding integer value

# Mapping
- `Verbosity.None()` → 0
- `Verbosity.Info()` → 1
- `Verbosity.Warn()` → 2
- `Verbosity.Error()` → 3
- `Verbosity.Level(i)` → i

# Examples
```julia
# Convert standard levels
verbosity_to_int(Verbosity.None())   # Returns 0
verbosity_to_int(Verbosity.Info())   # Returns 1
verbosity_to_int(Verbosity.Warn())   # Returns 2
verbosity_to_int(Verbosity.Error())  # Returns 3

# Custom levels pass through
verbosity_to_int(Verbosity.Level(5)) # Returns 5
verbosity_to_int(Verbosity.Level(-1000)) # Returns -1000 (debug)

# Use with external packages
external_package(data, verbosity = verbosity_to_int(options.level))
```
"""
function verbosity_to_int(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => 0
        Verbosity.Info() => 1
        Verbosity.Warn() => 2
        Verbosity.Error() => 3
        Verbosity.Level(i) => i
    end
end

"""
    verbosity_to_bool(verb::Verbosity.Type) -> Bool

Convert a `Verbosity.Type` to a boolean value for compatibility with packages that use 
boolean verbosity flags.

# Arguments
- `verb::Verbosity.Type`: The verbosity level to convert

# Returns
- `Bool`: `false` if verbosity is `None`, `true` otherwise

# Mapping
- `Verbosity.None()` → `false`
- All other levels → `true`

# Examples
```julia
# None returns false
verbosity_to_bool(Verbosity.None())  # Returns false

# All other levels return true
verbosity_to_bool(Verbosity.Info())  # Returns true
verbosity_to_bool(Verbosity.Warn())  # Returns true
verbosity_to_bool(Verbosity.Error()) # Returns true
verbosity_to_bool(Verbosity.Level(-1000)) # Returns true

# Use with legacy code expecting boolean verbosity
legacy_solver(problem, verbose = verbosity_to_bool(options.solver_output))
```
"""
function verbosity_to_bool(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => false
        _ => true
    end
end

"""
    SciMLLogger(; kwargs...) -> AbstractLogger

Create a specialized logger that routes messages to different destinations based on their 
log level. This logger can send messages to both the REPL and files simultaneously.

# Keyword Arguments
- `info_repl::Bool = true`: Show info messages in the REPL
- `warn_repl::Bool = true`: Show warning messages in the REPL
- `error_repl::Bool = true`: Show error messages in the REPL
- `info_file::Union{String, Nothing} = nothing`: File path for info messages
- `warn_file::Union{String, Nothing} = nothing`: File path for warning messages
- `error_file::Union{String, Nothing} = nothing`: File path for error messages

# Returns
A composite logger that handles message routing according to the specified configuration.

# Examples
```julia
# REPL only (default)
logger = SciMLLogger()

# Log warnings and errors to files
logger = SciMLLogger(
    warn_file = "warnings.log",
    error_file = "errors.log"
)

# Log everything to files, only errors to REPL
logger = SciMLLogger(
    info_repl = false,
    warn_repl = false,
    error_repl = true,
    info_file = "info.log",
    warn_file = "warnings.log",
    error_file = "errors.log"
)

# Use the logger
with_logger(logger) do
    @SciMLMessage("Information", verbose, :option, :group)
    @SciMLMessage("Warning", verbose, :warning, :group)
    @SciMLMessage("Error", verbose, :error, :group)
end
```

# Implementation
The logger uses `LoggingExtras.jl` to create a `TeeLogger` that combines multiple 
filtered loggers, each handling specific log levels and destinations.
"""
function SciMLLogger(; info_repl = true, warn_repl = true, error_repl = true,
        info_file = nothing, warn_file = nothing, error_file = nothing)
    info_sink = isnothing(info_file) ? NullLogger() : FileLogger(info_file)
    warn_sink = isnothing(warn_file) ? NullLogger() : FileLogger(warn_file)
    error_sink = isnothing(error_file) ? NullLogger() : FileLogger(error_file)

    repl_filter = EarlyFilteredLogger(current_logger()) do log
        if log.level == Logging.Info && info_repl
            return true
        end

        if log.level == Logging.Warn && warn_repl
            return true
        end

        if log.level == Logging.Error && error_repl
            return true
        end

        return false
    end

    info_filter = EarlyFilteredLogger(info_sink) do log
        log.level == Logging.Info
    end

    warn_filter = EarlyFilteredLogger(warn_sink) do log
        log.level == Logging.Warn
    end

    error_filter = EarlyFilteredLogger(error_sink) do log
        log.level == Logging.Error
    end

    TeeLogger(repl_filter, info_filter, warn_filter, error_filter)
end
