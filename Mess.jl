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

# import Base.show in order to use it for our own types
import Base.show

# Client arrival rates [s]
    #constante random flow gebaseerd op experimentele gegevens 
    #timings 1Ba 2Ba!!
    #een van de testen: spreiding client arrivals
const arrivals = Dict("[1130-1200[" => Distributions.Exponential(25*60),
                        "[1200-1230[" => Distributions.Exponential(1*60),
                        "[1230-1300[" => Distributions.Exponential(10*60),
                        "[1300-1330[" => Distributions.Exponential(2*60))
#distributions indicating how much time is required for every action 
   # (plateau en bestek nemen, hoofdgerecht nemen, groenten nemen, verplaatsing tussen stations...)
# Arrival time function [s]
function nextarrival(t::DateTime; arrivals::Dict=arrivals)
    if (hour(t) < 12)     #we starten de simulatie om 11:30
        return Second(round(rand(arrivals["[1130-1200["])))
    elseif (hour(t) >= 12) & (hour(t) < 13)
        if (minute(t) < 30)
            return Second(round(rand(arrivals["[1200-1230["])))
        else
            return Second(round(rand(arrivals["[1230-1300["])))
        end
    elseif (hour(t) >= 13) #we eindigen simulatie om 13:30                 
        return Second(round(rand(arrivals["[1300-1330["])))
    else
        return nothing
    end
end

struct Mess #alle onderdelen van de mess in toevoegen
    staff::Resource
    queuelength::Array{Tuple{DateTime,Int64},1}
    waitingtimes::Array{Millisecond, 1} #per station om zo te bepalen wat de bottleneck is
    function Shop(env::Environment, nstaff::Int=1)
        # add the crew
        staff = Resource(env,nstaff)
        # no queue at the start of the simulation       
        queuelength = [(nowDatetime(env),0)]              
        # client waiting times
        waitingtimes = Array{Millisecond,1}()                   
        return new(staff,queuelength,clients,waitingtimes,renegtimes)
    end
end

mutable struct Client
    id::Int
    proc::Process
    function Client(env::Environment,shop::Mess)
        client = new()
        client.id = length(shop.clients) + 1
        # start the client process
        client.proc = @process clientbehavior(env, shop, client)
        return client
    end
end

# Generating function for clients.
@resumable function clientgenerator(env::Environment, shop::Mess, topen::Int=8, tclose::Int=20)
    while true  
        tnext = nextarrival(nowDatetime(env))
        @yield timeout(env, tnext)
        c = Client(env,shop)
    end
end