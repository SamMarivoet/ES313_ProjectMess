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

# Client arrival rates [s]
    #constante random flow gebaseerd op experimentele gegevens 
    #timings 1Ba 2Ba!!
    #een van de testen: spreiding client arrivals
const arrivals = Dict("[1130-1200[" => Distributions.Exponential(30),
                        "[1200-1230[" => Distributions.Exponential(20),
                        "[1230-1300[" => Distributions.Exponential(3),
                        "[1300-1330[" => Distributions.Exponential(10))
const Use = Dict("Utensils" => Distributions.Normal(3.5,2),
                    "Main" => Distributions.Normal(4,2),
                    "Side" => Distributions.Normal(4,3),
                    "Des" => Distributions.Normal(3,1),
                    "Cash" => Distributions.Normal(6,2))
const Min = Dict("Utensils" => 1.5,
                    "Main" => 2,
                    "Side" => 2,
                    "Des" => 1.5,
                    "Cash" => 4)
const Max = Dict("Utensils" => 7,
                    "Main" => 8,
                    "Side" => 7,
                    "Des" => 4,
                    "Cash" => 10)
# verplaatsing tussen stations
# Arrival time function [s]
function nextarrival(t::DateTime; arrivals::Dict=arrivals)
    if (hour(t) < 12) & (minute(t) >= 30)       #we starten de simulatie om 11:30
        return Second(round(rand(arrivals["[1130-1200["])))
    elseif (hour(t) >= 12) & (hour(t) < 13)
        if (minute(t) < 30)
            return Second(round(rand(arrivals["[1200-1230["])))
        else
            return Second(round(rand(arrivals["[1230-1300["])))
        end
    elseif (hour(t) >= 13) & (minute(t) < 30)   #we eindigen simulatie om 13:30                 
        return Second(round(rand(arrivals["[1300-1330["])))
    else
        return nothing
    end
end
const Choices = ["Main_Side_Des_Cash"]
const Choprob = Distributions.Categorical([1])
# path = (Main,Side,Des,Pasta,Salad,Steak)
const Paths = Dict(Choices[1]=>[1,1,1,0,0,0])

struct Mess #alle onderdelen van de mess in toevoegen
    staff::Resource
    #queues 
    queue_Utensils1::Resource
    queue_Utensils2::Resource
    queue_Main1::Resource
    queue_Main2::Resource
    queue_Side1::Resource
    queue_Side2::Resource
    queue_Des1::Resource
    queue_Des2::Resource
    queue_Pasta::Resource
    queue_Salad::Resource
    queue_Steak::Resource
    queue_Cash1::Resource
    queue_Cash2::Resource
    #queuelengths
    queuelength_Entrance::Array{Tuple{DateTime,Int64},1}
    queuelength_Utensils1::Array{Tuple{DateTime,Int64},1}
    queuelength_Utensils2::Array{Tuple{DateTime,Int64},1}
    queuelength_Main1::Array{Tuple{DateTime,Int64},1}
    queuelength_Main2::Array{Tuple{DateTime,Int64},1}
    queuelength_Side1::Array{Tuple{DateTime,Int64},1}
    queuelength_Side2::Array{Tuple{DateTime,Int64},1}
    queuelength_Des1::Array{Tuple{DateTime,Int64},1}
    queuelength_Des2::Array{Tuple{DateTime,Int64},1}
    queuelength_Pasta::Array{Tuple{DateTime,Int64},1}
    queuelength_Salad::Array{Tuple{DateTime,Int64},1}
    queuelength_Steak::Array{Tuple{DateTime,Int64},1}
    queuelength_Cash1::Array{Tuple{DateTime,Int64},1}
    queuelength_Cash2::Array{Tuple{DateTime,Int64},1}
    #queuetimes (begin to end of queue)
    queuetime_Entrance::Array{Millisecond,1}
    queuetime_Utensils1::Array{Millisecond,1}
    queuetime_Utensils2::Array{Millisecond,1}
    queuetime_Main1::Array{Millisecond,1}
    queuetime_Main2::Array{Millisecond,1}
    queuetime_Side1::Array{Millisecond,1}
    queuetime_Side2::Array{Millisecond,1}
    queuetime_Des1::Array{Millisecond,1}
    queuetime_Des2::Array{Millisecond,1}
    queuetime_Pasta::Array{Millisecond,1}
    queuetime_Salad::Array{Millisecond,1}
    queuetime_Steak::Array{Millisecond,1}
    queuetime_Cash1::Array{Millisecond,1}
    queuetime_Cash2::Array{Millisecond,1}
    function Mess(env::Environment, nstaff::Int=6)
        # add the crew
        staff = Resource(env,nstaff)
        #add queues
        queue_Utensils1 = Resource(env,3)
        queue_Utensils2 = Resource(env,3)
        queue_Main1 = Resource(env,4)
        queue_Main2 = Resource(env,4)
        queue_Side1 = Resource(env,8)
        queue_Side2 = Resource(env,8)
        queue_Des1 = Resource(env,2)
        queue_Des2 = Resource(env,2)
        queue_Pasta = Resource(env)
        queue_Salad = Resource(env)
        queue_Steak = Resource(env)
        queue_Cash1 = Resource(env,5)
        queue_Cash2 = Resource(env,5)
        # no queue at the start of the simulation       
        queuelength_Entrance = [(nowDatetime(env),0)]
        queuelength_Utensils1 = [(nowDatetime(env),0)]
        queuelength_Utensils2 = [(nowDatetime(env),0)]
        queuelength_Main1 = [(nowDatetime(env),0)]
        queuelength_Main2 = [(nowDatetime(env),0)]
        queuelength_Side1 = [(nowDatetime(env),0)]
        queuelength_Side2 = [(nowDatetime(env),0)]
        queuelength_Des1 = [(nowDatetime(env),0)]
        queuelength_Des2 = [(nowDatetime(env),0)]
        queuelength_Pasta = [(nowDatetime(env),0)]
        queuelength_Salad = [(nowDatetime(env),0)]
        queuelength_Steak = [(nowDatetime(env),0)]
        queuelength_Cash1 = [(nowDatetime(env),0)]
        queuelength_Cash2 = [(nowDatetime(env),0)]              
        # client waiting times
        queuetime_Entrance = Array{Millisecond,1}()
        queuetime_Utensils1 = Array{Millisecond,1}()
        queuetime_Utensils2 = Array{Millisecond,1}()
        queuetime_Main1 = Array{Millisecond,1}()
        queuetime_Main2 = Array{Millisecond,1}()
        queuetime_Side1 = Array{Millisecond,1}()
        queuetime_Side2 = Array{Millisecond,1}()
        queuetime_Des1 = Array{Millisecond,1}()
        queuetime_Des2 = Array{Millisecond,1}()
        queuetime_Pasta = Array{Millisecond,1}()
        queuetime_Salad = Array{Millisecond,1}()
        queuetime_Steak = Array{Millisecond,1}()
        queuetime_Cash1 = Array{Millisecond,1}()
        queuetime_Cash2 = Array{Millisecond,1}()                    
        return new(staff,queue_Utensils1,queue_Utensils2,queue_Main1,queue_Main2,queue_Side1,queue_Side2,queue_Des1,queue_Des2,queue_Pasta,queue_Salad,queue_Steak,queue_Cash1,queue_Cash2,queuelength_Entrance,queuelength_Utensils1,queuelength_Utensils2,queuelength_Main1,queuelength_Main2,queuelength_Side1,queuelength_Side2,queuelength_Des1,queuelength_Des2,queuelength_Pasta,queuelength_Salad,queuelength_Steak,queuelength_Cash1,queuelength_Cash2,queuetime_Entrance,queuetime_Utensils1,queuetime_Utensils2,queuetime_Main1,queuetime_Main2,queuetime_Side1,queuetime_Side2,queuetime_Des1,queuetime_Des2,queuetime_Pasta,queuetime_Salad,queuetime_Steak,queuetime_Cash1,queuetime_Cash2)
    end
end

mutable struct Client
    proc::Process
    function Client(env::Environment,m::Mess)
        client = new()
        # start the client process
        client.proc = @process clientbehavior(env, m)
        return client
    end
end

# Generating function for clients.
@resumable function clientgenerator(env::Environment, m::Mess)
    while true 
        if (hour(nowDatetime(env)) < 12) & (minute(nowDatetime(env)) < 30)
            delta = floor(nowDatetime(env), Day) + Hour(11) + Minute(30) - nowDatetime(env)
            @yield timeout(env, delta)
        elseif (hour(nowDatetime(env)) >= 13) & (minute(nowDatetime(env)) >= 30)
            delta = floor(nowDatetime(env), Day) + Day(1) + Hour(11) + Minute(30) - nowDatetime(env)
            @yield timeout(env, delta)
        end

        tnext = nextarrival(nowDatetime(env))
        @yield timeout(env, tnext)
        c = Client(env,m)
    end
end

@resumable function clientbehavior(env::Environment, m::Mess)
    choice = Choices[rand(Choprob)]
    path = Paths[choice]
    tin = nowDatetime(env)
    @yield request(m.queue_Utensils1)
        push!(m.queuetime_Entrance, Millisecond(nowDatetime(env)-tin))
        push!(m.queuelength_Entrance, (nowDatetime(env), length(m.queue_Utensils1.put_queue)))
        @yield timeout(env, Millisecond(clamp(round(rand(Use["Utensils"]),digits=3),Min["Utensils"],Max["Utensils"])*10^3)) #verdeling geeft resultaat in seconden dat wordt omgezet naar milliseconden
    tin = nowDatetime(env)
    @yield request(m.queue_Main1)
        @yield request(m.staff)
        push!(m.queuetime_Main1, Millisecond(nowDatetime(env)-tin))
        push!(m.queuelength_Main1, (nowDatetime(env), length(m.queue_Main1.put_queue)))
        @yield timeout(env, Millisecond(clamp(round(rand(Use["Main"]),digits=3),Min["Main"],Max["Main"])*10^3))
    tin = nowDatetime(env)
    @yield request(m.queue_Side1)
        push!(m.queuetime_Side1, Millisecond(nowDatetime(env)-tin))
        push!(m.queuelength_Side1, (nowDatetime(env), length(m.queue_Side1.put_queue)))
        @yield timeout(env, Millisecond(clamp(round(rand(Use["Side"]),digits=3),Min["Side"],Max["Side"])*10^3))
    tin = nowDatetime(env)
    @yield request(m.queue_Des1)
        push!(m.queuetime_Des1, Millisecond(nowDatetime(env)-tin))
        push!(m.queuelength_Des1, (nowDatetime(env), length(m.queue_Des1.put_queue)))
        @yield timeout(env, Millisecond(clamp(round(rand(Use["Des"]),digits=3),Min["Des"],Max["Des"])*10^3))
    tin = nowDatetime(env)
    @yield request(m.queue_Cash1)
        @yield request(m.staff)
        push!(m.queuetime_Cash1, Millisecond(nowDatetime(env)-tin))
        push!(m.queuelength_Cash1, (nowDatetime(env), length(m.queue_Cash1.put_queue)))
        @yield timeout(env, Millisecond(clamp(round(rand(Use["Cash"]),digits=3),Min["Cash"],Max["Cash"])*10^3))
end

function plotqueue(m::Mess)
    # some makeup
    tstart = floor(m.queuelength_Entrance[1][1], Day) + Hour(11) + Minute(30)
    tstop  = floor(m.queuelength_Entrance[1][1], Day) + Hour(13) + Minute(30)
    daterange =  tstart : Minute(60) : tstop
    datexticks = [Dates.value(mom) for mom in daterange]
    datexticklabels = Dates.format.(daterange,"HH:MM")
    # queue length
    x1::Array{DateTime,1} = map(v -> v[1], m.queuelength_Entrance)
    y1::Array{Int,1} = map(v -> v[2], m.queuelength_Entrance)
    p = plot(x1, y1, linetype=:steppost, label="Queue length")
    x2::Array{DateTime,1} = map(v -> v[1], m.queuelength_Utensils1)
    y2::Array{Int,1} = map(v -> v[2], m.queuelength_Utensils1)
    plot!(x2, y2, linetype=:steppost, label="Queue length")
    x3::Array{DateTime,1} = map(v -> v[1], m.queuelength_Main1)
    y3::Array{Int,1} = map(v -> v[2], m.queuelength_Main1)
    plot!(x3, y3, linetype=:steppost, label="Queue length")
    x4::Array{DateTime,1} = map(v -> v[1], m.queuelength_Side1)
    y4::Array{Int,1} = map(v -> v[2], m.queuelength_Side1)
    plot!(x4, y4, linetype=:steppost, label="Queue length")
    x5::Array{DateTime,1} = map(v -> v[1], m.queuelength_Des1)
    y5::Array{Int,1} = map(v -> v[2], m.queuelength_Des1)
    plot!(x5, y5, linetype=:steppost, label="Queue length")
    x6::Array{DateTime,1} = map(v -> v[1], m.queuelength_Des1)
    y6::Array{Int,1} = map(v -> v[2], m.queuelength_Des1)
    plot!(x6, y6, linetype=:steppost, label="Queue length")

    xticks!(datexticks, datexticklabels,rotation=0)
    xlims!(Dates.value(tstart),Dates.value(tstop))
    yticks!(0:1:maximum(maximum, [y1;y2;y3;y4;y5;y6])+1)
    savefig(p, "./Mess_Images/queuelength.png")
end

function runsim()
    @info "$("-"^70)\nStarting a complete simulation\n$("-"^70)"
    # Start a simulation on today 00Hr00
    sim = Simulation(floor(Dates.now(),Day))
    m = Mess(sim, 3)
    @process clientgenerator(sim, m)
    # Run the sim for one day
    run(sim, floor(Dates.now(),Day) + Day(1))
    # Make an illustration of the queue length
    @info "Making queue length figure"
    plotqueue(m)
end

runsim()