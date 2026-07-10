using SciMLTesting, SciMLLogging, Test
using SciMLLogging: @SciMLMessage, @verbosity_specifier,
    Silent, InfoLevel, WarnLevel, ErrorLevel,
    None, Standard
using JET

run_qa(
    SciMLLogging; explicit_imports = true,
    ei_kwargs = (;
        # SciMLLogging integrates with the standard logging stack via Base/Core
        # internals that are not (and cannot be made) public:
        #   Core.println; Base.CoreLogging.{current_logger_for_env,shouldlog,handle_message}
        # (src/utils.jl). `CoreLogging` is itself a non-public submodule of `Base`.
        all_qualified_accesses_are_public = (;
            ignore = (
                :CoreLogging, :current_logger_for_env, :handle_message,
                :println, :shouldlog,
            ),
        ),
    )
)

const EXPECTED_OWNED_PUBLIC_NAMES = Set(
    Symbol[
        Symbol("@SciMLMessage"),
        Symbol("@verbosity_specifier"),
        :AbstractVerbosityPreset,
        :AbstractVerbositySpecifier,
        :All,
        :DebugLevel,
        :Detailed,
        :ErrorLevel,
        :InfoLevel,
        :MessageLevel,
        :Minimal,
        :None,
        :SciMLLogger,
        :Silent,
        :Standard,
        :WarnLevel,
        :get_logging_backend,
        :set_logging_backend,
        :verbosity_to_bool,
        :verbosity_to_int,
    ]
)

function owned_public_names(mod)
    public_names = Set(filter(!=(nameof(mod)), names(mod)))

    if isdefined(Base, :ispublic)
        ispublic = getproperty(Base, :ispublic)
        for name in names(mod; all = true, imported = false)
            name == nameof(mod) && continue
            startswith(string(name), "#") && continue
            ispublic(mod, name) && push!(public_names, name)
        end
    end

    return public_names
end

function docs_block_names()
    docs_root = normpath(joinpath(@__DIR__, "..", "..", "docs", "src"))
    documented_names = Set{Symbol}()

    for (root, _, files) in walkdir(docs_root)
        for file in files
            endswith(file, ".md") || continue
            in_docs_block = false

            for line in eachline(joinpath(root, file))
                stripped = strip(line)
                if startswith(stripped, "```@docs")
                    in_docs_block = true
                elseif in_docs_block && startswith(stripped, "```")
                    in_docs_block = false
                elseif in_docs_block && !isempty(stripped) && !startswith(stripped, "#")
                    token = first(split(stripped))
                    name = replace(token, r"\(.*$" => "")
                    name = replace(name, r"^SciMLLogging\." => "")
                    push!(documented_names, Symbol(name))
                end
            end
        end
    end

    return documented_names
end

@testset "public API documentation coverage" begin
    public_names = owned_public_names(SciMLLogging)
    @test public_names == EXPECTED_OWNED_PUBLIC_NAMES

    metadata = Docs.meta(SciMLLogging)
    missing_docstrings = sort(
        [name for name in public_names if !haskey(metadata, Docs.Binding(SciMLLogging, name))];
        by = string
    )
    @test isempty(missing_docstrings)

    rendered_doc_names = docs_block_names()
    missing_rendered_docs = sort(collect(setdiff(public_names, rendered_doc_names)); by = string)
    @test isempty(missing_rendered_docs)
end

# Functional inference regression test: emitting messages under a `None()` preset
# must stay type-stable / allocation-free (no fallback to the dynamic logging path).
@verbosity_specifier JETTestVerbosity begin
    toggles = (:a, :b, :c)

    presets = (
        None = (
            a = Silent,
            b = Silent,
            c = Silent,
        ),
        Standard = (
            a = WarnLevel,
            b = InfoLevel,
            c = ErrorLevel,
        ),
    )

    groups = ()
end

function emit_all(verbose)
    @SciMLMessage("msg a", verbose, :a)
    @SciMLMessage("msg b", verbose, :b)
    @SciMLMessage(lazy"msg c", verbose, :c)
    return nothing
end

@testset "JET report_opt with None() preset" begin
    verbose = JETTestVerbosity(None())
    JET.@test_opt target_modules = (SciMLLogging,) emit_all(verbose)
end
