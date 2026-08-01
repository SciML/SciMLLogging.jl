module SciMLLoggingTracyExt

using SciMLLogging
using SciMLLogging: MessageLevel, DebugLevel, InfoLevel, WarnLevel, ErrorLevel
using Tracy: Tracy

# Map MessageLevel values to Tracy color symbols
function level_to_color(level::MessageLevel)
    level == DebugLevel && return :cyan
    level == InfoLevel  && return :green
    level == WarnLevel  && return :yellow
    level == ErrorLevel && return :red
    return :white  # Default for custom MessageLevel values
end

# Override the fallback implementation when Tracy is loaded
function SciMLLogging.emit_tracy_message(msg, level::MessageLevel, _, _, _)
    # Use Tracy.jl's tracymsg to emit the message with color based on level.
    # The message will show up in the Tracy profiler with appropriate color.
    color = level_to_color(level)
    return Tracy.tracymsg(msg; color)
end

end
