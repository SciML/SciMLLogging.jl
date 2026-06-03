# Verbosity Presets

Presets provide convenient, predefined verbosity configurations that cover common use cases. Instead of manually setting each message category, users can choose from standard presets that automatically configure appropriate message levels. SciMLLogging provides the `AbstractVerbosityPreset` type, along with five subtypes meant to represent different verbosity levels. It is up to the implementer of the `AbstractVerbositySpecifier` to ensure that the verbosity presets are able to be used.  

## General Idea of Preset Levels

### Definition of the Preset Levels

The general idea behind the preset levels is as follows. Each lower level keeps everything enabled from the level above it, and adds the additional information:

* `None` makes it easy to turn off all printing/logging to ensure 0 overhead and 0 noise.
* `Minimal` turns on only the fatal errors, for example solvers exiting early due to instability, which the user must react to in order to appropriately compute correctly.
* `Standard` turns on non-fatal but critical warnings, for example major performance warnings or deprecations which have been flagged that the user almost certainly should
  respond to. While the program is still running correctly if these are firing, this is the level on by default to signal to the wider userbase issues which should be
  handled in order to have "normal" running code.
* `Detailed` turns on additional information as part of the run which can be helpful for in-depth debugging. This includes information about critical quantities at each step
  of the calculation, behaviors of the solver that are chosen behind the scenes, and critical numerical issues which are detected. This level should be detailed, but it should
  be something that does not necessarily overflow the standard REPL output and should not introduce major performance overhead.
* `All` turns on all logging available in the system. This can include detailed printing that happens in every iteration (i.e. overflowing the terminal output maximum lines),
  expensive calculations of critical quantities like condition numbers which can be more expensive than the standard solver but serve as good diagnostics to understand the
  numerical quantities better, and other verbose output which could be found interesting to package developers looking for obscure issues. It is generally recommended that
  `All` output is redirected to a file as it likely will need to be parsed to be human understandable.

### Preset Level Examples

* In the ODE solver, if `dt<dtmin` the solver needs to exit. Almost all users should be notified of this behavior in order to understand why the solver did not go to the final time.
  This should be set as a `WarnLevel` in the `Minimal` preset.
* In LinearSolve.jl's default methods, it has the ability to swap from using an LU factorization to a column-pivoted QR factorization behind the scenes if a singular matrix is detected.
  Since LinearSolve.jl automatically recovers from any error here, most users do not need to know if this has happened, thus it is a solver behavior that should be logged at the `Detailed`
  level because it's non-verbose and no extra cost to know, but can be a critical debugging information.
* In SciMLSensitivity.jl's default vjp method, it has to run through a bunch of different potential reverse-mode AD methods to see which is compatible with the user's `f`. If none of the
  AD methods are compatible, it needs to fallback to `FiniteDiffVJP`, which is finite differencing and thus changes the `J'v` calculation from O(n) matrix-free to O(n^2) building J. This is
  a massive difference in computational cost which most users should know about, as it should generally be considered incorrect behavior to require finite differencing here and the user
  should be notified by default about this fallback. Thus it should be given `WarnLevel` in the `Standard` preset, since it's not critical so it's not `Minimal`. In the `Detailed` preset,
  the vjp choice should additionally be shared every time even if it's not finite differencing.
* In LinearSolve.jl, it can be very useful to know `cond(A)` in order to know how ill-conditioned the numerical problem is at every step. This can help for understanding why Newton-Krylov
  methods aren't converging well, or whether ODE solves should have difficulties handling a given step. However, `cond(A)` is a very expensive calculation, sometimes more expensive than the
  solver itself, and thus it should only be enabled when maximum information is needed. Thus this printing would only be enabled when `All` is chosen.
* The default ODE solver has the ability to automatically swap between solvers based on certain qualities of the ODE that are detected, essentially estimating condition number. While
  this behavior is not necessary for most users to know, it can help a lot while debugging to know exactly when the swaps occurred. Since they don't occur often, this information should
  be included in the `Detailed` output, along with some information about why the trigger occurred.
* Error estimate values of adaptive ODE solvers, eigenvalue estimates in stabilized RK (RKC) methods, and other per-step estimators can be really useful for debugging ODE solvers in order
  to know what specific term  is likely making the solver drop the `dt` to be smaller, but it's very noisy to print tons of information at every step. Thus this information can be setup
  to have standard printers which are only turned on by demand or in the `All` preset.

### Abstract Base Type

```@docs
AbstractVerbosityPreset
```

### Available Presets

```@docs
SciMLLogging.None
Minimal
Standard
Detailed
All
```

## Custom Presets

Packages can define their own preset types for specialized use cases. With the
`@verbosity_specifier` macro, simply add the custom preset as a key in the
`presets` block — the macro generates the preset's struct definition and the
matching constructor automatically:

```julia
@verbosity_specifier MyPackageVerbosity begin
    toggles = (:initialization, :progress, :convergence, :warnings, :errors)

    presets = (
        # ... standard presets ...
        DebuggingPreset = (
            initialization = InfoLevel,
            progress       = DebugLevel,  # Extra detailed progress
            convergence    = InfoLevel,
            warnings       = WarnLevel,
            errors         = ErrorLevel,
        ),
    )

    groups = ()
end
```

For a manually-defined specifier, declare the preset type and the constructor
yourself:

```julia
struct DebuggingPreset <: AbstractVerbosityPreset end

function MyPackageVerbosity(::DebuggingPreset)
    MyPackageVerbosity(
        initialization = InfoLevel,
        progress       = DebugLevel,
        convergence    = InfoLevel,
        warnings       = WarnLevel,
        errors         = ErrorLevel,
    )
end
```

## Using Presets

Presets are typically used as constructor arguments for verbosity specifiers:

```julia
using SciMLLogging

# Assuming a package defines MyPackageVerbosity
quiet_config = MyPackageVerbosity(None())      # No output
default_config = MyPackageVerbosity(Standard()) # Balanced output
debug_config = MyPackageVerbosity(All())       # Maximum output
```

## How Presets Work

When you pass a preset to a verbosity specifier constructor, the package implementation maps the preset to appropriate message levels for each category. For example:

```julia
# This preset usage...
verbosity = SolverVerbosity(Standard())

# ...might be equivalent to this manual configuration:
verbosity = SolverVerbosity(
    initialization = InfoLevel,
    progress = Silent,
    convergence = InfoLevel,
    diagnostics = WarnLevel,
    performance = InfoLevel
)
```

