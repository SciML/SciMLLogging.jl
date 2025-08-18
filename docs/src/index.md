# SciMLLogging.jl

```@meta
CurrentModule = SciMLLogging
```

## Overview

SciMLLogging.jl provides a flexible and powerful verbosity control system for the SciML ecosystem. It enables fine-grained control over logging and messaging in scientific computing workflows, allowing developers and users to manage what information is displayed during computation.

## Key Features

- **Fine-grained control**: Control individual aspects of logging with specific verbosity settings
- **Hierarchical organization**: Group related verbosity options into logical categories
- **Type-safe interface**: Leverage Julia's type system for compile-time safety
- **Integration with Julia's logging**: Built on top of Julia's standard logging infrastructure
- **Zero-cost abstraction**: Disabled verbosity has no runtime overhead
- **Extensible design**: Easy to create custom verbosity types for your specific needs

## Quick Example

```julia
using SciMLLogging
using Logging

# Define verbosity options
mutable struct MyOptions
    algorithm::Verbosity.Type
    progress::Verbosity.Type
    
    function MyOptions(;
        algorithm = Verbosity.Info(),
        progress = Verbosity.Warn()
    )
        new(algorithm, progress)
    end
end

# Create verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end

# Use it
verbose = MyVerbosity{true}(MyOptions())
@SciMLMessage("Algorithm selected: GMRES", verbose, :algorithm, :options)
```

## Installation

SciMLLogging.jl can be installed using the Julia package manager:

```julia
using Pkg
Pkg.add("SciMLLogging")
```

## Getting Help

- Check the [Getting Started](getting_started.md) guide for a quick introduction
- Browse the [Core Concepts](core_concepts.md) to understand the design
- See the Usage Guide section for detailed instructions
- Look at the Examples section for practical use cases
- Consult the [API Reference](api.md) for complete documentation

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests to the [GitHub repository](https://github.com/SciML/SciMLLogging.jl).

## License

SciMLLogging.jl is licensed under the MIT License.