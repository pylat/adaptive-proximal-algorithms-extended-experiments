include(joinpath(@__DIR__, "..", "logging.jl"))

using Random
using LinearAlgebra
using Logging: with_logger, @logmsg
using Tables
using DataFrames
using Plots
using LaTeXStrings
using ProximalCore
using ProximalOperators: NormL1
using AdaProx

pgfplotsx()

struct LinearLeastSquares{TA,Tb}
    A::TA
    b::Tb
end

function AdaProx.eval_with_pullback(f::LinearLeastSquares, w)
    res = f.A * w - f.b
    linear_least_squares_pullback() = f.A' * res
    return 0.5 * norm(res)^2, linear_least_squares_pullback
end

(f::LinearLeastSquares)(w) = AdaProx.eval_with_pullback(f, w)[1]

function run_random_lasso(;
    m = 400,
    n = 1000,
    pfactor = 5,
    seed = 0,
    tol = 1e-5,
    kappa = 0.01,
    maxit = 10_000,
)
    @info "Start Lasso ($m by $n)"

    Random.seed!(seed)

    T = Float64
    I = Int64

    p = n / pfactor # nonzeros
    rho = 1 # some positive number controlling how large solution is
    lam = 1  
    y_star = rand(m)
    y_star ./= norm(y_star) #y^\star
    C = rand(m, n) .* 2 .- 1

    CTy = abs.(C' * y_star)
    perm = sortperm(CTy, rev = true) # indices with decreasing order by abs

    alpha = zeros(n)
    for i = 1:n
        if i <= p
            alpha[perm[i]] = lam / CTy[perm[i]]
        else
            temp = CTy[perm[i]]
            if temp < 0.1 * lam
                alpha[perm[i]] = lam
            else
                alpha[perm[i]] = lam * rand() / temp
            end
        end
    end
    A = C * diagm(0 => alpha)   # scaling the columns of Cin
    # generate the primal solution
    x_star = zeros(n)
    for i = 1:n
        if i <= p
            x_star[perm[i]] = rand() * rho / sqrt(p) * sign(dot(A[:, perm[i]], y_star))
        end
    end
    b = A * x_star + y_star
    optimum = norm(y_star) / 2 + lam * norm(x_star, 1) # the solution

    @logmsg AdaProx.Record "" method=nothing it=1 objective=optimum

    Lf = opnorm(A)^2
    gam_init = 1 / Lf
    f = LinearLeastSquares(A, b)
    g = NormL1(lam)


    xi_values = [1.0, 1.1, 1.3, 1.5, 2]
    for xi = xi_values
        sol, numit = AdaProx.backtracking_proxgrad(
            zeros(n),
            f = AdaProx.Counting(f),
            g = g,
            gamma0 = gam_init,
            xi = xi, #increase in stepsize
            tol = tol,
            maxit = maxit,
            name = "PGM (backtracking) (xi=$(xi))"
        )
    end

    sol, numit = AdaProx.fixed_nesterov(
        zeros(n),
        f = AdaProx.Counting(f),
        g = g,
        gamma = gam_init,
        tol = tol,
        maxit = maxit,
        name = "Nesterov (fixed)"
    )

    sol, numit = AdaProx.adaptive_proxgrad(
        zeros(n),
        f = AdaProx.Counting(f),
        g = g,
        rule = AdaProx.MalitskyMishchenkoRule(gamma = gam_init),
        tol = tol,
        maxit = maxit,
        name = "AdaPGM (MM)"
    )

    sol, numit = AdaProx.adaptive_proxgrad(
        zeros(n),
        f = AdaProx.Counting(f),
        g = g,
        rule = AdaProx.OurRule(gamma = gam_init),
        tol = tol,
        maxit = maxit,
        name = "AdaPGM (Ours)"
    )

    parameters = [
        #########Tested for best values (xi, nu, 1/pi)
        (1/3, 1, 0.9), 
        # (2/3, 1, 5/8), 
        (1, 1, 3/5), # works best
        (1, 1, 2/3), 
        (1.5, 1, 2/5),
        (1, 1, 1),  
        # (7/3, 1, 1/3), 
        # (4, 1, 1/4), 
        #
    ]
    for (xi, nu, rp) in parameters # xi = p/r - nu
        p = 1/rp # rp stands for 1/pi
        r = p/ ((xi + nu))  # note that pi = r * (xi+nu)
        sol, numit = AdaProx.adaptive_proxgrad(
            zeros(n),
            f = AdaProx.Counting(f),
            g = g,
            rule = AdaProx.OurRulePlus(gamma = gam_init, xi = xi, r = r, nu = nu),
            tol = tol,
            maxit = maxit,
            name = "AdaPGM (p,nu,r) ($(round(p, digits=2)), $(nu), $(round(r, digits=2)))"
        )
    end
end

function plot_convergence(path)
    df = eachline(path) .|> JSON.parse |> Tables.dictrowtable |> DataFrame
    optimal_value = minimum(df[!, :objective])
    gb = groupby(df, :method)

    fig = plot(
        title = "Lasso ($(basename(path)))",
        xlabel = L"\mbox{call to } \mathcal A, \mathcal A'",
        ylabel = L"F(x^k) - F_\star",
    )

    for k in keys(gb)
        if k.method === nothing
            continue
        end
        plot!(
            # each evaluation of f is one mul with A
            # each gradient of f is one additional mul with A'
            gb[k][!, :grad_f_evals] + gb[k][!, :f_evals],
            max.(1e-14, gb[k][!, :objective] .- optimal_value),
            yaxis = :log,
            label = k.method,
        )
    end

    savefig(fig, joinpath(@__DIR__, "$(basename(path)).pdf"))
end

function main(;maxit = 2500)
    col = [
        (100, 300, 10),
        (500, 1000, 10),
        (4000, 1000, 10),
    ]
    for (m, n, pf) in col
        path = joinpath(@__DIR__, "lasso_$(m)_$(n)_$(pf).jsonl")
        with_logger(get_logger(path)) do
            run_random_lasso(
                m = m,
                n = n,
                pfactor = pf,
                maxit = maxit,
                tol = 1e-7,
                seed = 0,
            )
        end
        plot_convergence(path)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
