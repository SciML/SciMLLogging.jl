# SciMLVerbosity

[![Build Status](https://github.com/jClugstor/SciMLVerbosity.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jClugstor/SciMLVerbosity.jl/actions/workflows/CI.yml?query=branch%3Amain)

A flexible verbosity control system for the SciML ecosystem that allows fine-grained control over logging, warnings.

Installation

```julia
using Pkg
Pkg.add("SciMLVerbosity")
```

SciMLVerbosity.jl provides a structured approach to controlling verbosity in scientific computing workflows. It enables:

Fine-grained control over which messages are displayed and at what levels
Hierarchical organization of verbosity settings by component and message type

Consistent logging patterns across the SciML ecosystem

# Basic Usage

```julia
using SciMLVerbosity
using Logging

# Create a simple verbosity structure
mutable struct MyVerbosityOptions
    algorithm_choice::Verbosity.Type
    iteration_progress::Verbosity.Type

    function MyVerbosityOptions(;
            algorithm_choice = Verbosity.Warn(),
            iteration_progress = Verbosity.Info()
    )
        new(algorithm_choice, iteration_progress)
    end
end

struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyVerbosityOptions

    function MyVerbosity{T}(;
            options = MyVerbosityOptions()
    ) where {T}
        new{T}(options)
    end
end

# Create enabled verbosity
verbose = MyVerbosity{true}()

# Log messages at different levels
@SciMLMessage("Selected algorithm: GMRES", verbose, :algorithm_choice, :options)
@SciMLMessage("Iteration 5/100 complete", verbose, :iteration_progress, :options)

# Use a function to create the message
@SciMLMessage(verbose, :iteration_progress, :options) do
    iter = 10
    total = 100
    progress = iter / total * 100
    "Iteration $iter/$total complete ($(round(progress, digits=1))%)"
end
```

# Verbosity Levels

SciMLVerbosity supports several verbosity levels:

  - `Verbosity.None()`: No output
  - `Verbosity.Info()`: Informational messages
  - `Verbosity.Warn()`: Warning messages
  - `Verbosity.Error()`: Error messages
  - `Verbosity.Level(n)`: Custom logging level (using Julia's LogLevel(n))
  - `Verbosity.Edge()`: Special case for edge behaviors
  - `Verbosity.All()`: Maximum verbosity
  - `Verbosity.Default()`: Default verbosity settings

# Creating Custom Verbosity Types

 1. Define a structure for each group of verbosity options
 2. Create a main verbosity struct that inherits from AbstractVerbositySpecifier{T}
 3. Define constructors for easy creation and default values
    Example:

```julia
# Define option groups
mutable struct SolverOptions
    iterations::Verbosity.Type
    convergence::Verbosity.Type

    function SolverOptions(;
            iterations = Verbosity.Info(),
            convergence = Verbosity.Warn()
    )
        new(iterations, convergence)
    end
end

mutable struct PerformanceOptions
    timing::Verbosity.Type
    memory::Verbosity.Type

    function PerformanceOptions(;
            timing = Verbosity.None(),
            memory = Verbosity.None()
    )
        new(timing, memory)
    end
end

# Main verbosity struct
struct MyAppVerbosity{T} <: AbstractVerbositySpecifier{T}
    solver::SolverOptions
    performance::PerformanceOptions

    function MyAppVerbosity{T}(;
            solver = SolverOptions(),
            performance = PerformanceOptions()
    ) where {T}
        new{T}(solver, performance)
    end
end

# Constructor with enable/disable parameter
MyAppVerbosity(; enable = true, kwargs...) = MyAppVerbosity{enable}(; kwargs...)
```

Integration with Julia's Logging System
SciMLVerbosity integrates with Julia's built-in logging system. You can customize how logs are handled with the SciMLLogger,
which allows you to direct logs to different outputs. Or you can use your own logger based on the Julia logging system or LoggingExtras.jl.

```julia
# Create a logger that sends warnings to a file
log_file = "warnings.log"
logger = SciMLLogger(
    info_repl = true,     # Show info in REPL
    warn_repl = true,     # Show warnings in REPL
    error_repl = true,    # Show errors in REPL
    warn_file = log_file  # Also log warnings to file
)

# Use the logger
with_logger(logger) do
    # Your code with @SciMLMessage calls
end
```

Disabling Verbosity
To completely disable verbosity without changing your code:

```julia
# Create disabled verbosity
silent = MyVerbosity{false}()

# This won't produce any output
@SciMLMessage("This message won't be shown", silent, :algorithm_choice, :options)
```

# License

SciMLVerbosity.jl is licensed under the MIT License.
