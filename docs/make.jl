using Documenter
using SciMLLogging
using Logging

DocMeta.setdocmeta!(SciMLLogging, :DocTestSetup, :(using SciMLLogging); recursive = true)

makedocs(;
    modules = [SciMLLogging],
    authors = "SciML Developers and contributors",
    sitename = "SciMLLogging.jl",
    format = Documenter.HTML(;
        canonical = "https://docs.sciml.ai/SciMLLogging/stable",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Core Concepts" => "core_concepts.md",
        "Usage Guide" => [
            "Basic Usage" => "usage/basic.md",
            "Creating Custom Verbosity Types" => "usage/custom_types.md",
            "Integration with Logging" => "usage/logging_integration.md",
            "Advanced Features" => "usage/advanced.md",
        ],
        "Examples" => [
            "Simple Example" => "examples/simple.md",
            "Solver Verbosity" => "examples/solver.md",
            "Performance Monitoring" => "examples/performance.md",
        ],
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/SciML/SciMLLogging.jl",
    devbranch = "main",
)