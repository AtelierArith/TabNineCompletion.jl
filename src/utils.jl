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
