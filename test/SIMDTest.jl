module SIMDTest

using Compat
using Compat.Test
using ForwardDiff: Dual, valtype
using StaticArrays: SVector

const DUALS = (Dual(1., 2., 3., 4.),
               Dual(1., 2., 3., 4., 5.),
               Dual(Dual(1., 2.), Dual(3., 4.)))


function simd_sum(x::Vector{T}) where T
    s = zero(T)
    @simd for i in eachindex(x)
        @inbounds s = s + x[i]
    end
    return s
end

# `pow2dot` is chosen so that `@code_llvm pow2dot(SVector(1:1.0:4...))`
# generates code with SIMD instructions.
# See:
# https://github.com/JuliaDiff/ForwardDiff.jl/pull/332
# https://github.com/JuliaDiff/ForwardDiff.jl/pull/331#issuecomment-406107260
@inline pow2(x) = x^2
pow2dot(xs) = pow2.(xs)

for D in map(typeof, DUALS)
    plus_bitcode = sprint(io -> code_llvm(io, +, (D, D)))
    @test contains(plus_bitcode, "fadd <4 x double>")

    minus_bitcode = sprint(io -> code_llvm(io, -, (D, D)))
    @test contains(minus_bitcode, "fsub <4 x double>")

    times_bitcode = sprint(io -> code_llvm(io, *, (D, D)))
    @test ismatch(r"fadd \<.*?x double\>", times_bitcode)
    @test ismatch(r"fmul \<.*?x double\>", times_bitcode)

    div_bitcode = sprint(io -> code_llvm(io, /, (D, D)))
    @test ismatch(r"fadd \<.*?x double\>", div_bitcode)
    @test ismatch(r"fmul \<.*?x double\>", div_bitcode)

    exp_bitcode = sprint(io -> code_llvm(io, ^, (D, D)))
    @test ismatch(r"fadd \<.*?x double\>", exp_bitcode)
    if !(valtype(D) <: Dual)
        # see https://github.com/JuliaDiff/ForwardDiff.jl/issues/167
        @test ismatch(r"fmul \<.*?x double\>", exp_bitcode)

        # see https://github.com/JuliaDiff/ForwardDiff.jl/pull/201
        sum_bitcode = sprint(io -> code_llvm(io, simd_sum, (Vector{D},)))
        @test ismatch(r"fadd \<.*?x double\>", sum_bitcode)
    end

    pow_bitcode = sprint(io -> code_llvm(io, pow2dot, (SVector{4, D},)))
    @test ismatch(r"(.*fmul \<.*?x double\>){2}"s, pow_bitcode)
end

end # module
