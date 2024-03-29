using Pkg
	cd(joinpath(dirname(@__FILE__)))
  Pkg.activate(pwd())
using Dates              # for actual time & date
using Distributions      # for distributions and random behaviour
using HypothesisTests    # for more statistical analysis
using Logging            # for debugging
using Plots              # for figures
using ConcurrentSim      # for DES
using ResumableFunctions # for resumable functions
using Statistics         # for statistics
for i = (1:
  10)
  println(i)
end