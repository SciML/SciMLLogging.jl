# Getting Started with SciMLLogging.jl

This guide will help you get up and running with SciMLLogging.jl quickly. SciMLLogging provides fine-grained verbosity control for scientific computing workflows in Julia.

## Basic Concepts

SciMLLogging.jl is built around three core concepts:

1. **Message Levels**: Define the importance of messages (`Silent()`, `InfoLevel()`, `WarnLevel()`, `ErrorLevel()`)
2. **Verbosity Specifiers**: Control which categories of messages are shown and at what level
3. **Verbosity Presets**: Predefined settings for common use cases (`None()`, `Minimal()`, `Standard()`, `Detailed()`, `All()`)

## Quick Start with Presets

The easiest way to get started is with verbosity presets. Most packages that use SciMLLogging will provide these options:

```julia
using SciMLLogging

# Use presets for quick setup (assuming MyPackageVerbosity from a package)
none_verbose = MyPackageVerbosity(None())      # No output (best for production)
minimal_verbose = MyPackageVerbosity(Minimal()) # Only essential messages
standard_verbose = MyPackageVerbosity(Standard()) # Balanced output (recommended)
detailed_verbose = MyPackageVerbosity(Detailed()) # Comprehensive output for debugging
all_verbose = MyPackageVerbosity(All())        # Maximum verbosity

# Use in your code
result = solve(problem, verbose = standard_verbose)
```
## Custom Configuration

For more control, packages typically allow you to configure individual message categories:

```julia
# Custom configuration
custom_verbose = MyPackageVerbosity(
    startup = InfoLevel(),      # Show startup messages
    progress = Silent(),        # Hide progress updates
    diagnostics = WarnLevel(),  # Show diagnostic warnings
    performance = InfoLevel()   # Show performance info
)

result = solve(problem, verbose = custom_verbose)
```

**Message Levels:**
- `Silent()`: No output for this category
- `InfoLevel()`: Informational messages
- `WarnLevel()`: Warning messages
- `ErrorLevel()`: Error messages
- `CustomLevel(n)`: Custom level with integer value

## Logging Backends

By default, SciMLLogging integrates with Julia's standard logging system, but there is also a backend that uses `Core.println` to emit messages. This is configurable via a [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl) preference setting.

### Standard Julia Logging (Default)

```julia
using Logging

# Use with Julia's built-in loggers
with_logger(ConsoleLogger(stdout, Logging.Info)) do
    # Your code here with verbose output
    run_simulation(verbose = standard_verbose)
end
```
### Simple Console Output

For simpler output without the logging infrastructure:

```julia
# Switch to simple println-style output (r)
SciMLLogging.set_logging_backend("core")
```
This makes the logging compatible with binary building via JuliaC and reduces the overhead. 

### Switching Back

To switch back to using the logging infrastructure:
```julia
SciMLLogging.set_logging_backend("logging")
```
Note that you will need to restart Julia for this to take affect. 

## Saving Output to Files

Combine with Julia's logging to save output:

```julia
using Logging

# Save all output to a file
open("computation_log.txt", "w") do io
    with_logger(SimpleLogger(io)) do
        result = long_computation(verbose = MyPackageVerbosity(Standard()))
    end
end

# Or use SciMLLogger for more control
logger = SciMLLogger(
    info_file = "info.log",
    warn_file = "warnings.log",
    error_file = "errors.log"
)

with_logger(logger) do
    result = computation(verbose = MyPackageVerbosity(Detailed()))
end
```

## Next Steps

- **For end users**: See the [User Tutorial: Configuring Package Verbosity](@ref) for detailed information about controlling package verbosity
- **For package developers**: Check the [Developer Tutorial: Adding SciMLLogging to Your Package](@ref) to learn how to integrate SciMLLogging into your packages

## Getting Help

If you encounter issues:
- Check package-specific documentation for their verbosity settings
- Use maximum verbosity (`All()`) to see what's happening
- Consult the Julia logging documentation for advanced output control
- Visit the [SciML Community page](https://sciml.ai/community/) for support