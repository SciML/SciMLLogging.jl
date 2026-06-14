using SciMLLogging
using LinearSolve: LinearProblem, LinearVerbosity, solve as lin_solve
using NonlinearSolve: NonlinearProblem, NonlinearVerbosity, solve as nl_solve
using OrdinaryDiffEq: ODEProblem, Tsit5, solve as ode_solve
using DiffEqBase: DEVerbosity
using JET
using Test

@testset "JET report_opt: LinearSolve with SciMLLogging.None()" begin
    A = rand(4, 4)
    b = rand(4)
    prob = LinearProblem(A, b)
    verbose = LinearVerbosity(SciMLLogging.None())
    JET.@test_opt target_modules = (SciMLLogging,) lin_solve(prob; verbose = verbose)
end

@testset "JET report_opt: NonlinearSolve with SciMLLogging.None()" begin
    f(u, p) = u .^ 2 .- p
    u0 = [1.0]
    prob = NonlinearProblem(f, u0, 2.0)
    verbose = NonlinearVerbosity(SciMLLogging.None())
    JET.@test_opt target_modules = (SciMLLogging,) nl_solve(prob; verbose = verbose)
end

@testset "JET report_opt: OrdinaryDiffEq with SciMLLogging.None()" begin
    f(u, p, t) = 1.01 .* u
    u0 = [1.0]
    tspan = (0.0, 1.0)
    prob = ODEProblem(f, u0, tspan)
    verbose = DEVerbosity(SciMLLogging.None())
    JET.@test_opt target_modules = (SciMLLogging,) ode_solve(prob, Tsit5(); verbose = verbose)
end
