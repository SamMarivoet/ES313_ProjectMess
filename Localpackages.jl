using Pkg
cd(joinpath(dirname(@__FILE__)))
@info "Activating project in $(pwd())"
Pkg.activate(pwd())
@info "Precompiling"
Pkg.update()
Pkg.instantiate()
@info "Done"