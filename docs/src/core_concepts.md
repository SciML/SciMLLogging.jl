# Core Concepts

Understanding the core concepts of SciMLLogging.jl will help you use it effectively and create custom verbosity systems tailored to your needs.

## Design Philosophy

SciMLLogging.jl was designed with several key principles in mind:

1. **Zero-cost abstraction**: When verbosity is disabled (`T = false`), there is no runtime overhead
2. **Type safety**: Use Julia's type system to ensure correctness at compile time
3. **Composability**: Build complex verbosity systems from simple components
4. **Flexibility**: Support various use cases from simple boolean flags to complex hierarchical systems
5. **Integration**: Work seamlessly with Julia's built-in logging infrastructure

## Key Components

### AbstractVerbositySpecifier{T}

The foundation of the system is the `AbstractVerbositySpecifier{T}` abstract type:

```julia
abstract type AbstractVerbositySpecifier{T} end
```

The type parameter `T` is a boolean that determines whether verbosity is enabled:
- `T = true`: Verbosity is enabled, messages will be processed
- `T = false`: Verbosity is disabled, messages are compiled away with no runtime cost

### Verbosity Levels

The `Verbosity` type is a sum type (algebraic data type) that represents different verbosity levels:

```julia
@data Verbosity begin
    None        # No output
    Info        # Informational messages
    Warn        # Warning messages
    Error       # Error messages
    Level(Int)  # Custom log level
    Edge        # Special edge cases
    All         # Maximum verbosity
    Default     # Default settings
    Code(Expr)  # Custom code execution
end
```

Each level maps to Julia's logging levels or special behaviors:
- `None()` → No message emitted
- `Info()` → `Logging.Info`
- `Warn()` → `Logging.Warn`
- `Error()` → `Logging.Error`
- `Level(n)` → `Logging.LogLevel(n)`
- `Code(expr)` → Execute custom expression

### The @SciMLMessage Macro

The `@SciMLMessage` macro is the primary interface for emitting messages:

```julia
@SciMLMessage(message_or_function, verbosity, option, group)
```

Parameters:
- `message_or_function`: Either a string message or a 0-argument function that returns a string
- `verbosity`: An instance of `AbstractVerbositySpecifier`
- `option`: Symbol identifying the specific verbosity option (e.g., `:progress`)
- `group`: Symbol identifying the group containing the option (e.g., `:options`)

## Message Resolution

When a message is emitted, the system follows this resolution process:

1. Check if verbosity is enabled (`T = true`)
2. Access the specified group from the verbosity instance
3. Access the specified option from the group
4. Map the verbosity level to a Julia log level
5. Emit the message using Julia's logging system

Example flow:
```julia
verbose = MyVerbosity{true}(options = MyOptions(progress = Verbosity.Info()))
@SciMLMessage("Progress update", verbose, :progress, :options)
# 1. T = true, so proceed
# 2. Access verbose.options
# 3. Access options.progress → Verbosity.Info()
# 4. Map to Logging.Info
# 5. Emit at Info level
```

## Hierarchical Organization

SciMLLogging encourages organizing verbosity options hierarchically:

```julia
struct SolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    initialization::InitOptions
    iteration::IterationOptions
    convergence::ConvergenceOptions
    performance::PerformanceOptions
end
```

This allows for:
- Logical grouping of related options
- Independent control of different aspects
- Clear, self-documenting code structure

## Compile-Time Optimization

The type parameter design enables Julia's compiler to optimize away disabled verbosity:

```julia
function solve_with_verbosity(problem, verbose::AbstractVerbositySpecifier{T}) where T
    @SciMLMessage("Starting solve", verbose, :start, :init)
    # When T = false, the above line compiles to nothing
    
    # ... solving logic ...
end

# No runtime cost for disabled verbosity
solve_with_verbosity(problem, MyVerbosity{false}())
```

## Integration Points

SciMLLogging integrates with Julia's ecosystem at multiple levels:

1. **Logging.jl**: Built on standard logging infrastructure
2. **LoggingExtras.jl**: Support for advanced logging features
3. **Type system**: Leverages Julia's powerful type system
4. **Macros**: Uses metaprogramming for ergonomic API

## Best Practices

1. **Group related options**: Create separate structs for different aspects (e.g., solver options, I/O options)
2. **Provide defaults**: Always include default constructors with sensible defaults
3. **Use descriptive names**: Option names should clearly indicate what they control
4. **Document behavior**: Clearly document what each verbosity level does
5. **Consider performance**: Use function-based messages for expensive string construction

## Extensibility

The system is designed to be extended:

- Create custom verbosity types for domain-specific needs
- Add new verbosity levels if needed
- Integrate with external logging systems
- Build verbosity presets for common use cases

Understanding these core concepts will help you design effective verbosity systems for your SciML applications.