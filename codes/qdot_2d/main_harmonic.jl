push!(LOAD_PATH, pwd())

using Printf
using LinearAlgebra
using SparseArrays
using Random
using Gnuplot

import PyPlot
const plt = PyPlot
plt.rc("text", usetex=true)

using MyModule

function pot_harmonic( grid; ω=1.0, A=0.0 )
    Npoints = grid.Npoints
    Vpot = zeros(Npoints)
    for i in 1:Npoints
        x = grid.r[1,i]
        y = grid.r[2,i]
        Vpot[i] = 0.5 * ω^2 *( x^2 + y^2 ) - A
    end
    return Vpot
end

function main()

    Random.seed!(1234)

    AA = [-15.0, -15.0]
    BB = [ 15.0,  15.0]
    NN = [80, 80]

    grid = FD2dGrid( NN, AA, BB )
    #grid = LF2dGrid( NN, AA, BB, types=(:sinc,:sinc) )

    ∇2 = build_nabla2_matrix( grid )

    Vpot = pot_harmonic( grid, ω=0.22, A=1.0 )
    
    Ham = -0.5*∇2 + spdiagm( 0 => Vpot )

    prec = ILU0Preconditioner(Ham)

    @printf("sizeof Ham  = %18.10f MiB\n", Base.summarysize(Ham)/1024/1024)
    @printf("sizeof prec = %18.10f MiB\n", Base.summarysize(prec)/1024/1024)

    dVol = grid.dVol
    Nstates = 10
    Npoints = grid.Npoints
    X = rand(Float64, Npoints, Nstates)
    ortho_sqrt!(X, dVol)

    println("Check normalization")
    for i in 1:Nstates
        @printf("dot: %18.10f\n", dot(X[:,i],X[:,i])*dVol)
    end

    println("Check orthogonal")
    ist = 1
    for i in 1:Nstates
        if i != ist
            @printf("dot: %18.10f\n", dot(X[:,i],X[:,ist])*dVol)
        end
    end

    conv_info = [0,0]
    #@time evals = diag_Emin_PCG!( Ham, X, prec, verbose=true, tol=1e-10, conv_info=conv_info )
    @time evals = diag_LOBPCG!( Ham, X, prec, verbose=true, tol=1e-10, conv_info=conv_info )
    X = X/sqrt(grid.dVol) # renormalize

    #evals, NiterDiagConv = diag_davidson!( Ham, X, prec, verbose=true )
    #X = X*sqrt(dVol) # renormalize for diag_davidson
    println("conv_info = ", conv_info)
    println("Check normalization")
    for i in 1:Nstates
        @printf("dot: %18.10f\n", dot(X[:,i],X[:,i])*dVol)
    end

    println("Check orthogonal")
    ist = 1
    for i in 1:Nstates
        if i != ist
            @printf("dot: %18.10f\n", dot(X[:,i],X[:,ist])*dVol)
        end
    end

    @printf("\n\nEigenvalues\n")
    for i in 1:Nstates
        @printf("%5d %18.10f\n", i, evals[i])
    end

    plot_pyplot(grid, X)

end

function plot_gnuplot(grid, X)
    Nx = grid.Nx
    Ny = grid.Ny
    Nstates = size(X,2)
    for ist in 1:Nstates
        filesave = "IMG_X_"*string(ist)*".pdf"
        @gp "set term pdfcairo size 12cm,13cm fontscale 0.5" :-
        @gp :- "set output '$filesave'" :-
        @gp :- "set view 70, 40" :-
        @gsp :- grid.x grid.y reshape(X[:,ist], Ny, Nx) "w pm3d notitle" palette(:viridis)
        @gsp :- "set xrange [-9:9]" :-
        @gsp :- "set yrange [-9:9]"
    end
end

function plot_pyplot(grid, X)
    @printf("Plotting wave functions and slice of rhoe:\n")
    Nx = grid.Nx
    Ny = grid.Ny
    Nstates = size(X,2)
    for ist in 1:Nstates
        #
        plt.clf()
        plt.surf(grid.x, grid.y, reshape(X[:,ist], grid.Nx, grid.Ny), cmap=:jet)
        plt.tight_layout()
        plt.savefig("IMG_harmonic_psi_"*string(ist)*".pdf")
        #
        ρ = X[:,ist].*X[:,ist]
        plt.clf()
        plt.contourf(grid.x, grid.y, reshape(ρ, grid.Nx, grid.Ny), cmap=:jet)
        plt.axis("equal")
        plt.tight_layout()
        plt.savefig("IMG_harmonic_rho_"*string(ist)*".png", dpi=150)
        #
        @printf("State %d done\n", ist)
    end
end

main()



