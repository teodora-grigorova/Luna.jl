import Test: @test, @testset, @test_throws, @test_broken
import Luna: Maths
import Dierckx

@testset "Derivatives" begin
    f(x) = @. 4x^3 + 3x^2 + 2x + 1

    @test isapprox(Maths.derivative(f, 1, 1), 12+6+2)
    @test isapprox(Maths.derivative(f, 1, 2), 24+6)
    @test isapprox(Maths.derivative(f, 1, 3), 24)

    e(x) = @. exp(x)

    x = [1, 2, 3, 4, 5]
    @test isapprox(Maths.derivative(e, 1, 5), exp(1), rtol=1e-6)
    @test isapprox(Maths.derivative.(e, x, 5), exp.(x), rtol=1e-6)

    @test isapprox(Maths.derivative(x -> exp.(2x), 1, 1), 2*exp(2))
    @test isapprox(Maths.derivative(x -> exp.(2x), 1, 2), 4*exp(2))
    @test isapprox(Maths.derivative(x -> exp.(-x.^2), 0, 1), 0, atol=1e-14)
end

@testset "Moments" begin
    x = collect(range(-10, stop=10, length=513))
    y = Maths.gauss(x, 1, x0=1)
    @test Maths.moment(x, y) ≈ 1
    @test Maths.moment(x, y, 2) ≈ 2
    @test Maths.rms_width(x, y) ≈ 1

    x0 = [-2.5, -1.0, 0.0, 1.0, 2.5]
    σ = [0.1, 0.5, 1.0, 1.5, 1.5]
    y = zeros(length(x), length(x0))
    for ii = 1:length(x0)
        y[:, ii] = Maths.gauss(x, σ[ii], x0=x0[ii])
    end
    @test_throws DomainError Maths.moment(x, y, dim=2)
    @test all(isapprox.(transpose(Maths.moment(x, y, dim=1)), x0, atol=1e-5))
    @test all(isapprox.(transpose(Maths.rms_width(x, y, dim=1)), σ, atol=1e-5))

    yt = transpose(y)
    @test_throws DomainError Maths.moment(x, yt, dim=1)
    xm = Maths.moment(x, yt, dim=2)
    @test all(isapprox.(xm, x0, atol=1e-5))
end

@testset "Fourier" begin
    t = collect(range(-10, stop=10, length=513))
    Et = Maths.gauss(t, fwhm=4).*cos.(4*t)
    EtA = Maths.hilbert(Et)
    @test maximum(abs.(EtA)) ≈ 1
    @test all(isapprox.(real(EtA), Et, atol=1e-9))

    hilbert! = Maths.plan_hilbert!(Et)
    out = complex(Et)
    hilbert!(out, Et)
    @test all(out .≈ EtA)

    hilbert = Maths.plan_hilbert(Et)
    out = hilbert(Et)
    @test all(out .≈ EtA)

    t = collect(range(-10, stop=10, length=512))
    Et = Maths.gauss(t, fwhm=4).*cos.(4*t)
    to, Eto = Maths.oversample(t, Et, factor=4)
    @test 4*size(Et)[1] == size(Eto)[1]
    @test all(isapprox.(Eto[1:4:end], Et, rtol=1e-6))

    Etc = Maths.gauss(t, fwhm=4).*exp.(1im*4*t)
    to, Etco = Maths.oversample(t, Etc, factor=4)
    @test 4*size(Etc)[1] == size(Etco)[1]
    @test all(isapprox.(Etco[1:4:end], Etc, rtol=1e-6))
end

@testset "integration" begin
    x = collect(range(0, stop=8π, length=2^14)).*1e-15
    y = cos.(x.*1e15)
    yi = sin.(x.*1e15)./1e15
    yic = similar(yi)
    yic2 = copy(y)
    Maths.cumtrapz!(yic, y, x)
    Maths.cumtrapz!(yic2, x[2]-x[1])
    @test isapprox(yi, yic, rtol=1e-6)
    @test isapprox(yi, yic2, rtol=1e-6)

    ω = [1e15, 2e15]'
    y = cos.(x.*ω)
    yi =  sin.(x.*ω)./ω
    yic = similar(y)
    yic2 = copy(y)
    Maths.cumtrapz!(yic, y, x)
    Maths.cumtrapz!(yic2, x[2]-x[1])
    @test isapprox(yi, yic, rtol=1e-6)
    @test isapprox(yi, yic2, rtol=1e-6)
end

@testset "series" begin
    sumfunc(x, n) = x + 1/factorial(n)
    e, succ, steps = Maths.aitken_accelerate(sumfunc, 0, rtol=1e-10)
    e2, succ, steps = Maths.converge_series(sumfunc, 0, rtol=1e-10)
    @test isapprox(e, exp(1), rtol=1e-10)
    @test isapprox(e, e2, rtol=1e-10)
    sumfunc(x, n) = x + 1/2^n
    o, succ, steps = Maths.aitken_accelerate(sumfunc, 0, n0=1, rtol=1e-10)
    @test isapprox(o, 1, rtol=1e-10)
    serfunc(x, n) = (x + 2/x)/2
    sqrt2, succ, steps = Maths.aitken_accelerate(serfunc, 1, rtol=1e-10)
    @test isapprox(sqrt2, sqrt(2), rtol=1e-10)
end

@testset "windows" begin
    x = collect(range(-10, stop=10, length=2048))
    pl = Maths.planck_taper(x, -5, -4, 7, 8)
    @test all(pl[x .< -5] .== 0)
    @test all(pl[-4 .< x .< 7] .== 1)
    @test all(pl[8 .< x] .== 0)
end

@testset "CSpline" begin
    import Random: shuffle
    x = range(0.0, 2π, length=100)
    y = sin.(x)
    spl = Maths.CSpline(x, y)
    fslow(x0) = x0 <= spl.x[1] ? 2 :
                x0 >= spl.x[end] ? length(spl.x) :
                findfirst(x -> x>x0, spl.x)
    ff = Maths.FastFinder(x)
    @test_throws ErrorException Maths.FastFinder(x[end:-1:1])
    @test_throws ErrorException Maths.FastFinder(shuffle(x))
    @test_throws ErrorException Maths.FastFinder(vcat(x[1], x))
    @test all(abs.(spl.(x) .- y) .< 5e-18)
    x2 = range(0.0, 2π, length=300)
    idcs = spl.ifun.(x2)
    idcs_slow = fslow.(x2)
    idcs_ff = ff.(x2)
    idcs_ff_bw = ff.(x2[end:-1:1])
    @test idcs == idcs_slow
    @test idcs_ff == idcs_slow
    @test idcs_ff_bw == idcs_slow[end:-1:1]
    for i = 1:10
        x2r = shuffle(x2)
        @test ff.(x2r) == fslow.(x2r)
    end
    # Create new FastFinder, immediately index backwards - does this still work?
    ff = Maths.FastFinder(x)
    @test ff.(x2[end:-1:1]) == idcs_slow[end:-1:1]
    # Extrapolation
    ff = Maths.FastFinder(x)
    x3 = range(-0.5, 2π+0.5, length=200)
    @test ff.(x3[end:-1:1]) == fslow.(x3[end:-1:1])
    @test ff.(x3) == fslow.(x3)
    @test maximum(spl.(x2) - sin.(x2)) < 5e-8
    @test abs(Maths.derivative(spl, 1.3, 1) - cos(1.3)) < 1.7e-7
    @test maximum(cos.(x2) - Maths.derivative.(spl, x2, 1)) < 2.1e-6
end

@testset "BSpline" begin
    x = range(0.0, 2π, length=100)
    y = sin.(x)
    spl = Maths.BSpline(x, y)
    @test all(abs.(spl.(x) .- y) .< 3e-16)
    x2 = range(0.0, 2π, length=300)
    @test maximum(spl.(x2) - sin.(x2)) < 5e-8
    # these use the actual spline derivative
    @test abs(Maths.derivative(spl, 1.3, 1) - cos(1.3)) < 1.7e-7
    @test maximum(cos.(x2) - Maths.derivative.(spl, x2, 1)) < 2.1e-6
    # test second derivative
    @test maximum(-sin.(x2) - Maths.derivative.(spl, x2, 2)) < 2.0e-4
    # test direct finite differences
    @test abs(invoke(Maths.derivative, Tuple{Any,Any,Integer}, spl, 1.3, 1) - cos(1.3)) < 1.7e-7
    @test maximum(cos.(x2) .- invoke.(Maths.derivative, Tuple{Any,Any,Integer}, spl, x2, 1)) < 2.1e-6
    # test roots
    yr = x.^2 .- 1.0
    splr = Maths.BSpline(x, yr)
    @test Maths.roots(splr) == [1.0]
    # test complex
    yi = sin.(x .+ π/6)
    yc = complex.(y, yi)
    splc = Maths.BSpline(x, complex.(y, yi))
    @test all(abs.(splc.(x) .- yc) .< 5e-16)
    @test maximum(abs.(splc.(x2) .- complex.(sin.(x2), sin.(x2 .+ π/6)))) < 2.6e-7
    @test abs(Maths.derivative(splc, 1.3, 1) - complex(cos(1.3), cos(1.3 + π/6))) < 2.5e-7
    @test abs(Maths.derivative(splc, 1.3, 2) - complex(-sin(1.3), -sin(1.3 + π/6))) < 2.5e-3
    # test Julia evaluation vs original Dierckx
    @test all(spl.(x2) .== spl.rspl.(x2))
    # test full spline Derivatives
    spl1 = Maths.differentiate_spline(spl, 1)
    @test maximum(abs.(cos.(x2) .- spl1.(x2))) < 5.1e-6
    spl2 = Maths.differentiate_spline(spl, 2)
    @test isapprox(-sin.(x2), spl2.(x2),  rtol=3e-5)
    spl3 = Maths.differentiate_spline(spl, 3)
    @test isapprox(-cos.(x2), spl3.(x2),  rtol=8e-4)
end

@testset "randgauss" begin
    import Statistics: std, mean
    x = Maths.randgauss(1, 0.5, 1000000, seed=1234)
    @test isapprox(std(x), 0.5, rtol=1e-3)
    @test isapprox(mean(x), 1, rtol=1e-3)
    x = Maths.randgauss(10, 0.1, 1000000, seed=1234)
    @test isapprox(std(x), 0.1, rtol=1e-3)
    @test isapprox(mean(x), 10, rtol=1e-3)
    x = Maths.randgauss(-1, 0.5, 1000000, seed=1234)
    @test isapprox(std(x), 0.5, rtol=1e-3)
    @test isapprox(mean(x), -1, rtol=1e-3)
    x = Maths.randgauss(1, 0.5, (1000, 1000), seed=1234)
    @test isapprox(std(x), 0.5, rtol=1e-3)
    @test isapprox(mean(x), 1, rtol=1e-3)
end
