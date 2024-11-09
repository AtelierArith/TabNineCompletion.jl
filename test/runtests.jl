using Test

using TabNineCompletion

using Aqua
using JET

@static if VERSION ≥ v"1.10"
    @testset "JET" begin
        JET.report_file(joinpath(pkgdir(TabNineCompletion), "src", "utils.jl"))
        JET.report_file(joinpath(pkgdir(TabNineCompletion), "src", "TabNineCompletion.jl"))
    end
end

@testset "Aqua" begin
    Aqua.test_all(
        TabNineCompletion;
        ambiguities = false,
        unbound_args = false,
        deps_compat = false,
    )
end
