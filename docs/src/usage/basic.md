# Basic Usage

This guide covers the fundamental usage patterns of SciMLLogging.jl.

## Simple String Messages

The most basic use of `@SciMLMessage` is with a simple string:

```julia
using SciMLLogging
using Logging

# Define a simple verbosity structure
mutable struct SimpleOptions
    info_level::Verbosity.Type
end

struct SimpleVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::SimpleOptions
end

# Create and use
verbose = SimpleVerbosity{true}(SimpleOptions(Verbosity.Info()))
@SciMLMessage("This is an info message", verbose, :info_level, :options)
```

## Dynamic Messages with Functions

For messages that require computation, use a function:

```julia
# Variables from surrounding scope
x = 10
y = 20

@SciMLMessage(verbose, :info_level, :options) do
    result = x * y
    "The product of $x and $y is $result"
end
```

This approach is beneficial because:
- The computation only happens if the message will be emitted
- You can access variables from the surrounding scope
- Complex formatting can be encapsulated

## Controlling Verbosity Levels

You can easily adjust verbosity levels:

```julia
# Create options with different levels
options = SimpleOptions(Verbosity.Warn())  # Only warnings and above

# Change level dynamically
options.info_level = Verbosity.Info()  # Now info messages will show
options.info_level = Verbosity.None()  # Disable this category
```

## Enabling and Disabling Verbosity

Control whether any messages are emitted using the type parameter:

```julia
# Enabled - messages will be processed
verbose_on = SimpleVerbosity{true}(SimpleOptions(Verbosity.Info()))
@SciMLMessage("This will be shown", verbose_on, :info_level, :options)

# Disabled - no runtime cost
verbose_off = SimpleVerbosity{false}(SimpleOptions(Verbosity.Info()))
@SciMLMessage("This will not be shown", verbose_off, :info_level, :options)
```

## Working with Multiple Groups

Organize related options into groups:

```julia
mutable struct IOOptions
    file_read::Verbosity.Type
    file_write::Verbosity.Type
end

mutable struct ComputeOptions
    iterations::Verbosity.Type
    convergence::Verbosity.Type
end

struct AppVerbosity{T} <: AbstractVerbositySpecifier{T}
    io::IOOptions
    compute::ComputeOptions
end

# Use different groups
verbose = AppVerbosity{true}(
    IOOptions(Verbosity.Info(), Verbosity.Warn()),
    ComputeOptions(Verbosity.None(), Verbosity.Error())
)

@SciMLMessage("Reading file", verbose, :file_read, :io)
@SciMLMessage("Writing results", verbose, :file_write, :io)
@SciMLMessage("Iteration 10", verbose, :iterations, :compute)
@SciMLMessage("Failed to converge", verbose, :convergence, :compute)
```

## Using Custom Log Levels

For fine-grained control, use custom log levels:

```julia
options = SimpleOptions(Verbosity.Level(-1000))  # Debug level
@SciMLMessage("Debug information", verbose, :info_level, :options)

options.info_level = Verbosity.Level(1000)  # Critical level
@SciMLMessage("Critical error", verbose, :info_level, :options)
```

## Conditional Message Generation

Use functions for expensive message generation that should only run when needed:

```julia
@SciMLMessage(verbose, :info_level, :options) do
    # This expensive computation only runs if the message will be shown
    data = expensive_analysis()
    stats = compute_statistics(data)
    "Analysis complete: mean=$(stats.mean), std=$(stats.std)"
end
```

## Pattern: Boolean Convenience

Create a convenience constructor for simple on/off control:

```julia
function SimpleVerbosity(enable::Bool = true; level = Verbosity.Info())
    options = SimpleOptions(enable ? level : Verbosity.None())
    SimpleVerbosity{enable}(options)
end

# Easy to use
verbose = SimpleVerbosity(true)   # Enabled with Info level
silent = SimpleVerbosity(false)   # Completely disabled
```

## Pattern: Preset Configurations

Create preset configurations for common use cases:

```julia
function SimpleVerbosity(preset::Symbol)
    options = if preset == :debug
        SimpleOptions(Verbosity.Level(-1000))
    elseif preset == :normal
        SimpleOptions(Verbosity.Info())
    elseif preset == :quiet
        SimpleOptions(Verbosity.Warn())
    elseif preset == :silent
        SimpleOptions(Verbosity.None())
    else
        error("Unknown preset: $preset")
    end
    SimpleVerbosity{preset != :silent}(options)
end

# Use presets
verbose = SimpleVerbosity(:debug)   # Maximum verbosity
verbose = SimpleVerbosity(:quiet)   # Only warnings and errors
```

## Working with Existing Code

To integrate with code that expects boolean verbosity:

```julia
# Convert to boolean
is_verbose = verbosity_to_bool(options.info_level)
legacy_function(data, verbose = is_verbose)

# Convert to integer verbosity levels
verbosity_int = verbosity_to_int(options.info_level)
other_package_function(data, verbosity = verbosity_int)
```

## Best Practices

1. **Use descriptive option names**: `:algorithm_selection` instead of `:alg`
2. **Group related options**: Keep I/O, computation, and debugging separate
3. **Provide sensible defaults**: Most users shouldn't need to configure everything
4. **Document verbosity levels**: Be clear about what each level shows
5. **Use functions for expensive messages**: Don't compute unless necessary
6. **Test with verbosity disabled**: Ensure your code works with `T = false`

## Common Patterns Summary

```julia
# Simple on/off
verbose = SimpleVerbosity(true)

# Specific level
verbose = SimpleVerbosity{true}(SimpleOptions(Verbosity.Warn()))

# Dynamic message
@SciMLMessage(verbose, :level, :group) do
    "Computed message: $(expensive_computation())"
end

# Conditional verbosity
verbose = if debug_mode
    SimpleVerbosity(:debug)
else
    SimpleVerbosity(:normal)
end
```