# Conversion Utilities

SciMLLogging provides utility functions to convert message levels to common formats used by other packages.

## Integer Conversion

```@docs
verbosity_to_int
```
## Boolean Conversion

```@docs
verbosity_to_bool
```

## Usage Examples

### Integrating with Integer-Based Packages

```julia
# Package that expects integer verbosity levels
function external_solver(problem; verbosity_level = 0)
    if verbosity_level >= 1
        println("Starting solver...")
    end
    # ...
end

# Use with SciMLLogging
verbose_spec = MyPackageVerbosity(Standard())
level = verbosity_to_int(verbose_spec.progress)
result = external_solver(problem, verbosity_level = level)
```

### Integrating with Boolean-Based Packages

```julia
# Package that expects boolean verbosity
function simple_algorithm(data; verbose = false)
    if verbose
        println("Processing data...")
    end
    # ...
end

# Use with SciMLLogging
verbose_spec = MyPackageVerbosity(Standard())
is_verbose = verbosity_to_bool(verbose_spec.progress)
result = simple_algorithm(data, verbose = is_verbose)
```