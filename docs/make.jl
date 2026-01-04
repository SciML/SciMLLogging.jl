using Documenter
using SciMLLogging

# Copy project files for reproducibility
# Handle both running from root (CI) and from docs directory (local)
docs_dir = @__DIR__
manifest_src = joinpath(docs_dir, "Manifest.toml")
project_src = joinpath(docs_dir, "Project.toml")
manifest_dst = joinpath(docs_dir, "src", "assets", "Manifest.toml")
project_dst = joinpath(docs_dir, "src", "assets", "Project.toml")

if isfile(manifest_src)
    cp(manifest_src, manifest_dst, force = true)
end
if isfile(project_src)
    cp(project_src, project_dst, force = true)
end

include("pages.jl")

makedocs(
    sitename = "SciMLLogging.jl",
    authors = "SciML",
    modules = [SciMLLogging],
    clean = true,
    doctest = false,
    linkcheck = true,
    checkdocs = :exports,
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
        canonical = "https://docs.sciml.ai/SciMLLogging/stable/",
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = pages
)

deploydocs(
    repo = "github.com/SciML/SciMLLogging.jl.git",
    devbranch = "main",
    push_preview = true
)
