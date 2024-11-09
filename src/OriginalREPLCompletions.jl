#=
MIT License

Copyright (c) 2009-2024: Jeff Bezanson, Stefan Karpinski, Viral B. Shah, and other contributors: https://github.com/JuliaLang/julia/contributors

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

end of terms and conditions

Please see [THIRDPARTY.md](./THIRDPARTY.md) for license information for other software used in this project.
=#

module OriginalREPLCompletions

using REPL.REPLCompletions: Completion, Completions, PackageCompletion, PathCompletion
using REPL.REPLCompletions:
    dict_identifier_key,
    bslash_completions,
    complete_keyword_argument,
    non_identifier_chars,
    afterusing,
    complete_identifiers!,
    identify_possible_method_completion,
    complete_any_methods,
    module_filter,
    _readdirx,
    project_deps_get_completion_candidates,
    is_broadcasting_expr,
    complete_methods,
    complete_expanduser,
    complete_path,
    find_dict_matches

# This is the original implementation of REPL.REPLCompletions.completions function.
function _completions(
    string::String,
    pos::Int,
    context_module::Module = Main,
    shift::Bool = true,
    hint::Bool = false,
)
    # First parse everything up to the current position
    partial = string[1:pos]
    inc_tag = Base.incomplete_tag(Meta.parse(partial, raise = false, depwarn = false))

    # ?(x, y)TAB lists methods you can call with these objects
    # ?(x, y TAB lists methods that take these objects as the first two arguments
    # MyModule.?(x, y)TAB restricts the search to names in MyModule
    rexm = match(r"(\w+\.|)\?\((.*)$", partial)
    if !isnothing(rexm)
        # Get the module scope
        if isempty(rexm.captures[1])
            callee_module = context_module
        else
            modname = Symbol(rexm.captures[1][1:end-1])
            if isdefined(context_module, modname)
                callee_module = getfield(context_module, modname)
                if !isa(callee_module, Module)
                    callee_module = context_module
                end
            else
                callee_module = context_module
            end
        end
        moreargs = !endswith(rexm.captures[2], ')')
        callstr = "_(" * rexm.captures[2]
        if moreargs
            callstr *= ')'
        end
        ex_org = Meta.parse(callstr, raise = false, depwarn = false)
        if isa(ex_org, Expr)
            return complete_any_methods(
                ex_org,
                callee_module::Module,
                context_module,
                moreargs,
                shift,
            ),
            (0:length(rexm.captures[1])+1) .+ rexm.offset,
            false
        end
    end

    # if completing a key in a Dict
    identifier, partial_key, loc = dict_identifier_key(partial, inc_tag, context_module)
    if identifier !== nothing
        matches = find_dict_matches(identifier, partial_key)
        length(matches) == 1 &&
            (lastindex(string) <= pos || string[nextind(string, pos)] != ']') &&
            (matches[1] *= ']')
        length(matches) > 0 && return Completion[
            DictCompletion(identifier, match) for match in sort!(matches)
        ],
        loc::Int:pos,
        true
    end

    ffunc = Returns(true)
    suggestions = Completion[]

    # Check if this is a var"" string macro that should be completed like
    # an identifier rather than a string.
    # TODO: It would be nice for the parser to give us more information here
    # so that we can lookup the macro by identity rather than pattern matching
    # its invocation.
    varrange = findprev("var\"", string, pos)

    expanded = nothing
    was_expanded = false

    if varrange !== nothing
        ok, ret = bslash_completions(string, pos)
        ok && return ret
        startpos = first(varrange) + 4
        dotpos = something(findprev(isequal('.'), string, first(varrange) - 1), 0)
        name = string[startpos:pos]
        return complete_identifiers!(
            Completion[],
            ffunc,
            context_module,
            string,
            name,
            pos,
            dotpos,
            startpos,
        )
    elseif inc_tag === :cmd
        # TODO: should this call shell_completions instead of partially reimplementing it?
        let m = match(r"[\t\n\r\"`><=*?|]| (?!\\)", reverse(partial)) # fuzzy shell_parse in reverse
            startpos = nextind(partial, reverseind(partial, m.offset))
            r = startpos:pos
            scs::String = string[r]

            expanded = complete_expanduser(scs, r)
            was_expanded = expanded[3]
            if was_expanded
                scs = (only(expanded[1])::PathCompletion).path
                # If tab press, ispath and user expansion available, return it now
                # otherwise see if we can complete the path further before returning with expanded ~
                !hint && ispath(scs) && return expanded::Completions
            end

            path::String = replace(scs, r"(\\+)\g1(\\?)`" => "\1\2`") # fuzzy unescape_raw_string: match an even number of \ before ` and replace with half as many
            # This expansion with "\\ "=>' ' replacement and shell_escape=true
            # assumes the path isn't further quoted within the cmd backticks.
            path = replace(path, r"\\ " => " ", r"\$" => "\$") # fuzzy shell_parse (reversed by shell_escape_posixly)
            paths, dir, success =
                complete_path(path, shell_escape = true, raw_escape = true)

            if success && !isempty(dir)
                let dir = do_raw_escape(do_shell_escape(dir))
                    # if escaping of dir matches scs prefix, remove that from the completions
                    # otherwise make it the whole completion
                    if endswith(dir, "/") && startswith(scs, dir)
                        r = (startpos+sizeof(dir)):pos
                    elseif startswith(scs, dir * "/")
                        r = nextind(string, startpos + sizeof(dir)):pos
                    else
                        map!(paths, paths) do c::PathCompletion
                            p = dir * "/" * c.path
                            was_expanded && (p = contractuser(p))
                            return PathCompletion(p)
                        end
                    end
                end
            end
            if isempty(paths) && !hint && was_expanded
                # if not able to provide completions, not hinting, and ~ expansion was possible, return ~ expansion
                return expanded::Completions
            else
                return sort!(paths, by = p -> p.path), r::UnitRange{Int}, success
            end
        end
    elseif inc_tag === :string
        # Find first non-escaped quote
        let m = match(r"\"(?!\\)", reverse(partial))
            startpos = nextind(partial, reverseind(partial, m.offset))
            r = startpos:pos
            scs::String = string[r]

            expanded = complete_expanduser(scs, r)
            was_expanded = expanded[3]
            if was_expanded
                scs = (only(expanded[1])::PathCompletion).path
                # If tab press, ispath and user expansion available, return it now
                # otherwise see if we can complete the path further before returning with expanded ~
                !hint && ispath(scs) && return expanded::Completions
            end

            path = try
                unescape_string(replace(scs, "\\\$" => "\$"))
            catch ex
                ex isa ArgumentError || rethrow()
                nothing
            end
            if !isnothing(path)
                paths, dir, success = complete_path(path::String, string_escape = true)

                if close_path_completion(dir, paths, path, pos)
                    p = (paths[1]::PathCompletion).path * "\""
                    hint && was_expanded && (p = contractuser(p))
                    paths[1] = PathCompletion(p)
                end

                if success && !isempty(dir)
                    let dir = do_string_escape(dir)
                        # if escaping of dir matches scs prefix, remove that from the completions
                        # otherwise make it the whole completion
                        if endswith(dir, "/") && startswith(scs, dir)
                            r = (startpos+sizeof(dir)):pos
                        elseif startswith(scs, dir * "/") && dir != dirname(homedir())
                            was_expanded && (dir = contractuser(dir))
                            r = nextind(string, startpos + sizeof(dir)):pos
                        else
                            map!(paths, paths) do c::PathCompletion
                                p = dir * "/" * c.path
                                hint && was_expanded && (p = contractuser(p))
                                return PathCompletion(p)
                            end
                        end
                    end
                end

                # Fallthrough allowed so that Latex symbols can be completed in strings
                if success
                    return sort!(paths, by = p -> p.path), r::UnitRange{Int}, success
                elseif !hint && was_expanded
                    # if not able to provide completions, not hinting, and ~ expansion was possible, return ~ expansion
                    return expanded::Completions
                end
            end
        end
    end
    # if path has ~ and we didn't find any paths to complete just return the expanded path
    was_expanded && return expanded::Completions

    ok, ret = bslash_completions(string, pos)
    ok && return ret

    # Make sure that only bslash_completions is working on strings
    inc_tag === :string && return Completion[], 0:-1, false
    if inc_tag === :other
        frange, ex, wordrange, method_name_end =
            identify_possible_method_completion(partial, pos)
        if last(frange) != -1 && all(isspace, @view partial[wordrange]) # no last argument to complete
            if ex.head === :call
                return complete_methods(ex, context_module, shift),
                first(frange):method_name_end,
                false
            elseif is_broadcasting_expr(ex)
                return complete_methods(ex, context_module, shift),
                first(frange):(method_name_end-1),
                false
            end
        end
    elseif inc_tag === :comment
        return Completion[], 0:-1, false
    end

    # Check whether we can complete a keyword argument in a function call
    kwarg_completion, wordrange = complete_keyword_argument(partial, pos, context_module)
    isempty(wordrange) || return kwarg_completion, wordrange, !isempty(kwarg_completion)

    dotpos = something(findprev(isequal('.'), string, pos), 0)
    startpos =
        nextind(string, something(findprev(in(non_identifier_chars), string, pos), 0))
    # strip preceding ! operator
    if (m = match(r"\G\!+", partial, startpos)) isa RegexMatch
        startpos += length(m.match)
    end

    name = string[max(startpos, dotpos + 1):pos]
    comp_keywords = !isempty(name) && startpos > dotpos
    if afterusing(string, startpos)
        # We're right after using or import. Let's look only for packages
        # and modules we can reach from here

        # If there's no dot, we're in toplevel, so we should
        # also search for packages
        s = string[startpos:pos]
        if dotpos <= startpos
            for dir in Base.load_path()
                if basename(dir) in Base.project_names && isfile(dir)
                    append!(suggestions, project_deps_get_completion_candidates(s, dir))
                end
                isdir(dir) || continue
                for entry in _readdirx(dir)
                    pname = entry.name
                    if pname[1] != '.' &&
                       pname != "METADATA" &&
                       pname != "REQUIRE" &&
                       startswith(pname, s)
                        # Valid file paths are
                        #   <Mod>.jl
                        #   <Mod>/src/<Mod>.jl
                        #   <Mod>.jl/src/<Mod>.jl
                        if isfile(entry)
                            endswith(pname, ".jl") && push!(
                                suggestions,
                                PackageCompletion(pname[1:prevind(pname, end - 2)]),
                            )
                        else
                            mod_name = if endswith(pname, ".jl")
                                pname[1:prevind(pname, end - 2)]
                            else
                                pname
                            end
                            if isfile(joinpath(entry, "src", "$mod_name.jl"))
                                push!(suggestions, PackageCompletion(mod_name))
                            end
                        end
                    end
                end
            end
        end
        ffunc = module_filter
        comp_keywords = false
    end

    startpos == 0 && (pos = -1)
    dotpos < startpos && (dotpos = startpos - 1)
    return complete_identifiers!(
        suggestions,
        ffunc,
        context_module,
        string,
        name,
        pos,
        dotpos,
        startpos;
        comp_keywords,
    )
end

end # module OriginalREPLCompletions