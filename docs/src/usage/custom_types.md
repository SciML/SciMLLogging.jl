# Creating Custom Verbosity Types

This guide shows how to create custom verbosity types tailored to your specific application needs.

## Basic Structure

A custom verbosity type requires three components:

1. Option structures to hold verbosity settings
2. A main type inheriting from `AbstractVerbositySpecifier{T}`
3. Constructors for convenience

## Step-by-Step Example

Let's create a verbosity system for a differential equation solver:

### Step 1: Define Option Groups

```julia
using SciMLLogging

# Initialization phase options
mutable struct InitializationOptions
    problem_setup::Verbosity.Type
    jacobian_analysis::Verbosity.Type
    memory_allocation::Verbosity.Type
    
    function InitializationOptions(;
        problem_setup = Verbosity.Info(),
        jacobian_analysis = Verbosity.None(),
        memory_allocation = Verbosity.Warn()
    )
        new(problem_setup, jacobian_analysis, memory_allocation)
    end
end

# Iteration phase options
mutable struct IterationOptions
    step_info::Verbosity.Type
    residual::Verbosity.Type
    timestep::Verbosity.Type
    
    function IterationOptions(;
        step_info = Verbosity.None(),
        residual = Verbosity.None(),
        timestep = Verbosity.Info()
    )
        new(step_info, residual, timestep)
    end
end

# Convergence checking options
mutable struct ConvergenceOptions
    tolerance_check::Verbosity.Type
    convergence_rate::Verbosity.Type
    warnings::Verbosity.Type
    
    function ConvergenceOptions(;
        tolerance_check = Verbosity.None(),
        convergence_rate = Verbosity.Info(),
        warnings = Verbosity.Warn()
    )
        new(tolerance_check, convergence_rate, warnings)
    end
end
```

### Step 2: Create Main Verbosity Type

```julia
struct SolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    init::InitializationOptions
    iter::IterationOptions
    conv::ConvergenceOptions
    
    function SolverVerbosity{T}(;
        init = InitializationOptions(),
        iter = IterationOptions(),
        conv = ConvergenceOptions()
    ) where {T}
        new{T}(init, iter, conv)
    end
end
```

### Step 3: Add Convenience Constructors

```julia
# Boolean constructor
function SolverVerbosity(enable::Bool = true; kwargs...)
    SolverVerbosity{enable}(; kwargs...)
end

# Preset constructor
function SolverVerbosity(preset::Symbol)
    if preset == :silent
        SolverVerbosity{false}()
    elseif preset == :minimal
        SolverVerbosity{true}(
            init = InitializationOptions(
                problem_setup = Verbosity.Warn(),
                jacobian_analysis = Verbosity.None(),
                memory_allocation = Verbosity.Error()
            ),
            iter = IterationOptions(
                step_info = Verbosity.None(),
                residual = Verbosity.None(),
                timestep = Verbosity.None()
            ),
            conv = ConvergenceOptions(
                tolerance_check = Verbosity.None(),
                convergence_rate = Verbosity.None(),
                warnings = Verbosity.Error()
            )
        )
    elseif preset == :normal
        SolverVerbosity{true}()  # Use defaults
    elseif preset == :verbose
        SolverVerbosity{true}(
            init = InitializationOptions(
                problem_setup = Verbosity.Info(),
                jacobian_analysis = Verbosity.Info(),
                memory_allocation = Verbosity.Info()
            ),
            iter = IterationOptions(
                step_info = Verbosity.Info(),
                residual = Verbosity.Info(),
                timestep = Verbosity.Info()
            ),
            conv = ConvergenceOptions(
                tolerance_check = Verbosity.Info(),
                convergence_rate = Verbosity.Info(),
                warnings = Verbosity.Warn()
            )
        )
    elseif preset == :debug
        # Everything at maximum verbosity
        all_info = InitializationOptions(
            problem_setup = Verbosity.Level(-1000),
            jacobian_analysis = Verbosity.Level(-1000),
            memory_allocation = Verbosity.Level(-1000)
        )
        # ... similar for other groups
        SolverVerbosity{true}(init = all_info, #= ... =#)
    else
        error("Unknown preset: $preset")
    end
end
```

## Advanced Patterns

### Universal Verbosity Constructor

Create a constructor that sets all fields to the same level:

```julia
function UniformVerbosity(::Type{T}, level::Verbosity.Type) where {T<:AbstractVerbositySpecifier}
    # Get all field names and types
    option_types = fieldtypes(T)
    
    # Create instances with all fields set to the same level
    options = map(option_types) do OT
        fields = fieldnames(OT)
        field_values = fill(level, length(fields))
        OT(field_values...)
    end
    
    T(options...)
end

# Usage
verbose = UniformVerbosity(SolverVerbosity{true}, Verbosity.Info())
```

### Builder Pattern

Implement a builder pattern for complex configurations:

```julia
mutable struct SolverVerbosityBuilder
    enable::Bool
    init::InitializationOptions
    iter::IterationOptions
    conv::ConvergenceOptions
    
    function SolverVerbosityBuilder()
        new(true, InitializationOptions(), IterationOptions(), ConvergenceOptions())
    end
end

# Builder methods
function with_initialization(builder::SolverVerbosityBuilder, options::InitializationOptions)
    builder.init = options
    builder
end

function with_debug_mode(builder::SolverVerbosityBuilder)
    # Set everything to debug level
    builder.init = InitializationOptions(
        problem_setup = Verbosity.Level(-1000),
        jacobian_analysis = Verbosity.Level(-1000),
        memory_allocation = Verbosity.Level(-1000)
    )
    # ... similar for other groups
    builder
end

function build(builder::SolverVerbosityBuilder)
    SolverVerbosity{builder.enable}(
        init = builder.init,
        iter = builder.iter,
        conv = builder.conv
    )
end

# Usage
verbose = SolverVerbosityBuilder() |>
    b -> with_debug_mode(b) |>
    build
```

### Hierarchical Defaults

Implement cascading defaults:

```julia
mutable struct HierarchicalOptions
    global_level::Verbosity.Type
    overrides::Dict{Symbol, Verbosity.Type}
    
    function HierarchicalOptions(level::Verbosity.Type = Verbosity.Info())
        new(level, Dict{Symbol, Verbosity.Type}())
    end
end

function get_level(opts::HierarchicalOptions, key::Symbol)
    get(opts.overrides, key, opts.global_level)
end

function set_override!(opts::HierarchicalOptions, key::Symbol, level::Verbosity.Type)
    opts.overrides[key] = level
end

# Usage
opts = HierarchicalOptions(Verbosity.Info())
set_override!(opts, :critical_error, Verbosity.Error())
set_override!(opts, :debug_info, Verbosity.Level(-1000))
```

## Integration with Package Options

Integrate verbosity with other package options:

```julia
struct SolverOptions{V<:AbstractVerbositySpecifier}
    tolerance::Float64
    max_iterations::Int
    algorithm::Symbol
    verbosity::V
    
    function SolverOptions(;
        tolerance = 1e-6,
        max_iterations = 1000,
        algorithm = :default,
        verbosity = SolverVerbosity(:normal)
    )
        new(tolerance, max_iterations, algorithm, verbosity)
    end
end

function solve(problem, options::SolverOptions)
    @SciMLMessage("Starting solve with $(options.algorithm)", 
                  options.verbosity, :problem_setup, :init)
    # ... solving logic
end
```

## Type-Stable Verbosity

Ensure type stability for performance:

```julia
# Type-stable version
struct TypeStableVerbosity{T, I<:InitializationOptions, It<:IterationOptions, C<:ConvergenceOptions} <: AbstractVerbositySpecifier{T}
    init::I
    iter::It
    conv::C
end

# This allows the compiler to specialize on exact types
```

## Testing Custom Types

Always test your custom verbosity types:

```julia
using Test
using Logging

@testset "SolverVerbosity Tests" begin
    # Test construction
    v = SolverVerbosity(:normal)
    @test v isa AbstractVerbositySpecifier{true}
    
    # Test message emission
    @test_logs (:info, "Test message") begin
        @SciMLMessage("Test message", v, :problem_setup, :init)
    end
    
    # Test disabled verbosity
    v_off = SolverVerbosity(false)
    @test_logs min_level=Logging.Debug begin
        @SciMLMessage("Should not appear", v_off, :problem_setup, :init)
    end
    
    # Test preset configurations
    v_debug = SolverVerbosity(:debug)
    @test v_debug.init.jacobian_analysis == Verbosity.Level(-1000)
end
```

## Best Practices for Custom Types

1. **Start simple**: Begin with basic options and add complexity as needed
2. **Document options**: Clearly explain what each option controls
3. **Provide presets**: Common configurations should be easy to access
4. **Test thoroughly**: Ensure all combinations work as expected
5. **Consider performance**: Type-stable designs are important for hot paths
6. **Use meaningful names**: Option names should be self-documenting
7. **Allow flexibility**: Users should be able to override any setting

## Example: Domain-Specific Verbosity

Here's a complete example for a machine learning training loop:

```julia
mutable struct DataOptions
    loading::Verbosity.Type
    preprocessing::Verbosity.Type
    augmentation::Verbosity.Type
end

mutable struct TrainingOptions
    epoch_start::Verbosity.Type
    batch_progress::Verbosity.Type
    loss::Verbosity.Type
    metrics::Verbosity.Type
    gradient_norm::Verbosity.Type
end

mutable struct ValidationOptions
    start::Verbosity.Type
    metrics::Verbosity.Type
    best_model::Verbosity.Type
end

struct MLVerbosity{T} <: AbstractVerbositySpecifier{T}
    data::DataOptions
    train::TrainingOptions
    val::ValidationOptions
end

# Usage in training loop
function train_model(model, data, verbose::MLVerbosity)
    @SciMLMessage("Loading dataset", verbose, :loading, :data)
    
    for epoch in 1:num_epochs
        @SciMLMessage("Epoch $epoch starting", verbose, :epoch_start, :train)
        
        for (i, batch) in enumerate(data)
            @SciMLMessage(verbose, :batch_progress, :train) do
                "Batch $i/$(length(data))"
            end
            
            loss = train_step!(model, batch)
            
            @SciMLMessage(verbose, :loss, :train) do
                "Loss: $(round(loss, digits=4))"
            end
        end
        
        @SciMLMessage("Starting validation", verbose, :start, :val)
        # ... validation logic
    end
end
```

This comprehensive approach to custom verbosity types enables you to create sophisticated logging systems tailored to your specific domain and requirements.