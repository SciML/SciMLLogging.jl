# User Tutorial: Configuring Package Verbosity

This tutorial is for end users who want to control the verbosity of packages that use SciMLLogging.jl.
Each package will have it's own implementation of the `AbstractVerbositySpecifier` type, which defines the available verbosity options. This guide is meant to be a general guide to the specifics of SciMLLogging.jl, as well as give some examples of how the system is typically implemented. For details on the specific verbosity settings of a package, refer to that package's documentation.

## Quick Start

Packages that use SciMLLogging typically provide a keyword argument such as `verbose` or `verbosity` to control output. The easiest way to get started is with verbosity presets.

### Using Verbosity Presets (Recommended)

Most of the time, you'll want to use one of the built-in presets rather than configuring individual message categories:

**Available Presets:**
- `None()`: Log nothing at all 
- `Minimal()`: Only essential messages and warnings
- `Standard()`: Balanced verbosity suitable for typical usage
- `Detailed()`: Comprehensive verbosity for debugging and analysis
- `All()`: Maximum verbosity

```julia
using SciMLLogging

# No output at all - best for production
result = solve(problem, verbose = SolverVerbosity(None()))

# Minimal output - only critical messages
result = solve(problem, verbose = SolverVerbosity(Minimal()))

# Standard output - balanced for typical usage (recommended)
result = solve(problem, verbose = SolverVerbosity(Standard()))

# Detailed output - comprehensive information for debugging
result = solve(problem, verbose = SolverVerbosity(Detailed()))

# Maximum output - show everything
result = solve(problem, verbose = SolverVerbosity(All()))
```

### Custom Verbosity Configuration

For more control, you can configure individual message categories:

```julia
# Example: Customizing a solve's verbosity
verbose_settings = SolverVerbosity(
    initialization = InfoLevel(),      # Show startup messages
    iterations = Silent(),             # Don't show each iteration
    convergence = InfoLevel(),         # Show convergence information
    error_control = WarnLevel()        # Show warnings related to error control of the solver
)

result = solve(problem, verbose = verbose_settings)
```

**Message Levels:**
- `Silent()`: No output for this category
- `InfoLevel()`: Informational messages
- `WarnLevel()`: Warning messages
- `ErrorLevel()`: Error messages
- `CustomLevel(n)`: Custom level with integer value `n`

## Complete Working Example

Here's a full example showing how SciMLLogging works in practice, using a simulated "solver":

```@example
using SciMLLogging
using SciMLLogging: None, Standard, All
using ConcreteStructs: @concrete

# 1. Define a verbosity specifier (this would typically be done by a package)
@concrete struct SolverVerbosity <: AbstractVerbositySpecifier
    initialization
    iterations
    convergence
    linear_solve
    warnings
end

# Likewise the constructors would typically be implemented by a package
function SolverVerbosity(;
    initialization = Info(),
    iterations = Silent(),
    convergence = InfoLevel(),
    linear_solve = Silent(),
    warnings = WarnLevel()
    )
    SolverVerbosity(initialization, iterations, convergence, linear_solve, warnings)
end

# 2. Implement preset support
function SolverVerbosity(preset::None)
    SolverVerbosity(Silent(), Silent(), Silent(), Silent(), Silent())
end

function SolverVerbosity(preset::Standard)
    SolverVerbosity(InfoLevel(), Silent(), InfoLevel(), Silent(), WarnLevel())
end

function SolverVerbosity(preset::All)
    SolverVerbosity(InfoLevel(), InfoLevel(), InfoLevel(), InfoLevel(), WarnLevel())
end

# 3. Example solver function using SciMLLogging, the specific messages and where the messages are emitted
# would be decided by the package
function example_solver(problem; verbose = SolverVerbosity(Standard()), max_iterations = 10)
    @SciMLMessage("Initializing solver for problem of size $(length(problem))", verbose, :initialization)

    # Simulate solver iterations
    for i in 1:max_iterations
        @SciMLMessage("Iteration $i: residual = $(0.1^i)", verbose, :iterations)

        if i % 3 == 0
            @SciMLMessage("Solving linear system", verbose, :linear_solve)
        end

        if 0.1^i < 1e-6
            @SciMLMessage("Converged after $i iterations", verbose, :convergence)
            return "Solution found"
        end

        if i == 8
            @SciMLMessage("Solver may be slow to converge", verbose, :warnings)
        end
    end

    @SciMLMessage("Maximum iterations reached", verbose, :warnings)
    return "Max iterations"
end

# 4. Try different verbosity levels
problem = [1.0, 2.0, 3.0]

println("=== With Standard verbosity ===")
result1 = example_solver(problem, verbose = SolverVerbosity(Standard()))

println("\n=== With All verbosity ===")
result2 = example_solver(problem, verbose = SolverVerbosity(All()))

println("\n=== With None verbosity ===")
result3 = example_solver(problem, verbose = SolverVerbosity(None()))

println("\n=== With custom verbosity ===")
custom_verbose = SolverVerbosity(
    initialization = InfoLevel(),
    iterations = Silent(),
    convergence = InfoLevel(),
    linear_solve = InfoLevel(),
    warnings = ErrorLevel()  # Treat warnings as errors for this run
)
result4 = example_solver(problem, verbose = custom_verbose)
```
