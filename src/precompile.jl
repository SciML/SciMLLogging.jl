@compile_workload begin
    level = MessageLevel(2)
    verbosity_to_int(level)
    verbosity_to_bool(level)
    SciMLLogger()

    Logging.with_logger(NullLogger()) do
        @SciMLMessage("precompiled message", true)
    end
end
