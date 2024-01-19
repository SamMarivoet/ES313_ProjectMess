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

sim = Simulation()

    tstart_data = floor(now(),Day)+(Hour(11) + Minute(30))
    tstop_data  = Hour(13) + Minute(30)
    daterange =  tstart_data : Minute(60) : tstop_data
for element in daterange
  println(element)
end

x1 = Array{DateTime,1}()