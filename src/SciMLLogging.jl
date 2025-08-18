"""
    SciMLLogging

A flexible verbosity control system for the SciML ecosystem that provides fine-grained 
control over logging and messaging in scientific computing workflows.

# Exports
- [`AbstractVerbositySpecifier`](@ref): Base type for verbosity specifiers
- [`Verbosity`](@ref): Sum type for verbosity levels
- [`@SciMLMessage`](@ref): Macro for emitting messages
- [`verbosity_to_int`](@ref): Convert verbosity to integer
- [`verbosity_to_bool`](@ref): Convert verbosity to boolean
- [`SciMLLogger`](@ref): Create custom logger with routing

# Basic Usage
```julia
using SciMLLogging

# Define verbosity options
mutable struct MyOptions
    level::Verbosity.Type
end

# Create verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end

# Use it
verbose = MyVerbosity{true}(MyOptions(Verbosity.Info()))
@SciMLMessage("Hello, SciML!", verbose, :level, :options)
```

See the documentation for detailed usage guides and examples.
"""
module SciMLLogging

import Moshi.Data: @data
import Moshi.Match: @match
import Logging
using LoggingExtras

include("utils.jl")

# Export public API
export AbstractVerbositySpecifier, Verbosity
export @SciMLMessage
export verbosity_to_int, verbosity_to_bool
export SciMLLogger

end
