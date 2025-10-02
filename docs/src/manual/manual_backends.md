# Logging Backends

SciMLLogging supports two output backends: Julia's standard logging system (default) and simple console output.

## Backend Configuration

```@docs
set_logging_backend
get_logging_backend
```

Switch between backends:
```julia
# Switch to simple console output
set_logging_backend("core")

# Switch back to standard logging (default)
set_logging_backend("logging")
```

**Note:** Restart Julia after changing backends.

## Standard Logging Backend

Uses Julia's Logging system. Messages integrate with loggers and can be filtered or redirected using standard filters or other packages that integrate with the logging system, e.g. [LoggingExtras.jl](https://github.com/JuliaLogging/LoggingExtras.jl).

```julia
using Logging

# Route to console
with_logger(ConsoleLogger(stdout, Logging.Info)) do
    result = solve(problem, verbose = SolverVerbosity(Standard()))
end

# Route to file
open("output.log", "w") do io
    with_logger(SimpleLogger(io)) do
        result = solve(problem, verbose = SolverVerbosity(Detailed()))
    end
end
```

## Core Backend

Uses `Core.println` for direct console output. Simpler but less flexible. This allows messages to emitted, while still being compatible with static compilation and JuliaC. 

## SciMLLogger

```@docs
SciMLLogger
```

Convenient logger that routes messages by level:

```julia
# Route info to file, warnings/errors to console and file
logger = SciMLLogger(
    info_repl = false,
    info_file = "info.log",
    warn_file = "warnings.log",
    error_file = "errors.log"
)

with_logger(logger) do
    result = solve(problem, verbose = SolverVerbosity(Standard()))
end
```