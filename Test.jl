using Pkg
	cd(joinpath(dirname(@__FILE__),".."))
    Pkg.activate(pwd())
using Dates              # for actual time & date
using Distributions      # for distributions and random behaviour
using HypothesisTests    # for more statistical analysis
using Logging            # for debugging
using Plots              # for figures
using ConcurrentSim      # for DES
using ResumableFunctions # for resumable functions
using StatsPlots         # for nicer histograms
using Statistics         # for statistics
using Dates

@resumable function car(env::Environment)
    while true
      println("Start parking at ", now(env))
      parking_duration = 5
      @yield timeout(env, parking_duration)
      println("Start driving at ", now(env))
      trip_duration = 2
      @yield timeout(env, trip_duration)
    end
  end
sim = Simulation()
@process car(sim)
run(sim,10)

rand(Distributions.Exponential(2*60))