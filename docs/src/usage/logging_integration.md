# Integration with Julia's Logging System

SciMLLogging.jl is built on top of Julia's standard logging infrastructure, providing seamless integration and advanced features through LoggingExtras.jl.

## Understanding the Logging Pipeline

When you use `@SciMLMessage`, the message flows through this pipeline:

1. **Verbosity Check**: The verbosity level is checked
2. **Level Mapping**: The Verbosity type is mapped to a Julia LogLevel
3. **Message Emission**: The message is emitted via Julia's logging system
4. **Logger Processing**: The current logger handles the message

## Using the SciMLLogger

SciMLLogging provides a specialized logger that can route messages to different destinations:

```julia
using SciMLLogging
using Logging

# Create a logger with custom routing
logger = SciMLLogger(
    info_repl = true,      # Show info in REPL
    warn_repl = true,      # Show warnings in REPL  
    error_repl = true,     # Show errors in REPL
    info_file = "info.log",    # Log info to file
    warn_file = "warnings.log", # Log warnings to file
    error_file = "errors.log"   # Log errors to file
)

# Use the logger
with_logger(logger) do
    # Your code with @SciMLMessage calls
    @SciMLMessage("Information", verbose, :option, :group)
    @SciMLMessage("Warning", verbose, :warning_option, :group)
end
```

## Custom Logger Configuration

You can create more sophisticated logging setups using LoggingExtras.jl:

```julia
using LoggingExtras
using Logging

# Create a logger that filters by group
group_filter = EarlyFilteredLogger(current_logger()) do log
    # Only show messages from the :performance group
    get(log.kwargs, :_group, nothing) == :performance
end

# Create a logger that adds timestamps
timestamped = TransformerLogger(current_logger()) do log
    merge(log, (message = "[$(now())] $(log.message)",))
end

# Combine multiple loggers
combined = TeeLogger(
    group_filter,
    timestamped,
    FileLogger("combined.log")
)

with_logger(combined) do
    # Messages will be processed by all loggers
    @SciMLMessage("Performance metric", verbose, :timing, :performance)
end
```

## Filtering Messages

### By Level

```julia
# Only show warnings and above
filtered_logger = MinLevelLogger(Logging.Warn, current_logger())

with_logger(filtered_logger) do
    @SciMLMessage("Info - won't show", verbose_info, :option, :group)
    @SciMLMessage("Warning - will show", verbose_warn, :option, :group)
end
```

### By Custom Criteria

```julia
# Filter based on module
module_filter = EarlyFilteredLogger(current_logger()) do log
    log._module == MyModule
end

# Filter based on message content
content_filter = EarlyFilteredLogger(current_logger()) do log
    !occursin("DEBUG", log.message)
end
```

## File Logging

### Simple File Output

```julia
# Log everything to a file
file_logger = FileLogger("application.log")

with_logger(file_logger) do
    @SciMLMessage("This goes to file", verbose, :option, :group)
end
```

### Rotating Logs

```julia
using Dates

# Create date-stamped log files
function create_dated_logger()
    filename = "logs/app_$(Dates.format(now(), "yyyy-mm-dd")).log"
    FileLogger(filename)
end

# Use different files for different runs
with_logger(create_dated_logger()) do
    # Your application code
end
```

### Separate Files by Level

```julia
# Route different levels to different files
info_file = FileLogger("info.log", min_level=Logging.Info)
error_file = FileLogger("errors.log", min_level=Logging.Error)

multi_file = TeeLogger(info_file, error_file)

with_logger(multi_file) do
    @SciMLMessage("Info message", verbose, :info_opt, :group)
    @SciMLMessage("Error message", verbose, :error_opt, :group)
end
```

## Formatting Messages

### Custom Format

```julia
# Add custom formatting
formatter = TransformerLogger(current_logger()) do log
    # Add prefix based on level
    prefix = if log.level == Logging.Error
        "❌ ERROR: "
    elseif log.level == Logging.Warn
        "⚠️  WARN: "
    elseif log.level == Logging.Info
        "ℹ️  INFO: "
    else
        "📝 "
    end
    
    merge(log, (message = prefix * log.message,))
end

with_logger(formatter) do
    @SciMLMessage("Something happened", verbose, :option, :group)
end
```

### JSON Logging

```julia
using JSON3

# Log as JSON for structured logging systems
json_logger = TransformerLogger(current_logger()) do log
    json_msg = JSON3.write(Dict(
        "timestamp" => now(),
        "level" => string(log.level),
        "message" => log.message,
        "module" => string(log._module),
        "file" => log._file,
        "line" => log._line,
        "group" => get(log.kwargs, :_group, nothing)
    ))
    merge(log, (message = json_msg,))
end
```

## Performance Considerations

### Lazy Evaluation

The function form of `@SciMLMessage` ensures expensive computations only run when needed:

```julia
@SciMLMessage(verbose, :option, :group) do
    # This only runs if the message will be shown
    expensive_result = compute_something_expensive()
    "Result: $expensive_result"
end
```

### Batching Messages

For high-frequency logging, consider batching:

```julia
mutable struct BatchedLogger
    messages::Vector{String}
    batch_size::Int
    logger::AbstractLogger
    
    function BatchedLogger(batch_size::Int = 100)
        new(String[], batch_size, current_logger())
    end
end

function log_message(bl::BatchedLogger, msg::String)
    push!(bl.messages, msg)
    if length(bl.messages) >= bl.batch_size
        flush_messages(bl)
    end
end

function flush_messages(bl::BatchedLogger)
    if !isempty(bl.messages)
        combined = join(bl.messages, "\n")
        with_logger(bl.logger) do
            @info "Batch of $(length(bl.messages)) messages:\n$combined"
        end
        empty!(bl.messages)
    end
end
```

## Testing with Logging

Use `Test.@test_logs` to verify logging behavior:

```julia
using Test

@testset "Logging Tests" begin
    verbose = MyVerbosity{true}(options = MyOptions(level = Verbosity.Info()))
    
    # Test that a message is logged
    @test_logs (:info, "Expected message") begin
        @SciMLMessage("Expected message", verbose, :level, :options)
    end
    
    # Test that no message is logged
    silent = MyVerbosity{false}(options = MyOptions(level = Verbosity.Info()))
    @test_logs min_level=Logging.Debug begin
        @SciMLMessage("Should not appear", silent, :level, :options)
    end
    
    # Test multiple messages
    @test_logs (:info, "First") (:warn, "Second") begin
        @SciMLMessage("First", verbose_info, :opt1, :group)
        @SciMLMessage("Second", verbose_warn, :opt2, :group)
    end
end
```

## Global Logger Configuration

Set up a global logger for your application:

```julia
# In your application startup
function setup_logging(; log_file = nothing, min_level = Logging.Info)
    loggers = AbstractLogger[]
    
    # Always include console logger
    push!(loggers, ConsoleLogger(stderr, min_level))
    
    # Add file logger if specified
    if !isnothing(log_file)
        push!(loggers, FileLogger(log_file, min_level))
    end
    
    # Set as global logger
    global_logger(TeeLogger(loggers...))
end

# Use it
setup_logging(log_file = "app.log", min_level = Logging.Debug)
```

## Integration with External Systems

### Syslog Integration

```julia
# Example of sending to syslog (Unix-like systems)
function syslog_logger(facility = :local0)
    TransformerLogger(NullLogger()) do log
        level_map = Dict(
            Logging.Debug => :debug,
            Logging.Info => :info,
            Logging.Warn => :warning,
            Logging.Error => :err
        )
        
        level = get(level_map, log.level, :info)
        # Call syslog command or use a syslog library
        run(`logger -p $facility.$level "$(log.message)"`)
        log
    end
end
```

### Cloud Logging Services

```julia
# Example structure for cloud logging
function cloud_logger(api_key::String, endpoint::String)
    TransformerLogger(NullLogger()) do log
        # Format for cloud service
        payload = Dict(
            "timestamp" => now(),
            "severity" => string(log.level),
            "message" => log.message,
            "labels" => Dict(
                "module" => string(log._module),
                "file" => log._file,
                "line" => log._line
            )
        )
        
        # Send to cloud service (pseudo-code)
        # HTTP.post(endpoint, headers=["Authorization" => api_key], json=payload)
        
        log
    end
end
```

## Best Practices

1. **Use appropriate log levels**: Match verbosity levels to their semantic meaning
2. **Avoid over-logging**: Too many messages can obscure important information
3. **Include context**: Add relevant information to help with debugging
4. **Use structured logging**: Consider JSON or key-value formats for machine processing
5. **Test logging behavior**: Verify that messages appear as expected
6. **Handle logger failures gracefully**: Don't let logging errors crash your application
7. **Consider performance**: Use lazy evaluation for expensive message generation
8. **Rotate log files**: Prevent unbounded growth of log files

## Summary

SciMLLogging's integration with Julia's logging system provides:
- Flexible message routing
- Custom formatting options
- Performance-conscious design
- Testing capabilities
- Integration with external systems

This integration allows you to build sophisticated logging pipelines while maintaining the simplicity of the `@SciMLMessage` interface.