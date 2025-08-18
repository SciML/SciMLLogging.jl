# Solver Verbosity Example

This example demonstrates how to implement a comprehensive verbosity system for a numerical solver, similar to what would be used in SciML solvers.

## Complete Solver Example

```julia
using SciMLLogging
using Logging
using LinearAlgebra

# Define verbosity options for different solver phases
mutable struct SolverInitOptions
    problem_analysis::Verbosity.Type
    jacobian_setup::Verbosity.Type
    preconditioner::Verbosity.Type
    memory_allocation::Verbosity.Type
    
    function SolverInitOptions(;
        problem_analysis = Verbosity.Info(),
        jacobian_setup = Verbosity.None(),
        preconditioner = Verbosity.None(),
        memory_allocation = Verbosity.Warn()
    )
        new(problem_analysis, jacobian_setup, preconditioner, memory_allocation)
    end
end

mutable struct SolverIterOptions
    iteration_count::Verbosity.Type
    residual_norm::Verbosity.Type
    step_size::Verbosity.Type
    line_search::Verbosity.Type
    
    function SolverIterOptions(;
        iteration_count = Verbosity.Info(),
        residual_norm = Verbosity.None(),
        step_size = Verbosity.None(),
        line_search = Verbosity.None()
    )
        new(iteration_count, residual_norm, step_size, line_search)
    end
end

mutable struct SolverConvOptions
    tolerance_check::Verbosity.Type
    convergence_rate::Verbosity.Type
    stagnation::Verbosity.Type
    success::Verbosity.Type
    failure::Verbosity.Type
    
    function SolverConvOptions(;
        tolerance_check = Verbosity.None(),
        convergence_rate = Verbosity.Info(),
        stagnation = Verbosity.Warn(),
        success = Verbosity.Info(),
        failure = Verbosity.Error()
    )
        new(tolerance_check, convergence_rate, stagnation, success, failure)
    end
end

# Main solver verbosity type
struct SolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    init::SolverInitOptions
    iter::SolverIterOptions
    conv::SolverConvOptions
    
    function SolverVerbosity{T}(;
        init = SolverInitOptions(),
        iter = SolverIterOptions(),
        conv = SolverConvOptions()
    ) where {T}
        new{T}(init, iter, conv)
    end
end

# Convenience constructors
function SolverVerbosity(level::Symbol = :normal)
    if level == :silent
        SolverVerbosity{false}()
    elseif level == :minimal
        SolverVerbosity{true}(
            init = SolverInitOptions(
                problem_analysis = Verbosity.None(),
                jacobian_setup = Verbosity.None(),
                preconditioner = Verbosity.None(),
                memory_allocation = Verbosity.Error()
            ),
            iter = SolverIterOptions(
                iteration_count = Verbosity.None(),
                residual_norm = Verbosity.None(),
                step_size = Verbosity.None(),
                line_search = Verbosity.None()
            ),
            conv = SolverConvOptions(
                tolerance_check = Verbosity.None(),
                convergence_rate = Verbosity.None(),
                stagnation = Verbosity.Error(),
                success = Verbosity.Info(),
                failure = Verbosity.Error()
            )
        )
    elseif level == :normal
        SolverVerbosity{true}()  # Use defaults
    elseif level == :detailed
        SolverVerbosity{true}(
            init = SolverInitOptions(
                problem_analysis = Verbosity.Info(),
                jacobian_setup = Verbosity.Info(),
                preconditioner = Verbosity.Info(),
                memory_allocation = Verbosity.Info()
            ),
            iter = SolverIterOptions(
                iteration_count = Verbosity.Info(),
                residual_norm = Verbosity.Info(),
                step_size = Verbosity.Info(),
                line_search = Verbosity.None()
            ),
            conv = SolverConvOptions(
                tolerance_check = Verbosity.Info(),
                convergence_rate = Verbosity.Info(),
                stagnation = Verbosity.Warn(),
                success = Verbosity.Info(),
                failure = Verbosity.Error()
            )
        )
    elseif level == :debug
        # Everything at maximum verbosity
        SolverVerbosity{true}(
            init = SolverInitOptions(
                problem_analysis = Verbosity.Level(-1000),
                jacobian_setup = Verbosity.Level(-1000),
                preconditioner = Verbosity.Level(-1000),
                memory_allocation = Verbosity.Level(-1000)
            ),
            iter = SolverIterOptions(
                iteration_count = Verbosity.Level(-1000),
                residual_norm = Verbosity.Level(-1000),
                step_size = Verbosity.Level(-1000),
                line_search = Verbosity.Level(-1000)
            ),
            conv = SolverConvOptions(
                tolerance_check = Verbosity.Level(-1000),
                convergence_rate = Verbosity.Level(-1000),
                stagnation = Verbosity.Warn(),
                success = Verbosity.Info(),
                failure = Verbosity.Error()
            )
        )
    else
        error("Unknown verbosity level: $level")
    end
end

# Solver statistics structure
mutable struct SolverStats
    iterations::Int
    residual_history::Vector{Float64}
    step_sizes::Vector{Float64}
    converged::Bool
    convergence_reason::String
    
    function SolverStats()
        new(0, Float64[], Float64[], false, "")
    end
end

# Newton-Raphson solver with verbosity
function newton_solve(
    f::Function,           # Function to find root of
    J::Function,           # Jacobian function
    x0::Vector{Float64};   # Initial guess
    tol::Float64 = 1e-6,
    max_iter::Int = 100,
    verbose::SolverVerbosity = SolverVerbosity(:normal)
)
    # Initialization phase
    @SciMLMessage(verbose, :problem_analysis, :init) do
        "Problem dimension: $(length(x0)), tolerance: $tol, max iterations: $max_iter"
    end
    
    x = copy(x0)
    stats = SolverStats()
    
    # Analyze Jacobian structure
    J0 = J(x0)
    @SciMLMessage(verbose, :jacobian_setup, :init) do
        cond_num = cond(J0)
        "Jacobian condition number: $(round(cond_num, sigdigits=3))"
    end
    
    # Check memory requirements
    memory_estimate = sizeof(J0) + sizeof(x0) * 3  # Rough estimate
    if memory_estimate > 1e6  # More than 1MB
        @SciMLMessage(verbose, :memory_allocation, :init) do
            "Estimated memory usage: $(round(memory_estimate / 1e6, digits=2)) MB"
        end
    end
    
    # Main iteration loop
    for iter in 1:max_iter
        stats.iterations = iter
        
        # Compute residual
        residual = f(x)
        residual_norm = norm(residual)
        push!(stats.residual_history, residual_norm)
        
        @SciMLMessage(verbose, :iteration_count, :iter) do
            "Iteration $iter: ||f(x)|| = $(round(residual_norm, sigdigits=4))"
        end
        
        @SciMLMessage(verbose, :residual_norm, :iter) do
            "  Residual: $residual"
        end
        
        # Check convergence
        @SciMLMessage(verbose, :tolerance_check, :conv) do
            "  Checking: $(round(residual_norm, sigdigits=4)) < $tol"
        end
        
        if residual_norm < tol
            stats.converged = true
            stats.convergence_reason = "Tolerance achieved"
            @SciMLMessage(verbose, :success, :conv) do
                "✓ Converged in $iter iterations (||f(x)|| = $(round(residual_norm, sigdigits=4)))"
            end
            break
        end
        
        # Check for stagnation
        if iter > 5
            recent_residuals = stats.residual_history[end-4:end]
            if std(recent_residuals) / mean(recent_residuals) < 0.01
                @SciMLMessage(verbose, :stagnation, :conv) do
                    "⚠ Stagnation detected: residual not decreasing"
                end
            end
        end
        
        # Compute Newton step
        J_current = J(x)
        try
            step = -J_current \ residual
            step_norm = norm(step)
            push!(stats.step_sizes, step_norm)
            
            @SciMLMessage(verbose, :step_size, :iter) do
                "  Step size: $(round(step_norm, sigdigits=4))"
            end
            
            # Line search (simplified)
            α = 1.0
            x_new = x + α * step
            f_new_norm = norm(f(x_new))
            
            line_search_iters = 0
            while f_new_norm > residual_norm && α > 1e-4
                α *= 0.5
                x_new = x + α * step
                f_new_norm = norm(f(x_new))
                line_search_iters += 1
                
                @SciMLMessage(verbose, :line_search, :iter) do
                    "    Line search: α = $α, ||f(x_new)|| = $(round(f_new_norm, sigdigits=4))"
                end
            end
            
            x = x_new
            
            # Compute convergence rate
            if iter > 1
                rate = stats.residual_history[end] / stats.residual_history[end-1]
                @SciMLMessage(verbose, :convergence_rate, :conv) do
                    "  Convergence rate: $(round(rate, digits=3))"
                end
            end
            
        catch e
            stats.convergence_reason = "Jacobian singular"
            @SciMLMessage("✗ Solver failed: $(e)", verbose, :failure, :conv)
            break
        end
    end
    
    # Final status
    if !stats.converged && stats.iterations == max_iter
        stats.convergence_reason = "Maximum iterations reached"
        @SciMLMessage(verbose, :failure, :conv) do
            "✗ Failed to converge after $max_iter iterations (||f(x)|| = $(round(stats.residual_history[end], sigdigits=4)))"
        end
    end
    
    return x, stats
end

# Example: Solve a nonlinear system
function example_nonlinear_system()
    # Define the system: 
    # x^2 + y^2 = 1
    # x - y = 0.5
    f(x) = [x[1]^2 + x[2]^2 - 1.0, x[1] - x[2] - 0.5]
    
    # Jacobian
    J(x) = [2*x[1] 2*x[2]; 1.0 -1.0]
    
    # Initial guess
    x0 = [1.0, 0.0]
    
    println("=" ^ 60)
    println("Solving with NORMAL verbosity:")
    println("=" ^ 60)
    x_normal, stats_normal = newton_solve(f, J, x0, verbose = SolverVerbosity(:normal))
    
    println("\n" * "=" ^ 60)
    println("Solving with DETAILED verbosity:")
    println("=" * "=" * 60)
    x_detailed, stats_detailed = newton_solve(f, J, x0, verbose = SolverVerbosity(:detailed))
    
    println("\n" * "=" ^ 60)
    println("Solving with MINIMAL verbosity:")
    println("=" ^ 60)
    x_minimal, stats_minimal = newton_solve(f, J, x0, verbose = SolverVerbosity(:minimal))
    
    println("\n" * "=" ^ 60)
    println("Final Results:")
    println("=" ^ 60)
    println("Solution: x = $(round.(x_normal, digits=6))")
    println("Verification: f(x) = $(f(x_normal))")
    println("Iterations: $(stats_normal.iterations)")
    println("Final residual: $(stats_normal.residual_history[end])")
end

# Advanced: Adaptive verbosity based on convergence
function adaptive_newton_solve(f, J, x0; kwargs...)
    verbose = SolverVerbosity(:minimal)
    x, stats = newton_solve(f, J, x0; verbose = verbose, kwargs...)
    
    # If failed, retry with more verbosity
    if !stats.converged
        println("\nInitial solve failed. Retrying with detailed verbosity...")
        verbose = SolverVerbosity(:detailed)
        x, stats = newton_solve(f, J, x0; verbose = verbose, kwargs...)
    end
    
    return x, stats
end

# Run the example
example_nonlinear_system()
```

## Key Features Demonstrated

1. **Multi-level Organization**: Separate option groups for initialization, iteration, and convergence
2. **Detailed Solver Information**: Problem analysis, Jacobian condition, memory usage
3. **Iteration Monitoring**: Step sizes, residuals, convergence rates
4. **Adaptive Verbosity**: Increase verbosity when problems occur
5. **Performance Tracking**: Statistics collection alongside logging

## Extending for Real Solvers

### Integration with DifferentialEquations.jl

```julia
using DifferentialEquations

function solve_ode_verbose(prob::ODEProblem, alg; verbose = SolverVerbosity(:normal))
    # Create callback for verbosity
    function verbose_callback(integrator)
        @SciMLMessage(verbose, :iteration_count, :iter) do
            "t = $(integrator.t), dt = $(integrator.dt)"
        end
    end
    
    # Add callback to algorithm
    callback = DiscreteCallback(
        (u, t, integrator) -> true,  # Always trigger
        verbose_callback
    )
    
    solve(prob, alg, callback = callback)
end
```

### Parallel Solver Verbosity

```julia
using Distributed

function parallel_solve_verbose(problems, verbose)
    @SciMLMessage("Starting parallel solve on $(nworkers()) workers", 
                  verbose, :problem_analysis, :init)
    
    results = @distributed (vcat) for (i, prob) in enumerate(problems)
        local_verbose = SolverVerbosity(:minimal)  # Reduce verbosity in parallel
        x, stats = newton_solve(prob.f, prob.J, prob.x0, verbose = local_verbose)
        
        # Report back to main process
        (solution = x, converged = stats.converged, iterations = stats.iterations)
    end
    
    @SciMLMessage(verbose, :success, :conv) do
        converged_count = sum(r.converged for r in results)
        "Parallel solve complete: $(converged_count)/$(length(problems)) converged"
    end
    
    return results
end
```

This solver example shows how SciMLLogging.jl can provide detailed insights into solver behavior while maintaining performance through selective verbosity control.