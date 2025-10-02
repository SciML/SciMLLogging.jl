# SciMLLogging.jl

A verbosity control system for the SciML ecosystem that provides fine-grained control over logging and messaging in scientific computing workflows.

## Features

- **Fine-grained control**: Control individual aspects of logging with specific verbosity settings
- **Type-safe interface**: Leverage Julia's type system for compile-time safety  
- **Zero-cost abstraction**: Disabled verbosity has no runtime overhead
- **Integration with Julia's logging**: Built on top of Julia's standard logging infrastructure

## Installation

To install SciMLLogging, use the Julia package manager:

```julia
using Pkg
Pkg.add("SciMLLogging")
```

## Citation

If you use SciMLLogging.jl in your research, please cite the SciML organization:

```bibtex
@misc{SciMLLogging,
  author = {SciML},
  title = {SciMLLogging.jl: Verbosity Control for Scientific Machine Learning},
  url = {https://github.com/SciML/SciMLLogging.jl},
  version = {v1.0.0},
}
```

## Getting Started

See [Getting Started with SciMLLogging.jl](@ref) for a quick introduction to using SciMLLogging.jl.

## Contributing 

- Please refer to the [SciML ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://github.com/SciML/ColPrac/blob/master/README.md) for guidance on PRs, issues, and other matters relating to contributing to SciML.
- See the [SciML Style Guide](https://github.com/SciML/SciMLStyle) for common coding practices and other style decisions.
- There are a few community forums for getting help and asking questions:
    - The #diffeq-bridged and #sciml-bridged channels in the [Julia Slack](https://julialang.org/slack/)
    - The #diffeq-bridged and #sciml-bridged channels in the [Julia Zulip](https://julialang.zulipchat.com/#narrow/stream/279055-sciml-bridged)
    - On the [Julia Discourse forums](https://discourse.julialang.org)
    - See also [SciML Community page](https://sciml.ai/community/)

## Reproducibility

```@raw html
<details><summary>The documentation of this SciML package was built using these direct dependencies,</summary>
```

```@example
using Pkg # hide
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>and using this machine and Julia version.</summary>
```

```@example
using InteractiveUtils # hide
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>
```

```@example
using Pkg # hide
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```

```@eval
using TOML
using Markdown
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]
link_manifest = "https://github.com/SciML/" * name * ".jl/tree/gh-pages/v" * version *
                "/assets/Manifest.toml"
link_project = "https://github.com/SciML/" * name * ".jl/tree/gh-pages/v" * version *
               "/assets/Project.toml"
Markdown.parse("""You can also download the
[manifest]($link_manifest)
file and the
[project]($link_project)
file.
""")
```