"""
    @verbosity_specifier name begin
        toggles = (...)
        presets = (...)
        groups = (...)
    end

Generates a parametric struct and constructors for a verbosity specifier.

# Input Format

**toggles:** Tuple of symbols defining the verbosity toggle names (e.g., `(:toggle1, :toggle2)`).

**presets:** Named tuple mapping preset names to toggle configurations. Each preset maps toggle names to message levels or preset types.
Must include at least `Standard`. Can define custom presets beyond the standard five (None, Minimal, Standard, Detailed, All).

**groups:** Named tuple mapping group names to tuples of toggle symbols. Groups allow setting multiple toggles at once.

# Generated Code

**Struct:** Creates `name{T1, T2, ...} <: AbstractVerbositySpecifier` with fields for each toggle.

**Constructors:**
- `name()`: Default constructor using Standard preset
- `name(preset::AbstractVerbosityPreset)`: Constructor from preset (e.g., `name(Minimal())`) for each preset in presets
- `name(; preset=nothing, groups..., kwargs...)`: Keyword constructor with precedence: individual > group > preset

**Custom Preset Types:** Generates struct definitions for non-standard presets (beyond None, Minimal, Standard, Detailed, All).

# Example
```julia
@verbosity_specifier MyVerbosity begin
    toggles = (:toggle1, :toggle2)

    presets = (
        Standard = (
            toggle1 = InfoLevel(),
            toggle2 = WarnLevel()
        ),
    )

    groups = (
        group1 = (:toggle1,),
    )
end
```
"""
macro verbosity_specifier(name, block)
    # Extract the three assignments from the block
    local toggles_expr = nothing
    local presets_expr = nothing
    local groups_expr = nothing

    if block.head == :block
        for ex in block.args
            if ex isa Expr && ex.head == :(=)
                lhs = ex.args[1]
                rhs = ex.args[2]
                if lhs == :toggles
                    toggles_expr = rhs
                elseif lhs == :presets
                    presets_expr = rhs
                elseif lhs == :groups
                    groups_expr = rhs
                end
            end
        end
    end

    toggles_expr !== nothing || throw(ArgumentError("toggles must be defined in block"))
    presets_expr !== nothing || throw(ArgumentError("presets must be defined in block"))
    groups_expr !== nothing || throw(ArgumentError("groups must be defined in block"))

    # Parse toggles - should be a tuple of symbols
    toggles_expr.head == :tuple || throw(ArgumentError("toggles must be a tuple"))
    # Extract the actual symbols from QuoteNode objects
    toggles = [t.value for t in toggles_expr.args]

    # Parse presets - should be a NamedTuple
    presets_expr.head == :tuple || throw(ArgumentError("presets must be a NamedTuple"))
    presets_dict = Dict()
    for preset_def in presets_expr.args
        preset_def.head == :(=) || throw(ArgumentError("Each preset must be name = (...)"))
        preset_name = preset_def.args[1]
        preset_values = preset_def.args[2]
        preset_values.head == :tuple || throw(ArgumentError("Preset values must be a NamedTuple"))

        # Parse the preset configuration
        preset_config = Dict()
        for toggle_def in preset_values.args
            toggle_def.head == :(=) || throw(ArgumentError("Each toggle must be toggle_name = value"))
            toggle_name = toggle_def.args[1]
            toggle_value_expr = toggle_def.args[2]
            preset_config[toggle_name] = toggle_value_expr
        end
        presets_dict[preset_name] = preset_config
    end

    # Parse groups
    groups_expr.head == :tuple || throw(ArgumentError("groups must be a NamedTuple"))
    groups_dict = Dict()
    for group_def in groups_expr.args
        group_def.head == :(=) || throw(ArgumentError("Each group must be name = (...)"))
        group_name = group_def.args[1]
        group_toggles_expr = group_def.args[2]
        group_toggles_expr.head == :tuple || throw(ArgumentError("Group toggles must be a tuple"))
        # Extract the actual symbols from QuoteNode objects
        group_toggles = [t isa QuoteNode ? t.value : t for t in group_toggles_expr.args]
        groups_dict[group_name] = group_toggles
    end

    # Now generate the code
    preset_names = collect(keys(presets_dict))
    group_names = collect(keys(groups_dict))

    # Standard presets that already exist
    standard_presets = (:None, :Minimal, :Standard, :Detailed, :All)
    custom_presets = filter(p -> !(p in standard_presets), preset_names)

    # Generate custom preset types
    custom_preset_defs = [:(struct $p <: AbstractVerbosityPreset end) for p in custom_presets]

    # Generate parametric struct
    type_params = [Symbol("T$i") for i in eachindex(toggles)]
    struct_fields = [:($(toggles[i])::$(type_params[i])) for i in eachindex(toggles)]

    struct_def = :(
        struct $name{$(type_params...)} <: AbstractVerbositySpecifier
            $(struct_fields...)
        end
    )

    # Generate preset constructors
    preset_constructors = []
    for preset_name in preset_names
        preset_config = presets_dict[preset_name]
        field_values = [preset_config[t] for t in toggles]

        push!(
            preset_constructors, :(
                function $name(::$preset_name)
                    return $name($(field_values...))
                end
            )
        )
    end

    # Build toggle to group mapping
    toggle_to_group = Dict{Symbol, Union{Symbol, Nothing}}()
    for toggle in toggles
        toggle_to_group[toggle] = nothing
        for (group_name, group_toggles) in groups_dict
            if toggle in group_toggles
                toggle_to_group[toggle] = group_name
                break
            end
        end
    end

    # Get Standard preset config for fast path
    standard_config = presets_dict[:Standard]
    fast_path_values = [standard_config[t] for t in toggles]

    # Build validation for groups
    group_validations = []
    for group_name in group_names
        lazy_str = Expr(
            :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
            "\$($(QuoteNode(group_name))) must be a SciMLLogging.AbstractMessageLevel, got \$(typeof($(group_name)))"
        )
        push!(
            group_validations, quote
                if $(group_name) !== nothing && !($(group_name) isa AbstractMessageLevel)
                    throw(ArgumentError($lazy_str))
                end
            end
        )
    end

    # Build precedence logic for each toggle
    toggle_assignments = []
    for toggle in toggles
        group = toggle_to_group[toggle]
        toggle_key = QuoteNode(toggle)

        if group === nothing
            # Not in any group: individual > preset
            # Build preset_config inline as a tuple access
            push!(toggle_assignments, :($toggle = haskey(kwargs, $toggle_key) ? kwargs[$toggle_key] : preset_config[$toggle_key]))
        else
            # In a group: individual > group > preset
            push!(toggle_assignments, :($toggle = haskey(kwargs, $toggle_key) ? kwargs[$toggle_key] : ($group !== nothing ? $group : preset_config[$toggle_key])))
        end
    end

    # Build preset_map as a constant NamedTuple for runtime access
    # For each preset, create a NamedTuple of its toggle configurations
    preset_configs = []
    for pname in preset_names
        toggle_values = [presets_dict[pname][t] for t in toggles]
        # Use tuple of symbols for NamedTuple type parameter
        push!(preset_configs, :(NamedTuple{$(Tuple(toggles))}(($(toggle_values...),))))
    end

    # Use tuple of symbols for preset names
    preset_map_const = :(const $(Symbol("_preset_map_", name)) = NamedTuple{$(Tuple(preset_names))}(($(preset_configs...),)))

    # Build main constructor
    kwarg_params = [Expr(:kw, :preset, :nothing); [Expr(:kw, g, :nothing) for g in group_names]]
    runtime_condition = foldr((a, b) -> :($a && $b), [:($(g) === nothing) for g in group_names]; init = :(preset === nothing && isempty(kwargs)))

    # Build lazy string expressions
    preset_error_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "preset must be a SciMLLogging.AbstractVerbosityPreset, got \$(typeof(preset))"
    )
    unknown_option_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "Unknown verbosity option: \$key. Valid options are: $(Tuple(toggles))"
    )
    invalid_type_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "\$key must be a SciMLLogging.AbstractMessageLevel, AbstractVerbosityPreset, or AbstractVerbositySpecifier, got \$(typeof(value))"
    )

    main_constructor = quote
        function $name(; $(kwarg_params...), kwargs...)
            kwargs = NamedTuple(kwargs)

            # Fast path: all defaults
            if $runtime_condition
                return $name($(fast_path_values...))
            end

            # Validate groups
            $(group_validations...)

            # Validate preset
            if preset !== nothing && !(preset isa AbstractVerbosityPreset)
                throw(ArgumentError($preset_error_str))
            end

            # Validate kwargs
            for (key, value) in pairs(kwargs)
                if !(key in $(Tuple(toggles)))
                    throw(ArgumentError($unknown_option_str))
                end
                if !(value isa AbstractMessageLevel || value isa AbstractVerbosityPreset || value isa AbstractVerbositySpecifier)
                    throw(ArgumentError($invalid_type_str))
                end
            end

            # Get preset config
            preset_to_use = preset === nothing ? Standard() : preset
            preset_config = $(Symbol("_preset_map_", name))[typeof(preset_to_use).name.name]

            # Apply precedence
            $(toggle_assignments...)

            return $name($([t for t in toggles]...))
        end
    end

    # Assemble everything
    result = quote
        $(custom_preset_defs...)
        $preset_map_const
        $struct_def
        $(preset_constructors...)
        $main_constructor
    end

    return esc(result)
end
