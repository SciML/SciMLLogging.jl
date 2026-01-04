# Load preference for logging backend - defaults to "logging" for Julia Logging system
const LOGGING_BACKEND = @load_preference("logging_backend", "logging")

"""
    `AbstractVerbositySpecifier`

Base for types which specify which log messages are emitted at what level.
    
"""
abstract type AbstractVerbositySpecifier end

# Utilities

function logging_message_level(option)
    if option isa DebugLevel
        return Logging.Debug
    elseif option isa InfoLevel
        return Logging.Info
    elseif option isa WarnLevel
        return Logging.Warn
    elseif option isa ErrorLevel
        return Logging.Error
    elseif option isa CustomLevel
        return Logging.LogLevel(option.level)
    end
end

function logging_message_level(option::Silent)
    return nothing
end

function emit_message(
        f::Function, level, option, file, line,
        _module
    )
    message = f()
    msg = "Verbosity toggle: $option \n $message"
    @static if LOGGING_BACKEND == "core"
        Core.println(msg)
    else
        Base.@logmsg level msg _file = file _line = line _module = _module
    end

    return if level == Logging.Error
        throw(ErrorException(msg))
    end
end

function emit_message(
        message::AbstractString,
        level, option, file, line, _module
    )

    msg = "Verbosity toggle: $option \n $message"
    @static if LOGGING_BACKEND == "core"
        Core.println(msg)
    else
        Base.@logmsg level msg _file = file _line = line _module = _module
    end

    return if level == Logging.Error
        throw(ErrorException(msg))
    end
end

function emit_message(
        message::AbstractString,
        level::Nothing, option, file, line, _module
    )
end

function emit_message(
        f::Function, level::Nothing, option, file, line, _module
    )
end

function get_message_level(verb::AbstractVerbositySpecifier, option)
    return logging_message_level(getproperty(verb, option))
end

function get_message_level(verb::Bool, _)
    return verb ? logging_message_level(WarnLevel()) : logging_message_level(Silent())
end


"""
    `@SciMLMessage(message, verbosity::AbstracVerbositySpecifier, option::Symbol)`
    `@SciMLMessage(message, verbosity::Bool)`

A macro that emits a log message based on the log level specified in the `option` of the `AbstractVerbositySpecifier` supplied.

`f_or_message` may be a message String, or a 0-argument function that returns a String.

## Usage

To emit a simple string, `@SciMLMessage("message", verbosity, :option)` will emit a log message with the LogLevel specified in `verbosity` for the given `option`.

`@SciMLMessage` can also be used to emit a log message coming from the evaluation of a 0-argument function. This function is resolved in the environment of the macro call.
Therefore it can use variables from the surrounding environment. This may be useful if the log message writer wishes to carry out some calculations using existing variables
and use them in the log message. The function is only called if the message category is not `Silent()`, avoiding unnecessary computation.

The macro works with any `AbstractVerbositySpecifier` implementation:

```julia
# Package defines verbosity specifier
@concrete struct SolverVerbosity <: AbstractVerbositySpecifier
    initialization
    progress
    convergence
    diagnostics
    performance
end

# Usage in package code
function solve_problem(problem; verbose = SolverVerbosity(Standard()))
    @SciMLMessage("Initializing solver", verbose, :initialization)

    # ... solver setup ...

    for iteration in 1:max_iterations
        @SciMLMessage("Iteration \$iteration", verbose, :progress)

        # ... iteration work ...

        if converged
            @SciMLMessage("Converged after \$iteration iterations", verbose, :convergence)
            break
        end
    end

    return result
end
```

Alternatively, the macro also accepts a boolean value for `verb`:

When `verb` is a boolean:
- `true` will emit the message at `WarnLevel()`
- `false` will suppress the message (equivalent to `Silent()`)

The two-argument form `@SciMLMessage(message, verbosity)` can be used when `verbosity` is a `Bool`:

```julia
function solve_problem(problem; verbose::Bool = true)
    @SciMLMessage("Starting solver", verbose)
    # ... solver logic ...
end
```
"""
macro SciMLMessage(f_or_message, verb, option)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    expr = quote
        emit_message(
            $(esc(f_or_message)),
            get_message_level($(esc(verb)), $(esc(option))),
            $(esc(option)),
            $file,
            $line,
            $_module
        )
    end
    return expr
end

macro SciMLMessage(f_or_message, verb)
    return esc(:(@SciMLMessage($f_or_message, $verb, :_)))
end

"""
        `verbosity_to_int(verb::AbstractMessageLevel)`

    Takes a `AbstractMessageLevel` and gives a corresponding integer value.
    Verbosity settings that use integers or enums that hold integers are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity. Each of the basic verbosity levels
    are mapped to an integer.

    ```julia

    using SciMLLogging

    # Standard levels

    verbosity_to_int(Silent())        # Returns 0
    verbosity_to_int(DebugLevel())    # Returns 1
    verbosity_to_int(InfoLevel())     # Returns 2
    verbosity_to_int(WarnLevel())     # Returns 3
    verbosity_to_int(ErrorLevel())    # Returns 4

    # Custom levels

    verbosity_to_int(CustomLevel(10)) # Returns 10
    verbosity_to_int(CustomLevel(-5)) # Returns -5
    ```
"""
function verbosity_to_int(verb::AbstractMessageLevel)
    if verb isa Silent
        return 0
    elseif verb isa DebugLevel
        return 1
    elseif verb isa InfoLevel
        return 2
    elseif verb isa WarnLevel
        return 3
    elseif verb isa ErrorLevel
        return 4
    elseif verb isa CustomLevel
        return verb.level
    else
        return 0
    end
end

"""
        `verbosity_to_bool(verb::AbstractMessageLevel)`
        
    Takes a `AbstractMessageLevel` and gives a corresponding boolean value.
    Verbosity settings that use booleans are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity.
    If the verbosity is `Silent`, then `false` is returned. Otherwise, `true` is returned.

    ```julia
    using SciMLLogging

    # Silent returns false
    verbosity_to_bool(Silent())        # Returns false

    # All other levels return true
    verbosity_to_bool(InfoLevel())     # Returns true
    verbosity_to_bool(WarnLevel())     # Returns true
    verbosity_to_bool(ErrorLevel())    # Returns true
    verbosity_to_bool(CustomLevel(5))  # Returns true
    ```

"""
function verbosity_to_bool(verb::AbstractMessageLevel)
    if verb isa Silent
        return false
    else
        return true
    end
end

"""
    `set_logging_backend(backend::String)``

Set the logging backend preference. Valid options are:
- "logging": Use Julia's standard Logging system (default)
- "core": Use Core.println for simple output

Note: You must restart Julia for this preference change to take effect.
"""
function set_logging_backend(backend::String)
    return if backend in ["logging", "core"]
        @set_preferences!("logging_backend" => backend)
        @info("Logging backend set to '$backend'. Restart Julia for changes to take effect!")
    else
        throw(ArgumentError("Invalid backend '$backend'. Valid options are: 'logging', 'core'"))
    end
end

"""
    `get_logging_backend()`

Get the current logging backend preference.
"""
function get_logging_backend()
    return @load_preference("logging_backend", "logging")
end

"""
    SciMLLogger(; kwargs...)

Create a logger that routes messages to REPL and/or files based on log level.

# Keyword Arguments
- `debug_repl = false`: Show debug messages in REPL
- `info_repl = true`: Show info messages in REPL
- `warn_repl = true`: Show warnings in REPL
- `error_repl = true`: Show errors in REPL
- `debug_file = nothing`: File path for debug messages
- `info_file = nothing`: File path for info messages
- `warn_file = nothing`: File path for warnings
- `error_file = nothing`: File path for errors
"""
function SciMLLogger(;
        debug_repl = false, info_repl = true, warn_repl = true, error_repl = true,
        debug_file = nothing, info_file = nothing, warn_file = nothing, error_file = nothing
    )
    debug_sink = isnothing(debug_file) ? NullLogger() : FileLogger(debug_file)
    info_sink = isnothing(info_file) ? NullLogger() : FileLogger(info_file)
    warn_sink = isnothing(warn_file) ? NullLogger() : FileLogger(warn_file)
    error_sink = isnothing(error_file) ? NullLogger() : FileLogger(error_file)

    repl_filter = EarlyFilteredLogger(current_logger()) do log
        return (
            (log.level == Logging.Debug && debug_repl) ||
                (log.level == Logging.Info && info_repl) ||
                (log.level == Logging.Warn && warn_repl) ||
                (log.level == Logging.Error && error_repl)
        )
    end

    debug_filter = EarlyFilteredLogger(debug_sink) do log
        log.level == Logging.Debug
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

    return TeeLogger(repl_filter, debug_filter, info_filter, warn_filter, error_filter)
end
