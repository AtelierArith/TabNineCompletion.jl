module TabNineCompletion

export @enabletabnine!, @disabletabnine!
export enable_load_logs_repl_history!, disable_load_logs_repl_history!

import REPL

using JSON: JSON

include("utils.jl")
include("OriginalREPLCompletions.jl")
import .OriginalREPLCompletions

struct TabNineClient
    process::Base.Process
end

function TabNineClient(tnpath::AbstractString)
    # https://discourse.julialang.org/t/how-to-continuously-communicate-with-an-external-program/86319/2
    inp = Base.PipeEndpoint()
    out = Base.PipeEndpoint()
    err = Base.PipeEndpoint()
    if !isfile(tnpath)
        error("Could not find TabNine executable.")
    end
    c = `$(tnpath)`

    tabnineproc = run(c, inp, out, err, wait = false)
    TabNineClient(tabnineproc)
end

const tabnineclient = Ref{TabNineClient}()
const load_logs_repl_history = Ref{Bool}(false)

function send(client::TabNineClient, req::Dict)
    inputd = Dict("version" => "2.0.2", "request" => req)

    write(client.process, JSON.json(inputd) * "\n")
    outputjson = JSON.parse(readuntil(client.process, "\n"))::Dict{String,Any}
    details = map(outputjson["results"]::Vector) do o
        m = match(r"(\d+)", o["detail"])
        if isnothing(m)
            p = 0
        else
            p = parse(Int, only(m.captures))
        end
        (p, o["new_prefix"])
    end

    return sort(details, rev = true)
end

function enable_load_logs_repl_history!()
    load_logs_repl_history[] = true
end

function disable_load_logs_repl_history!()
    load_logs_repl_history[] = false
end

macro enabletabnine!()
    tabninepath = Base.contractuser(get_tabnine_path())
    @info "Launch tabnine process..." tabninepath
    tabnineclient[] = TabNineClient(expanduser(tabninepath))
    @eval begin
        # Override the default REPL.REPLCompletions.completions function
        function REPL.REPLCompletions.completions(
            string::String,
            pos::Int,
            context_module::Module = Main,
            shift::Bool = true,
            hint::Bool = false,
        )
            before = string[1:pos]

            if !isnothing(match(r"\\\\", before))
                # I don't know how to handle Unicode completion
                # Fall back to the original implementation
                return OriginalREPLCompletions._completions(string, pos, context_module, shift, hint)
            end
            after = ""
            if load_logs_repl_history[]
                filename = joinpath(Base.DEPOT_PATH[1], "logs", "repl_history.jl")
            else
                filename = nothing
            end
            req = Dict(
                "Autocomplete" => Dict(
                    "before" => rstrip(before),
                    "after" => strip(after),
                    "region_includes_beginning" => true,
                    "region_includes_end" => true,
                    "filename" => filename,
                    "max_num_results" => 5,
                ),
            )

            res = send(tabnineclient[], req)

            function compare(ref, tar)
                for i = 0:min(length(ref), length(tar))-1
                    ref[end-i:end] == tar[begin:i+1] && return i
                end
                return nothing
            end

            # @info "predict" res
            if isempty(res)
                # TabNine predicts nothing.
                # Fall back to the original implementation
                return OriginalREPLCompletions._completions(string, pos, context_module, shift, hint)
            else
                try
                    text = first(res)[end]
                    offset = compare(before, text)
                    if isnothing(offset)
                        # fall back to the original implementation
                        return OriginalREPLCompletions._completions(string, pos, context_module, shift, hint)
                    else
                        wordrange = (length(before)-offset::Int):length(before)
                        return (
                            REPL.REPLCompletions.Completion[REPL.REPLCompletions.ModuleCompletion(
                                context_module,
                                text,
                            )],
                            wordrange,
                            true,
                        )
                    end
                catch
                    # My TabNineCompletion fails.
                    # Fall back to the original implementation
                    #eturn OriginalREPLCompletions._completions(string, pos, context_module, shift, hint)
                end
            end
        end
    end
end

macro inittabnine!()
    esc(:(@enabletabnine!))
end

Base.@deprecate var"@inittabnine!" var"@enabletabnine!"

macro disabletabnine!()
    disable_load_logs_repl_history!()
    @eval begin
        function REPL.REPLCompletions.completions(
            string::String,
            pos::Int,
            context_module::Module = Main,
            shift::Bool = true,
            hint::Bool = false,
        )
            OriginalREPLCompletions._completions(string, pos, context_module, shift, hint)
        end
    end
end

end # module TabNineCompletion
