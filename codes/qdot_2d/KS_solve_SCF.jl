function KS_solve_SCF!(
    Ham::Hamiltonian, psi::Array{Float64,2};
    NiterMax=200, betamix=0.5,
    etot_conv_thr=1e-6,
    diag_func=diag_LOBPCG!,
    use_smearing=false,
    smear_func=smear_fermi, smear_func_entropy=smear_fermi_entropy,
    kT=0.01,
    guess_density=:random
)

    if use_smearing
        Nstates_occ = Ham.electrons.Nstates_occ
        Nstates = Ham.electrons.Nstates
        if Nstates <= Nstates_occ
            println("Nstates_occ = ", Nstates_occ)
            println("Nstates     = ", Nstates)
            error("Cannot use smearing")
        end
    end

    Npoints = Ham.grid.Npoints
    Nstates = Ham.electrons.Nstates
    dVol = Ham.grid.dVol

    Rhoe = zeros(Float64,Npoints)
    Rhoe_new = zeros(Float64,Npoints)
    
    calc_rhoe!( Ham, psi, Rhoe )
    update!( Ham, Rhoe )
    evals = zeros(Float64,Nstates)

    Etot_old = 0.0
    dEtot = 0.0
    dRhoe = 0.0

    ethr_evals_last=1e-5
    ethr = 0.1

    Nconverges = 0
    CONVERGED = false
    for iterSCF in 1:NiterMax

        # determine convergence criteria for diagonalization
        if iterSCF == 1
            ethr = 0.1
        elseif iterSCF == 2
            ethr = 0.01
        else
            ethr = ethr/5.0
            ethr = max( ethr, ethr_evals_last )
        end

        evals = diag_func( Ham, psi, Ham.precKin, tol=ethr,
                           Nstates_conv=Ham.electrons.Nstates_occ )
        if diag_func == diag_davidson!
            psi[:] = psi[:]*sqrt(dVol) # for diag_davidson
        else
            psi[:] = psi[:]/sqrt(dVol) # renormalize
        end

        if use_smearing
            E_f, Ham.energies.mTS =
            update_Focc!( Ham.electrons.Focc, smear_func, smear_func_entropy,
                          evals, Float64(Ham.electrons.Nelectrons), kT )
            @printf("\nOccupations and eigenvalues:\n")
            for i in 1:Nstates
                @printf("%3d %8.5f %18.10f\n", i, Ham.electrons.Focc[i], evals[i])
            end
            @printf("Fermi energy = %18.10f\n", E_f)
        end

        calc_rhoe!( Ham, psi, Rhoe_new )
        Rhoe = betamix*Rhoe_new + (1-betamix)*Rhoe

        update!( Ham, Rhoe )
        calc_energies!( Ham, psi )
        Etot = sum( Ham.energies )

        dRhoe = sum(abs.(Rhoe - Rhoe_new))/Npoints # MAE
        dEtot = abs(Etot - Etot_old)

        @printf("SCF: %5d %18.10f %18.10e %18.10e\n", iterSCF, Etot, dEtot, dRhoe)

        if dEtot < etot_conv_thr
            Nconverges = Nconverges + 1
        else
            Nconverges = 0
        end

        if Nconverges >= 2
            CONVERGED = true
            @printf("\nSCF is converged in iter: %d\n", iterSCF)
            break
        end

        Etot_old = Etot
        flush(stdout)
    end

    @printf("\nOccupations and eigenvalues:\n")
    for i in 1:Nstates
        @printf("%3d %8.5f %18.10f\n", i, Ham.electrons.Focc[i], evals[i])
    end
    println(Ham.energies)
    println("CONVERGED = ", CONVERGED)

    return
end