# Load preference for logging backend - defaults to "logging" for Julia Logging system
const LOGGING_BACKEND = @load_preference("logging_backend", "logging")

"""
    AbstractVerbositySpecifier{Enabled}

Base for types which specify which log messages are emitted at what level.

# Type Parameters

- `Enabled`: Boolean type parameter used to specialize enabled and disabled
  verbosity configurations.
"""
abstract type AbstractVerbositySpecifier{Enabled} end

# Utilities

# Convert a MessageLevel to a Julia Logging.LogLevel. Used only by the
# Logging backend at the point where we actually hand off to Julia's logging
# system — other backends (core, tracy) consume the MessageLevel directly.
@inline function to_loglevel(m::MessageLevel)
    m == DebugLevel && return Logging.Debug
    m == InfoLevel  && return Logging.Info
    m == WarnLevel  && return Logging.Warn
    m == ErrorLevel && return Logging.Error
    return Logging.LogLevel(m.level)
end

function emit_message(
        f::Function, level::MessageLevel, option, file, line,
        _module; kwargs...
    )
    message = f()
    msg = "Verbosity toggle: $option \n $message"
    @static if LOGGING_BACKEND == "core"
        Core.println(msg)
    elseif LOGGING_BACKEND == "tracy"
        emit_tracy_message(msg, level, file, line, _module)
    else
        _emit_log(to_loglevel(level), msg, _module, file, line; kwargs...)
    end

    return if level == ErrorLevel
        throw(ErrorException(msg))
    end
end

function emit_message(
        message::AbstractString,
        level::MessageLevel, option, file, line, _module; kwargs...
    )

    msg = "Verbosity toggle: $option \n $message"
    @static if LOGGING_BACKEND == "core"
        Core.println(msg)
    elseif LOGGING_BACKEND == "tracy"
        emit_tracy_message(msg, level, file, line, _module)
    else
        _emit_log(to_loglevel(level), msg, _module, file, line; kwargs...)
    end

    return if level == ErrorLevel
        throw(ErrorException(msg))
    end
end

function emit_message(
        message::AbstractString,
        level::Nothing, option, file, line, _module; kwargs...
    )
end

# Stub for SciMLLoggingTracyExt
function emit_tracy_message end

function emit_message(
        f::Function, level::Nothing, option, file, line, _module; kwargs...
    )
end

# Helper function to emit log messages using the lower-level Logging API
# This allows us to pass kwargs dynamically at runtime
function _emit_log(level, message, _module, file, line; kwargs...)
    # Generate a unique id based on file and line (similar to what @logmsg does)
    id = Symbol(basename(file), "_", line)
    group = Symbol(basename(file))

    # Get the appropriate logger
    logger = Base.CoreLogging.current_logger_for_env(level, group, _module)

    if logger !== nothing && Base.invokelatest(Base.CoreLogging.shouldlog, logger, level, _module, group, id)
        Base.invokelatest(
            Base.CoreLogging.handle_message,
            logger, level, message, _module, group, id, file, line; kwargs...
        )
    end
    return nothing
end

@inline function get_message_level(::AbstractVerbositySpecifier{false}, ::Any)
    return nothing
end

@inline function get_message_level(verb::AbstractVerbositySpecifier{true}, option)
    m = getproperty(verb, option)
    # Toggle access returns a MessageLevel (Silent → no emission). Sub-specifier
    # access returns a spec/preset, which doesn't make sense here — treat as no-op.
    return m isa MessageLevel && m != Silent ? m : nothing
end

@inline function get_message_level(verb::Bool, _)
    return verb ? WarnLevel : nothing
end


"""
    @SciMLMessage(message, verbosity::AbstractVerbositySpecifier, option::Symbol[, kwargs...])
    @SciMLMessage(message, verbosity::Bool[, kwargs...])

Emit a log message controlled by a verbosity specifier or boolean flag.

`message` may be a string or a zero-argument function that returns a string.

# Arguments

- `message`: Message string or zero-argument message-producing function.
- `verbosity`: `AbstractVerbositySpecifier` instance or `Bool` controlling emission.
- `option`: Field name in `verbosity` that selects the message category.
- `kwargs...`: Optional key-value metadata forwarded to Julia's logging system.

# Examples

The macro works with any `AbstractVerbositySpecifier` implementation:

```julia
# Package defines verbosity specifier
struct SolverVerbosity{Enabled} <: AbstractVerbositySpecifier{Enabled}
    initialization::MessageLevel
    progress::MessageLevel
    convergence::MessageLevel
    diagnostics::MessageLevel
    performance::MessageLevel
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
- `true` will emit the message at `WarnLevel`
- `false` will suppress the message (equivalent to `Silent`)

The two-argument form `@SciMLMessage(message, verbosity)` can be used when `verbosity` is a `Bool`:

```julia
function solve_problem(problem; verbose::Bool = true)
    @SciMLMessage("Starting solver", verbose)
    # ... solver logic ...
end
```

Like the base logging macros, `@SciMLMessage` supports additional key-value arguments:

```julia
x = 10
@SciMLMessage("Message", verbosity, :option, x, extra_info="some info")
# Output: ┌ Warning: Verbosity toggle: option
#         │          Message
#         │   x = 10
#         └   extra_info = "some info"
```
"""
macro SciMLMessage(f_or_message, verb, option, exs...)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__

    # Process extra arguments similar to how base logging macros do it
    # - Bare symbols like `x` become `x = x`
    # - Keyword arguments like `a=1` stay as-is
    kwargs = []
    for ex in exs
        if ex isa Expr && ex.head === :(=) && ex.args[1] isa Symbol
            # Already a key=value pair
            push!(kwargs, Expr(:kw, ex.args[1], esc(ex.args[2])))
        elseif ex isa Symbol
            # Bare symbol - create key=symbol pair
            push!(kwargs, Expr(:kw, ex, esc(ex)))
        else
            # Expression - use a generated key name
            key = Symbol(string(ex))
            push!(kwargs, Expr(:kw, key, esc(ex)))
        end
    end

    expr = quote
        let _sciml_level = get_message_level($(esc(verb)), $(esc(option)))
            _sciml_level !== nothing && emit_message(
                $(esc(f_or_message)),
                _sciml_level,
                $(esc(option)),
                $file,
                $line,
                $_module;
                $(kwargs...)
            )
        end
    end
    return expr
end

macro SciMLMessage(f_or_message, verb)
    return esc(:(@SciMLMessage($f_or_message, $verb, :_)))
end

"""
    verbosity_to_int(verb::MessageLevel)

Convert a `MessageLevel` to its integer value.

This is useful when integrating with APIs that represent verbosity as an
integer or integer-backed enum.

# Arguments

- `verb`: Message level to convert.

# Returns

The integer severity for `verb`.

# Examples

```julia
using SciMLLogging

verbosity_to_int(Silent)           # returns 0
verbosity_to_int(InfoLevel)        # returns 2
verbosity_to_int(MessageLevel(10)) # returns 10
```
"""
function verbosity_to_int(verb::MessageLevel)
    verb == Silent     && return 0
    verb == DebugLevel && return 1
    verb == InfoLevel  && return 2
    verb == WarnLevel  && return 3
    verb == ErrorLevel && return 4
    return verb.level
end

"""
    verbosity_to_bool(verb::MessageLevel)

Convert a `MessageLevel` to a boolean verbosity flag.

`Silent` maps to `false`; every other message level maps to `true`.

# Arguments

- `verb`: Message level to convert.

# Returns

`true` when `verb` emits messages, and `false` when it is `Silent`.

# Examples

```julia
using SciMLLogging

verbosity_to_bool(Silent)       # returns false
verbosity_to_bool(WarnLevel)    # returns true
verbosity_to_bool(MessageLevel(5))
```
"""
function verbosity_to_bool(verb::MessageLevel)
    return verb != Silent
end

"""
    set_logging_backend(backend::String)

Set the logging backend preference.

# Arguments

- `backend`: Backend name. Valid values are `"logging"`, `"core"`, and `"tracy"`.

# Returns

Returns `nothing` after updating the preference, or throws `ArgumentError` for
an invalid backend.

Note: You must restart Julia for this preference change to take effect.
"""
function set_logging_backend(backend::String)
    return if backend in ["logging", "core", "tracy"]
        @set_preferences!("logging_backend" => backend)
        @info("Logging backend set to '$backend'. Restart Julia for changes to take effect!")
    else
        throw(ArgumentError("Invalid backend '$backend'. Valid options are: 'logging', 'core', 'tracy'"))
    end
end

"""
    get_logging_backend()

Get the current logging backend preference.

# Returns

The configured backend name as a string.
"""
function get_logging_backend()
    return @load_preference("logging_backend", "logging")
end

"""
    SciMLLogger(; kwargs...)

Create a logger that routes messages to REPL and/or files based on log level.

# Keyword Arguments

- `debug_repl = false`: Show debug messages in the current logger.
- `info_repl = true`: Show info messages in the current logger.
- `warn_repl = true`: Show warnings in the current logger.
- `error_repl = true`: Show errors in the current logger.
- `debug_file = nothing`: File path for debug messages.
- `info_file = nothing`: File path for info messages.
- `warn_file = nothing`: File path for warnings.
- `error_file = nothing`: File path for errors.

# Returns

A `LoggingExtras.TeeLogger` that routes each log level to the requested sinks.
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
