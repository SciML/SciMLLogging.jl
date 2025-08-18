# API Reference

```@meta
CurrentModule = SciMLLogging
```

## Module

```@docs
SciMLLogging
```

## Core Types

### AbstractVerbositySpecifier

```@docs
AbstractVerbositySpecifier
```

The abstract base type for all verbosity specifiers. The type parameter `T` is a boolean that determines whether verbosity is enabled (`true`) or disabled (`false`).

### Verbosity

```@docs
Verbosity
```

A sum type representing different verbosity levels. Available variants:

- `Verbosity.None()` - No output
- `Verbosity.Info()` - Informational messages (maps to `Logging.Info`)
- `Verbosity.Warn()` - Warning messages (maps to `Logging.Warn`)
- `Verbosity.Error()` - Error messages (maps to `Logging.Error`)
- `Verbosity.Level(n::Int)` - Custom log level (maps to `Logging.LogLevel(n)`)
- `Verbosity.Edge()` - Special edge case handling
- `Verbosity.All()` - Maximum verbosity
- `Verbosity.Default()` - Default verbosity settings
- `Verbosity.Code(expr::Expr)` - Execute custom code instead of logging

## Macros

### @SciMLMessage

```@docs
@SciMLMessage
```

The primary macro for emitting messages based on verbosity settings.

**Signatures:**

```julia
@SciMLMessage(message::String, verbose::AbstractVerbositySpecifier, option::Symbol, group::Symbol)
@SciMLMessage(verbose::AbstractVerbositySpecifier, option::Symbol, group::Symbol) do
    # function body returning a string
end
```

**Parameters:**
- `message`: A string message to emit
- `verbose`: An instance of `AbstractVerbositySpecifier`
- `option`: Symbol identifying the specific verbosity option
- `group`: Symbol identifying the group containing the option

**Examples:**

```julia
# Simple string message
@SciMLMessage("Processing started", verbose, :startup, :options)

# Dynamic message with function
@SciMLMessage(verbose, :progress, :options) do
    percent = current / total * 100
    "Progress: $(round(percent, digits=1))%"
end
```

## Functions

### verbosity_to_int

```@docs
verbosity_to_int
```

Converts a `Verbosity.Type` to an integer value for compatibility with packages that use integer verbosity levels.

**Mapping:**
- `Verbosity.None()` → 0
- `Verbosity.Info()` → 1
- `Verbosity.Warn()` → 2
- `Verbosity.Error()` → 3
- `Verbosity.Level(i)` → i

**Example:**

```julia
level = verbosity_to_int(Verbosity.Warn())  # Returns 2
```

### verbosity_to_bool

```@docs
verbosity_to_bool
```

Converts a `Verbosity.Type` to a boolean value for compatibility with packages that use boolean verbosity flags.

**Mapping:**
- `Verbosity.None()` → `false`
- All other levels → `true`

**Example:**

```julia
is_verbose = verbosity_to_bool(Verbosity.Info())  # Returns true
is_verbose = verbosity_to_bool(Verbosity.None())  # Returns false
```

### SciMLLogger

```@docs
SciMLLogger
```

Creates a specialized logger that can route messages to different destinations based on their log level.

**Parameters:**
- `info_repl::Bool = true` - Show info messages in REPL
- `warn_repl::Bool = true` - Show warning messages in REPL
- `error_repl::Bool = true` - Show error messages in REPL
- `info_file::Union{String, Nothing} = nothing` - File path for info messages
- `warn_file::Union{String, Nothing} = nothing` - File path for warning messages
- `error_file::Union{String, Nothing} = nothing` - File path for error messages

**Example:**

```julia
logger = SciMLLogger(
    info_repl = true,
    warn_repl = true,
    error_repl = true,
    warn_file = "warnings.log",
    error_file = "errors.log"
)

with_logger(logger) do
    # Your code with @SciMLMessage calls
end
```

## Internal Functions

These functions are used internally by the SciMLLogging system but are documented for completeness.

### message_level

```julia
message_level(verbose::AbstractVerbositySpecifier{true}, option::Symbol, group::Symbol)
```

Retrieves the logging level for a specific option and group from a verbosity specifier.

**Returns:** 
- A Julia logging level (e.g., `Logging.Info`)
- `nothing` if the level is `Verbosity.None()`
- An `Expr` if the level is `Verbosity.Code(expr)`

### emit_message

```julia
emit_message(f::Function, verbose::AbstractVerbositySpecifier{true}, option, group, file, line, _module)
emit_message(message::String, verbose::AbstractVerbositySpecifier{true}, option, group, file, line, _module)
emit_message(f, verbose::AbstractVerbositySpecifier{false}, option, group, file, line, _module)
```

Internal function that handles the actual emission of messages. This function:
1. Determines the appropriate log level
2. Evaluates message functions if provided
3. Emits the message through Julia's logging system
4. Returns nothing for disabled verbosity

## Usage Patterns

### Creating a Custom Verbosity Type

```julia
# Define options
mutable struct MyOptions
    level::Verbosity.Type
    
    function MyOptions(; level = Verbosity.Info())
        new(level)
    end
end

# Define verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
    
    function MyVerbosity{T}(; options = MyOptions()) where {T}
        new{T}(options)
    end
end

# Convenience constructor
MyVerbosity(; enable = true, kwargs...) = MyVerbosity{enable}(; kwargs...)
```

### Using with Julia's Logging System

```julia
using Logging

# Set minimum log level
with_logger(MinLevelLogger(Logging.Warn, current_logger())) do
    # Only warnings and errors will be shown
    @SciMLMessage("Info message", verbose, :info_opt, :group)  # Not shown
    @SciMLMessage("Warning", verbose, :warn_opt, :group)       # Shown
end
```

### Testing Verbosity

```julia
using Test

@testset "Verbosity Tests" begin
    verbose = MyVerbosity{true}(options = MyOptions(level = Verbosity.Info()))
    
    # Test that message is logged
    @test_logs (:info, "Test message") begin
        @SciMLMessage("Test message", verbose, :level, :options)
    end
    
    # Test that disabled verbosity produces no output
    silent = MyVerbosity{false}()
    @test_logs min_level=Logging.Debug begin
        @SciMLMessage("Should not appear", silent, :level, :options)
    end
end
```

## Type Stability Considerations

For performance-critical code, ensure type stability:

```julia
# Type-stable version
function process(data, verbose::V) where {V <: AbstractVerbositySpecifier}
    # The compiler knows the exact type of verbose
    @SciMLMessage("Processing", verbose, :status, :options)
    # ...
end

# Avoid type instability
function process_unstable(data, verbose)
    # Type of verbose is not known at compile time
    @SciMLMessage("Processing", verbose, :status, :options)
    # ...
end
```

## Thread Safety

The logging system is thread-safe, but if you're modifying verbosity options from multiple threads, use appropriate synchronization:

```julia
using Base.Threads

# Thread-safe modification
lock = ReentrantLock()

function update_verbosity(verbose, new_level)
    lock(lock) do
        verbose.options.level = new_level
    end
end
```

## Performance Notes

1. **Zero-cost when disabled**: When `T = false`, all `@SciMLMessage` calls are compiled away
2. **Lazy evaluation**: Use function form for expensive message generation
3. **Minimal overhead**: The macro expands to efficient code with minimal runtime overhead
4. **Type stability**: Use concrete types for best performance

## Compatibility

SciMLLogging.jl requires:
- Julia 1.10 or later
- Logging standard library
- LoggingExtras.jl for advanced features
- Moshi.jl for sum types

## See Also

- [Julia Logging Documentation](https://docs.julialang.org/en/stable/stdlib/Logging/)
- [LoggingExtras.jl](https://github.com/JuliaLogging/LoggingExtras.jl)
- [SciML Ecosystem](https://sciml.ai/)