module TabNineCompletion

export @inittabnine!

import REPL
using JSON: JSON

function get_arch()
    arch = String(Sys.ARCH)
    if arch == "x86_64"
        return "x64"
    elseif arch == "i686"
        return "x32"
    elseif arch == "aarch64"
        return "arm64"
    else
        return arch
    end
end

function get_platform()
    if Sys.islinux()
        return "linux"
    elseif Sys.isapple()
        return "osx"
    elseif Sys.iswindows()
        return "windows"
    else
        return "unknown"
    end
end

function get_tabnine_path()
    translation = Dict(
        ("linux", "x32") => "i686-unknown-linux-musl/TabNine",
        ("linux", "x64") => "x86_64-unknown-linux-musl/TabNine",
        ("osx", "x32") => "i686-apple-darwin/TabNine",
        ("osx", "x64") => "x86_64-apple-darwin/TabNine",
        ("osx", "arm64") => "aarch64-apple-darwin/TabNine",
        ("windows", "x32") => "i686-pc-windows-gnu/TabNine.exe",
        ("windows", "x64") => "x86_64-pc-windows-gnu/TabNine.exe",
    )

    platform_key = (get_platform(), get_arch())
    platform = translation[platform_key]

    active_path = joinpath(pkgdir(@__MODULE__)::String, "deps", "binaries")
    v = sort(VersionNumber.(readdir(active_path)), rev = true) |> first |> string
    path = joinpath(active_path, v, platform)
    return path
end

struct TabNineClient
    process::Base.Process
end

function TabNineClient(tnpath::AbstractString)
    # https://discourse.julialang.org/t/how-to-continuously-communicate-with-an-external-program/86319/2
    inp = Base.PipeEndpoint()
    out = Base.PipeEndpoint()
    err = Base.PipeEndpoint()
    @assert isfile(tnpath)
    c = `$(tnpath)`

    tabnineproc = run(c, inp, out, err, wait = false)
    TabNineClient(tabnineproc)
end

const tabnineclient = Ref{TabNineClient}()

function send(client::TabNineClient, req::Dict)
    inputd = Dict("version" => "2.0.2", "request" => req)

    write(client.process, JSON.json(inputd) * "\n")
    outputjson = JSON.parse(readuntil(client.process, "\n"))::Dict{String, Any}
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

macro inittabnine!()
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
            # @info "userinput" before
            after = ""
            #filename = joinpath(Base.DEPOT_PATH[1], "logs", "repl_history.jl")
            filename = nothing
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
            end

            # @info "predict" res
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
                        context_module,
                        text,
                    )],
                    wordrange,
                    true,
                )
            end
        end
    end
end

end # module TabNineCompletion
