# Performance Monitoring Example

This example demonstrates using SciMLLogging.jl for comprehensive performance monitoring in scientific computing applications.

## Complete Performance Monitoring System

```julia
using SciMLLogging
using Logging
using Statistics
using Dates

# Performance monitoring options
mutable struct MemoryOptions
    allocation::Verbosity.Type
    gc_stats::Verbosity.Type
    peak_usage::Verbosity.Type
    
    function MemoryOptions(;
        allocation = Verbosity.None(),
        gc_stats = Verbosity.None(),
        peak_usage = Verbosity.Warn()
    )
        new(allocation, gc_stats, peak_usage)
    end
end

mutable struct TimingOptions
    function_timing::Verbosity.Type
    cumulative::Verbosity.Type
    bottlenecks::Verbosity.Type
    
    function TimingOptions(;
        function_timing = Verbosity.Info(),
        cumulative = Verbosity.Info(),
        bottlenecks = Verbosity.Warn()
    )
        new(function_timing, cumulative, bottlenecks)
    end
end

mutable struct ThroughputOptions
    operations_per_second::Verbosity.Type
    data_rate::Verbosity.Type
    efficiency::Verbosity.Type
    
    function ThroughputOptions(;
        operations_per_second = Verbosity.Info(),
        data_rate = Verbosity.None(),
        efficiency = Verbosity.Info()
    )
        new(operations_per_second, data_rate, efficiency)
    end
end

# Main performance verbosity type
struct PerformanceVerbosity{T} <: AbstractVerbositySpecifier{T}
    memory::MemoryOptions
    timing::TimingOptions
    throughput::ThroughputOptions
    
    function PerformanceVerbosity{T}(;
        memory = MemoryOptions(),
        timing = TimingOptions(),
        throughput = ThroughputOptions()
    ) where {T}
        new{T}(memory, timing, throughput)
    end
end

# Convenience constructor
function PerformanceVerbosity(level::Symbol = :normal)
    if level == :off
        PerformanceVerbosity{false}()
    elseif level == :minimal
        PerformanceVerbosity{true}(
            memory = MemoryOptions(
                allocation = Verbosity.None(),
                gc_stats = Verbosity.None(),
                peak_usage = Verbosity.Error()
            ),
            timing = TimingOptions(
                function_timing = Verbosity.None(),
                cumulative = Verbosity.Info(),
                bottlenecks = Verbosity.Error()
            ),
            throughput = ThroughputOptions(
                operations_per_second = Verbosity.None(),
                data_rate = Verbosity.None(),
                efficiency = Verbosity.Warn()
            )
        )
    elseif level == :normal
        PerformanceVerbosity{true}()
    elseif level == :detailed
        PerformanceVerbosity{true}(
            memory = MemoryOptions(
                allocation = Verbosity.Info(),
                gc_stats = Verbosity.Info(),
                peak_usage = Verbosity.Info()
            ),
            timing = TimingOptions(
                function_timing = Verbosity.Info(),
                cumulative = Verbosity.Info(),
                bottlenecks = Verbosity.Info()
            ),
            throughput = ThroughputOptions(
                operations_per_second = Verbosity.Info(),
                data_rate = Verbosity.Info(),
                efficiency = Verbosity.Info()
            )
        )
    else
        error("Unknown performance verbosity level: $level")
    end
end

# Performance tracker
mutable struct PerformanceTracker
    start_time::Float64
    function_times::Dict{String, Vector{Float64}}
    memory_samples::Vector{Int}
    operations_completed::Int
    bytes_processed::Int
    gc_stats_before::Base.GC_Num
    peak_memory::Int
    
    function PerformanceTracker()
        new(
            time(),
            Dict{String, Vector{Float64}}(),
            Int[],
            0,
            0,
            Base.gc_num(),
            0
        )
    end
end

# Timing macro that integrates with verbosity
macro timed_operation(tracker, name, verbose, expr)
    quote
        local start_time = time_ns()
        local start_mem = Base.gc_bytes()
        
        local result = $(esc(expr))
        
        local elapsed = (time_ns() - start_time) / 1e9  # Convert to seconds
        local allocated = Base.gc_bytes() - start_mem
        
        # Track the timing
        if !haskey($(esc(tracker)).function_times, $(esc(name)))
            $(esc(tracker)).function_times[$(esc(name))] = Float64[]
        end
        push!($(esc(tracker)).function_times[$(esc(name))], elapsed)
        
        # Log timing information
        @SciMLMessage($(esc(verbose)), :function_timing, :timing) do
            "$($(esc(name))): $(round(elapsed * 1000, digits=2))ms"
        end
        
        # Log memory allocation
        if allocated > 0
            @SciMLMessage($(esc(verbose)), :allocation, :memory) do
                "  Allocated: $(format_bytes(allocated))"
            end
        end
        
        # Update peak memory
        current_mem = Base.gc_bytes()
        if current_mem > $(esc(tracker)).peak_memory
            $(esc(tracker)).peak_memory = current_mem
            @SciMLMessage($(esc(verbose)), :peak_usage, :memory) do
                "⚠ New peak memory: $(format_bytes(current_mem))"
            end
        end
        
        result
    end
end

# Helper function to format bytes
function format_bytes(bytes::Integer)
    if bytes < 1024
        return "$(bytes) B"
    elseif bytes < 1024^2
        return "$(round(bytes / 1024, digits=2)) KB"
    elseif bytes < 1024^3
        return "$(round(bytes / 1024^2, digits=2)) MB"
    else
        return "$(round(bytes / 1024^3, digits=2)) GB"
    end
end

# Performance monitoring functions
function monitor_performance(f::Function, verbose::PerformanceVerbosity, description::String = "Operation")
    tracker = PerformanceTracker()
    
    @SciMLMessage("Starting performance monitoring: $description", verbose, :function_timing, :timing)
    
    # Monitor GC before
    GC.gc()  # Clean slate
    gc_before = Base.gc_num()
    
    # Run the function
    result = f(tracker)
    
    # Collect final stats
    gc_after = Base.gc_num()
    total_time = time() - tracker.start_time
    
    # Report timing statistics
    @SciMLMessage(verbose, :cumulative, :timing) do
        times_summary = String[]
        for (func_name, times) in tracker.function_times
            avg_time = mean(times)
            total = sum(times)
            push!(times_summary, "  $func_name: $(length(times)) calls, avg $(round(avg_time * 1000, digits=2))ms, total $(round(total, digits=3))s")
        end
        """
        Timing Summary:
        $(join(times_summary, "\n"))
        Total execution time: $(round(total_time, digits=3))s
        """
    end
    
    # Report GC statistics
    @SciMLMessage(verbose, :gc_stats, :memory) do
        gc_diff = gc_after - gc_before
        """
        GC Statistics:
        - Collections: $(gc_diff.collect)
        - Pause time: $(round(gc_diff.pause / 1e9, digits=3))s
        - Full collections: $(gc_diff.full_sweep)
        - Bytes allocated: $(format_bytes(gc_diff.allocd))
        - Peak memory: $(format_bytes(tracker.peak_memory))
        """
    end
    
    # Report throughput
    if tracker.operations_completed > 0
        ops_per_sec = tracker.operations_completed / total_time
        @SciMLMessage(verbose, :operations_per_second, :throughput) do
            "Throughput: $(round(ops_per_sec, digits=1)) operations/second"
        end
    end
    
    if tracker.bytes_processed > 0
        data_rate = tracker.bytes_processed / total_time
        @SciMLMessage(verbose, :data_rate, :throughput) do
            "Data rate: $(format_bytes(Int(round(data_rate))))/second"
        end
    end
    
    # Identify bottlenecks
    if !isempty(tracker.function_times)
        total_tracked_time = sum(sum(times) for times in values(tracker.function_times))
        bottlenecks = String[]
        
        for (func_name, times) in tracker.function_times
            func_total = sum(times)
            percentage = func_total / total_tracked_time * 100
            if percentage > 30  # More than 30% of time
                push!(bottlenecks, "$func_name ($(round(percentage, digits=1))%)")
            end
        end
        
        if !isempty(bottlenecks)
            @SciMLMessage(verbose, :bottlenecks, :timing) do
                "⚠ Performance bottlenecks detected: $(join(bottlenecks, ", "))"
            end
        end
    end
    
    # Calculate efficiency
    if tracker.operations_completed > 0
        ideal_time = tracker.operations_completed * 0.001  # Assume 1ms per operation ideal
        efficiency = ideal_time / total_time * 100
        
        @SciMLMessage(verbose, :efficiency, :throughput) do
            "Efficiency: $(round(efficiency, digits=1))% of theoretical maximum"
        end
    end
    
    return result
end

# Example: Matrix operations benchmark
function matrix_operations_benchmark(n::Int = 1000, verbose = PerformanceVerbosity(:normal))
    monitor_performance(verbose, "Matrix Operations Benchmark") do tracker
        # Generate random matrices
        A = @timed_operation tracker "Matrix Generation" verbose begin
            randn(n, n)
        end
        
        B = @timed_operation tracker "Matrix Generation" verbose begin
            randn(n, n)
        end
        
        # Matrix multiplication
        C = @timed_operation tracker "Matrix Multiplication" verbose begin
            tracker.operations_completed += n^3  # Approximate FLOPs
            tracker.bytes_processed += 3 * n^2 * sizeof(Float64)
            A * B
        end
        
        # LU decomposition
        lu_fact = @timed_operation tracker "LU Decomposition" verbose begin
            tracker.operations_completed += 2 * n^3 ÷ 3  # Approximate FLOPs
            lu(C)
        end
        
        # Eigenvalue computation
        eigenvals = @timed_operation tracker "Eigenvalue Computation" verbose begin
            tracker.operations_completed += 10 * n^3  # Approximate FLOPs
            eigvals(C)
        end
        
        # Multiple small operations to test overhead
        for i in 1:100
            @timed_operation tracker "Small Operation" verbose begin
                tracker.operations_completed += n
                sum(A[i, :])
            end
        end
        
        return C
    end
end

# Example: Adaptive performance monitoring
function adaptive_computation(data, initial_verbose = PerformanceVerbosity(:minimal))
    verbose = initial_verbose
    tracker = PerformanceTracker()
    
    for (i, chunk) in enumerate(data)
        start_time = time()
        
        # Process chunk
        result = process_chunk(chunk, tracker)
        
        chunk_time = time() - start_time
        
        # Adapt verbosity based on performance
        if chunk_time > 1.0  # Slow chunk
            if verbose.timing.function_timing != Verbosity.Info()
                @info "Performance degradation detected, increasing verbosity"
                verbose = PerformanceVerbosity(:detailed)
            end
        end
        
        @SciMLMessage(verbose, :function_timing, :timing) do
            "Chunk $i processed in $(round(chunk_time, digits=3))s"
        end
    end
end

function process_chunk(chunk, tracker)
    # Simulate processing
    tracker.operations_completed += length(chunk)
    tracker.bytes_processed += sizeof(chunk)
    sleep(0.01 * randn()^2)  # Variable processing time
    return sum(chunk)
end

# Example: Comparative performance analysis
function compare_algorithms(algorithms, test_data, verbose = PerformanceVerbosity(:normal))
    results = Dict{String, Any}()
    
    for (name, algo) in algorithms
        println("\n" * "=" ^ 60)
        println("Testing algorithm: $name")
        println("=" ^ 60)
        
        result = monitor_performance(verbose, "Algorithm: $name") do tracker
            algo(test_data, tracker)
        end
        
        results[name] = result
    end
    
    # Summary comparison
    println("\n" * "=" ^ 60)
    println("Performance Comparison Summary")
    println("=" ^ 60)
    
    for (name, result) in results
        println("$name:")
        println("  Result quality: $(result[:quality])")
        println("  Time: $(round(result[:time], digits=3))s")
        println("  Memory: $(format_bytes(result[:memory]))")
    end
end

# Run examples
function run_performance_examples()
    println("=" ^ 70)
    println("MATRIX OPERATIONS BENCHMARK - NORMAL VERBOSITY")
    println("=" ^ 70)
    matrix_operations_benchmark(500, PerformanceVerbosity(:normal))
    
    println("\n" * "=" ^ 70)
    println("MATRIX OPERATIONS BENCHMARK - DETAILED VERBOSITY")
    println("=" ^ 70)
    matrix_operations_benchmark(500, PerformanceVerbosity(:detailed))
    
    println("\n" * "=" ^ 70)
    println("MATRIX OPERATIONS BENCHMARK - MINIMAL VERBOSITY")
    println("=" ^ 70)
    matrix_operations_benchmark(500, PerformanceVerbosity(:minimal))
end

# Run the examples
run_performance_examples()
```

## Key Features

1. **Memory Monitoring**: Track allocations, GC statistics, and peak usage
2. **Timing Analysis**: Function-level timing with automatic bottleneck detection
3. **Throughput Metrics**: Operations per second and data rate calculations
4. **Efficiency Calculations**: Compare against theoretical maximums
5. **Adaptive Monitoring**: Adjust verbosity based on performance characteristics

## Integration with Profiling Tools

```julia
using Profile
using ProfileView  # If available

function profile_with_verbosity(f, verbose::PerformanceVerbosity)
    @SciMLMessage("Starting profiled run", verbose, :function_timing, :timing)
    
    Profile.clear()
    @profile result = f()
    
    @SciMLMessage(verbose, :function_timing, :timing) do
        data = Profile.fetch()
        "Profile collected $(length(data)) samples"
    end
    
    # Optionally visualize if ProfileView is available
    # ProfileView.view()
    
    return result
end
```

## Real-Time Monitoring

```julia
function realtime_monitor(computation, verbose::PerformanceVerbosity; 
                         update_interval = 1.0)
    start_time = time()
    last_update = start_time
    
    @async begin
        while !computation.completed
            current_time = time()
            if current_time - last_update > update_interval
                @SciMLMessage(verbose, :operations_per_second, :throughput) do
                    elapsed = current_time - start_time
                    rate = computation.operations_done / elapsed
                    "Real-time: $(computation.operations_done) ops, $(round(rate, digits=1)) ops/s"
                end
                last_update = current_time
            end
            sleep(0.1)
        end
    end
    
    # Run computation
    result = computation.run()
    computation.completed = true
    
    return result
end
```

This performance monitoring example demonstrates how SciMLLogging.jl can provide detailed insights into computational performance while maintaining flexibility through verbosity controls.