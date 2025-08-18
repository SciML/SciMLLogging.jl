# Simple Example

This example demonstrates a basic use case of SciMLLogging.jl for a simple application.

## Complete Example

```julia
using SciMLLogging
using Logging

# Step 1: Define verbosity options for your application
mutable struct ApplicationOptions
    startup::Verbosity.Type
    processing::Verbosity.Type
    results::Verbosity.Type
    errors::Verbosity.Type
    
    function ApplicationOptions(;
        startup = Verbosity.Info(),
        processing = Verbosity.None(),  # Silent by default
        results = Verbosity.Info(),
        errors = Verbosity.Error()
    )
        new(startup, processing, results, errors)
    end
end

# Step 2: Create the verbosity type
struct ApplicationVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::ApplicationOptions
    
    function ApplicationVerbosity{T}(;
        options = ApplicationOptions()
    ) where {T}
        new{T}(options)
    end
end

# Convenience constructors
ApplicationVerbosity(; enable = true, kwargs...) = 
    ApplicationVerbosity{enable}(; kwargs...)

function ApplicationVerbosity(level::Symbol)
    options = if level == :silent
        ApplicationOptions(
            startup = Verbosity.None(),
            processing = Verbosity.None(),
            results = Verbosity.None(),
            errors = Verbosity.Error()  # Still show errors
        )
    elseif level == :normal
        ApplicationOptions()  # Use defaults
    elseif level == :verbose
        ApplicationOptions(
            startup = Verbosity.Info(),
            processing = Verbosity.Info(),
            results = Verbosity.Info(),
            errors = Verbosity.Warn()
        )
    else
        error("Unknown verbosity level: $level")
    end
    
    ApplicationVerbosity{level != :silent}(options = options)
end

# Step 3: Use in your application
function process_data(data, verbose::ApplicationVerbosity = ApplicationVerbosity(:normal))
    @SciMLMessage("Starting data processing", verbose, :startup, :options)
    
    results = Float64[]
    errors = Int[]
    
    for (i, item) in enumerate(data)
        @SciMLMessage(verbose, :processing, :options) do
            "Processing item $i/$(length(data))"
        end
        
        try
            # Simulate processing
            if item < 0
                throw(DomainError(item, "Negative values not allowed"))
            end
            
            result = sqrt(item) + randn()
            push!(results, result)
            
        catch e
            push!(errors, i)
            @SciMLMessage("Error processing item $i: $e", verbose, :errors, :options)
        end
    end
    
    @SciMLMessage(verbose, :results, :options) do
        success_rate = (length(data) - length(errors)) / length(data) * 100
        "Processing complete: $(round(success_rate, digits=1))% success rate"
    end
    
    return results, errors
end

# Example usage
function main()
    # Generate sample data
    data = [1.0, 4.0, 9.0, -1.0, 16.0, 25.0]
    
    println("=" ^ 50)
    println("Running with normal verbosity:")
    println("=" ^ 50)
    results, errors = process_data(data, ApplicationVerbosity(:normal))
    
    println("\n" * "=" ^ 50)
    println("Running with verbose mode:")
    println("=" ^ 50)
    results, errors = process_data(data, ApplicationVerbosity(:verbose))
    
    println("\n" * "=" ^ 50)
    println("Running in silent mode:")
    println("=" ^ 50)
    results, errors = process_data(data, ApplicationVerbosity(:silent))
    
    println("\nResults: ", results)
    println("Errors at indices: ", errors)
end

# Run the example
main()
```

## Output Explanation

When you run this example, you'll see different output based on the verbosity level:

### Normal Mode
```
Starting data processing
Error processing item 4: DomainError(-1.0, "Negative values not allowed")
Processing complete: 83.3% success rate
```

### Verbose Mode
```
Starting data processing
Processing item 1/6
Processing item 2/6
Processing item 3/6
Processing item 4/6
Error processing item 4: DomainError(-1.0, "Negative values not allowed")
Processing item 5/6
Processing item 6/6
Processing complete: 83.3% success rate
```

### Silent Mode
```
Error processing item 4: DomainError(-1.0, "Negative values not allowed")
```

## Key Takeaways

1. **Structured Options**: Group related verbosity settings together
2. **Flexible Levels**: Different components can have different verbosity levels
3. **Presets**: Provide convenient presets for common use cases
4. **Lazy Evaluation**: Use functions for messages that require computation
5. **Error Handling**: Even in silent mode, critical errors are shown

## Extending the Example

You can extend this example by:

### Adding File Logging

```julia
using LoggingExtras

function process_data_with_logging(data, verbose, log_file = "process.log")
    # Set up file logging
    logger = TeeLogger(
        current_logger(),
        FileLogger(log_file)
    )
    
    with_logger(logger) do
        process_data(data, verbose)
    end
end
```

### Adding Progress Bars

```julia
function process_data_with_progress(data, verbose)
    @SciMLMessage("Starting data processing", verbose, :startup, :options)
    
    results = Float64[]
    total = length(data)
    
    for (i, item) in enumerate(data)
        # Show progress as percentage
        if verbose.options.processing != Verbosity.None()
            progress = i / total * 100
            bar_length = 20
            filled = Int(round(progress / 100 * bar_length))
            bar = "█" ^ filled * "░" ^ (bar_length - filled)
            
            @SciMLMessage(verbose, :processing, :options) do
                "\r[$bar] $(round(progress, digits=1))%"
            end
        end
        
        # Process item...
    end
end
```

### Adding Statistics

```julia
function process_data_with_stats(data, verbose)
    stats = Dict{Symbol, Any}()
    stats[:start_time] = time()
    
    results, errors = process_data(data, verbose)
    
    stats[:end_time] = time()
    stats[:duration] = stats[:end_time] - stats[:start_time]
    stats[:items_processed] = length(data)
    stats[:errors_count] = length(errors)
    
    @SciMLMessage(verbose, :results, :options) do
        """
        Processing Statistics:
        - Duration: $(round(stats[:duration], digits=3))s
        - Items: $(stats[:items_processed])
        - Errors: $(stats[:errors_count])
        - Rate: $(round(stats[:items_processed] / stats[:duration], digits=1)) items/s
        """
    end
    
    return results, errors, stats
end
```

This simple example demonstrates the core functionality of SciMLLogging.jl and provides a foundation for building more complex verbosity systems.