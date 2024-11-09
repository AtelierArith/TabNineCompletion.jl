using Test

using TabNineCompletion

using Aqua
using JET

@static if VERSION ≥ v"1.10"
	@testset "JET" begin
        JET.test_package(TabNineCompletion; target_defined_modules=true)
    end
end

@testset "Aqua" begin
    Aqua.test_all(TabNineCompletion; ambiguities = false, unbound_args = false, deps_compat = false)
end
