# Getting Started

This guide will help you get started with SciMLLogging.jl quickly.

## Installation

First, install the package using Julia's package manager:

```julia
using Pkg
Pkg.add("SciMLLogging")
```

## Basic Setup

The core workflow with SciMLLogging involves three steps:

1. Define your verbosity options structure
2. Create a verbosity type that inherits from `AbstractVerbositySpecifier`
3. Use the `@SciMLMessage` macro to emit messages

### Step 1: Define Verbosity Options

Create a mutable struct that holds your verbosity settings:

```julia
using SciMLLogging

mutable struct MyVerbosityOptions
    startup::Verbosity.Type
    progress::Verbosity.Type
    warnings::Verbosity.Type
    
    function MyVerbosityOptions(;
        startup = Verbosity.Info(),
        progress = Verbosity.None(),
        warnings = Verbosity.Warn()
    )
        new(startup, progress, warnings)
    end
end
```

### Step 2: Create Verbosity Type

Define a type that wraps your options and inherits from `AbstractVerbositySpecifier{T}`:

```julia
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyVerbosityOptions
    
    function MyVerbosity{T}(;
        options = MyVerbosityOptions()
    ) where {T}
        new{T}(options)
    end
end

# Convenience constructor
MyVerbosity(; enable = true, kwargs...) = MyVerbosity{enable}(; kwargs...)
```

### Step 3: Use the Verbosity System

Now you can use your verbosity system in your code:

```julia
using Logging

# Create an enabled verbosity instance
verbose = MyVerbosity(enable = true)

# Emit messages at different levels
@SciMLMessage("Application starting...", verbose, :startup, :options)
@SciMLMessage("Processing item 1/100", verbose, :progress, :options)
@SciMLMessage("Memory usage high", verbose, :warnings, :options)

# Create a disabled verbosity instance (no output)
silent = MyVerbosity(enable = false)
@SciMLMessage("This won't be shown", silent, :startup, :options)
```

## Verbosity Levels

SciMLLogging provides several built-in verbosity levels:

- `Verbosity.None()` - No output
- `Verbosity.Info()` - Informational messages
- `Verbosity.Warn()` - Warning messages  
- `Verbosity.Error()` - Error messages
- `Verbosity.Level(n)` - Custom log level with integer n
- `Verbosity.All()` - Maximum verbosity
- `Verbosity.Default()` - Default settings

## Dynamic Messages

You can use functions to generate messages dynamically:

```julia
iter = 5
total = 100

@SciMLMessage(verbose, :progress, :options) do
    percentage = iter / total * 100
    "Progress: $iter/$total ($(round(percentage, digits=1))%)"
end
```

## Next Steps

- Learn about [Core Concepts](core_concepts.md) to understand the design philosophy
- Explore [Creating Custom Verbosity Types](usage/custom_types.md) for more complex scenarios
- See [Integration with Julia's Logging System](usage/logging_integration.md) to customize log output
- Check out the Examples section for real-world use cases