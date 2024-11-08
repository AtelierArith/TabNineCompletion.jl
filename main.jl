using REPL
using JSON

const TABNINE_CMD = `./binaries/4.203.0/x86_64-apple-darwin/TabNine --client sublime`

struct TabNineClient
    process::Any
    function TabNineClient()
        # https://discourse.julialang.org/t/how-to-continuously-communicate-with-an-external-program/86319/2

        inp = Base.PipeEndpoint()
        out = Base.PipeEndpoint()
        err = Base.PipeEndpoint()
        tabnineproc = run(TABNINE_CMD, inp, out, err, wait = false)
        new(tabnineproc)
    end
end

function send(client::TabNineClient, req::Dict)
    inputd = Dict("version" => "2.0.2", "request" => req)

    write(client.process, JSON.json(inputd) * "\n")
    outputjson = JSON.parse(readuntil(client.process, "\n"))
    details = map(outputjson["results"]) do o
        m = match(r"(\d+)", o["detail"])
        if isnothing(m)
            p = 0
        else
            p = parse(Int, only(m.captures))
        end
        (p, o["new_prefix"])
    end

    sort(details, rev = true)
end

tabnineclient = TabNineClient()

function REPL.REPLCompletions.completions(
    string::String,
    pos::Int,
    context_module::Module = Main,
    shift::Bool = true,
    hint::Bool = false,
)
    before = string[1:pos]
    after = ""
    m = match(r"(.+?)(?:#|$)", @__FILE__)
    if isnothing(m)
        filename = nothing
    else
        filename = m.captures |> only
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

    res = send(tabnineclient, req)

    function compare(ref, tar)
        for i = 0:min(length(ref), length(tar))-1
            ref[end-i:end] == tar[begin:i+1] && return i
        end
    end

    if isempty(res)
        (REPL.REPLCompletions.Completion[], 1:0, true)
    else
        text = first(res)[end]
        offset = compare(before, text)
        if offset != 0
            wordrange = (length(before)-compare(before, text)):length(before)
        else
            wordrange = length(before):length(before)+length(text)
        end
        (
            REPL.REPLCompletions.Completion[REPL.REPLCompletions.ModuleCompletion(
                Main,
                text,
            )],
            wordrange,
            true,
        )
    end
end
