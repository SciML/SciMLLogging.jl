# Verbosity Specifiers

Verbosity specifiers are the core mechanism for controlling which messages are emitted and at what level. They provide fine-grained control over different categories of output in your applications. These are not provided by the SciMLLogging package, but instead must be implemented by a package wishing to use the SciMLLogging interface. 

## Abstract Base Type

```@docs
AbstractVerbositySpecifier
```

## Creating Verbosity Specifiers

Package authors can define their own verbosity specifier types in two ways:

### Using the `@verbosity_specifier` Macro (Recommended)

The `@verbosity_specifier` macro automatically generates a parametric struct with constructors, presets, and group support:

```@docs
@verbosity_specifier
```

### Manual Implementation

Alternatively, you can manually define verbosity specifier types by subtyping `AbstractVerbositySpecifier`:

```julia
using SciMLLogging
using ConcreteStructs: @concrete

@concrete struct MyPackageVerbosity <: AbstractVerbositySpecifier
    initialization   # Controls startup and setup messages
    progress         # Controls progress and iteration updates
    convergence      # Controls convergence-related messages
    diagnostics      # Controls diagnostic messages
    performance      # Controls performance-related messages
end
```

**Note:** It is recommended that the verbosity specifier is concretely typed for several performance reasons:

- **Type stability**: Eliminates type instabilities that can hurt performance
- **Compile-time optimization**: Allows the compiler to generate more efficient code

The `@concrete` macro from ConcreteStructs.jl is a convenient way to automate that. 

## Configuring Message Categories

Each field in a verbosity specifier can be set to any `AbstractMessageLevel`:

```julia
# Create a custom configuration
custom_verbosity = MyPackageVerbosity(
    initialization = InfoLevel(),     # Show startup information
    progress = Silent(),             # Hide progress updates
    convergence = InfoLevel(),        # Show convergence status
    diagnostics = WarnLevel(),       # Show diagnostic messages
    performance = InfoLevel()        # Show performance info
)
```

## Integration with Packages

Package authors should provide verbosity arguments in their main functions:

```julia
function solve_problem(problem; verbose = MyPackageVerbosity(Standard()), kwargs...)
    @SciMLMessage("Starting computation", verbose, :initialization)

    for i in 1:max_iterations
        @SciMLMessage("Iteration $i", verbose, :progress)

        # ... computation ...

        if converged
            @SciMLMessage("Converged after $i iterations", verbose, :convergence)
            break
        end
    end

    return result
end
```