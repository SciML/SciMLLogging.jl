# Message Levels

Message levels in SciMLLogging determine the severity and importance of log messages. Understanding these levels is essential for configuring appropriate verbosity in your applications.

## Overview

SciMLLogging provides a hierarchy of message levels that correspond to different types of information:

```@docs
AbstractMessageLevel
```

## Standard Message Levels

### Silent Level
```@docs
Silent
```

The `Silent` level is special - it completely suppresses output for a message.

### Information Level
```@docs
InfoLevel
```

Use `InfoLevel()` for general status updates, progress information, and routine diagnostic messages that users might want to see during normal operation.

### Warning Level
```@docs
WarnLevel
```

`WarnLevel()` should be used for potentially problematic situations that don't prevent execution but may require user attention.

### Error Level
```@docs
ErrorLevel
```

`ErrorLevel()` is reserved for serious problems and failures that indicate something has gone wrong in the computation.

## Custom Message Levels

```@docs
CustomLevel
```

Custom levels provide flexibility for specialized use cases where the standard Info/Warn/Error hierarchy isn't sufficient.

## Usage Examples

```julia
using SciMLLogging

# Standard levels
info_level = InfoLevel()
warn_level = WarnLevel()
error_level = ErrorLevel()
silent_level = Silent()

# Custom levels for specialized needs
debug_level = CustomLevel(-1000)    # Very low priority
trace_level = CustomLevel(-500)     # Low priority debugging
critical_level = CustomLevel(2000)  # Higher than standard error level
```

## Level Hierarchy

The message levels have a natural hierarchy that affects logging behavior:

- `CustomLevel(n)`: Priority determined by integer value `n`
- `ErrorLevel()`: Highest standard priority
- `WarnLevel()`: Medium priority
- `InfoLevel()`: Low priority for general information
- `Silent()`: No output (always suppressed)

Higher priority messages are more likely to be displayed by logging systems, while lower priority messages may be filtered out depending on the logger configuration.