
# Load preference for logging backend - defaults to "logging" for Julia Logging system
const LOGGING_BACKEND = @load_preference("logging_backend", "logging")

"""
    `AbstractVerbositySpecifier`

Base for types which specify which log messages are emitted at what level.
    
"""
abstract type AbstractVerbositySpecifier end

# Utilities 

function message_level(verbose::AbstractVerbositySpecifier, option)
    opt_level = getproperty(verbose, option)

    if opt_level isa Silent
        return nothing
    elseif opt_level isa InfoLevel
        return Logging.Info
    elseif opt_level isa WarnLevel
        return Logging.Warn
    elseif opt_level isa ErrorLevel
        return Logging.Error
    elseif opt_level isa CustomLevel
        return Logging.LogLevel(opt_level.level)
    else
        return nothing
    end
end

function emit_message(
        f::Function, verbose::AbstractVerbositySpecifier, level, file, line,
        _module)
    message = f()
    @static if LOGGING_BACKEND == "core"
        Core.println(message)
    else
        Base.@logmsg level message _file=file _line=line _module=_module
    end
end

function emit_message(message::String, verbose::AbstractVerbositySpecifier,
        level, file, line, _module)
    @static if LOGGING_BACKEND == "core"
        Core.println(message)
    else
        Base.@logmsg level message _file=file _line=line _module=_module
    end
end

function emit_message(message::String, verbose::AbstractVerbositySpecifier,
    level::Nothing, file, line, _module)
end 

function emit_message(
    f::Function, verbose::AbstractVerbositySpecifier, level::Nothing, file, line, _module)
end


"""
    `@SciMLMessage(message, verbosity, option)`

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
"""
macro SciMLMessage(f_or_message, verb, option)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    expr = :(emit_message($(esc(f_or_message)), $(esc(verb)), message_level($(esc(verb)), $(esc(option))), $file, $line, $_module))
    return expr
end

# For backwards compat to be not breaking. Also might be used in the future for log filtering.
macro SciMLMessage(f_or_message, verb, option, group)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    return :(emit_message(
        $(esc(f_or_message)), $(esc(verb)), message_level($(esc(verb)), $(esc(option))), $file, $line, $_module))
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
    verbosity_to_int(InfoLevel())     # Returns 1
    verbosity_to_int(WarnLevel())     # Returns 2
    verbosity_to_int(ErrorLevel())    # Returns 3

    # Custom levels

    verbosity_to_int(CustomLevel(10)) # Returns 10
    verbosity_to_int(CustomLevel(-5)) # Returns -5
    ```
"""
function verbosity_to_int(verb::AbstractMessageLevel)
    if verb isa Silent
        return 0
    elseif verb isa InfoLevel
        return 1
    elseif verb isa WarnLevel
        return 2
    elseif verb isa ErrorLevel
        return 3
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
    if backend in ["logging", "core"]
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
    `SciMLLogger(; kwargs...)`

Create a logger that routes messages to REPL and/or files based on log level.

# Keyword Arguments
- `info_repl = true`: Show info messages in REPL
- `warn_repl = true`: Show warnings in REPL
- `error_repl = true`: Show errors in REPL
- `info_file = nothing`: File path for info messages
- `warn_file = nothing`: File path for warnings
- `error_file = nothing`: File path for errors
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
