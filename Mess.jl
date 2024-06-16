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

const arrivals = Dict("[1130-1200[" => Distributions.Exponential(30),
                        "[1200-1230[" => Distributions.Exponential(20),
                        "[1230-1300[" => Distributions.Exponential(5),
                        "[1300-1330[" => Distributions.Exponential(10))
const Use = Dict("Utensils" => Distributions.Normal(5.9,2.1),
                    "Main" => Distributions.Gamma(8.83,0.92),
                    "Side" => Distributions.Normal(4,3),
                    "Side_veg" => Distributions.Gamma(7.86,0.86),
                    "Side_carbs1" => Distributions.Gamma(18.29,0.37),
                    "Side_carbs2" => Distributions.Gamma(42.89,0.29),
                    "Saus" => Distributions.Gamma(18.98,0.62),
                    "Kaas1" => Distributions.Normal(9.79,2.46), #optimal (29/35)
                    "Kaas2" => Distributions.Normal(18.48,1.25), #rondlopen (6/35)
                    "Pasta" => Distributions.Gamma(9.16,1.88),
                    "Des" => Distributions.Gamma(4.28,0.80),
                    "Glas" => Distributions.Normal(3.35,1.16),
                    "Cash" => Distributions.Gamma(10.56,1.12))
const Min = Dict("Utensils" => 1.7,
                    "Main" => 3.4,
                    "Side" => 2,
                    "Side_veg" => 3.2,
                    "Side_carbs" => 3.5,
                    "Saus" => 7.4,
                    "Kaas1" => 3.6,
                    "Kaas2" => 16.7,
                    "Pasta" => 7.4,
                    "Des" => 1.3,
                    "Glas" => 1.2,
                    "Cash" => 5.5)
const Max = Dict("Utensils" => 14,
                    "Main" => 16.3,
                    "Side" => 7,
                    "Side_veg" => 12.1,
                    "Side_carbs" => 30.8,
                    "Saus" => 22.6,
                    "Kaas1" => 13.7,
                    "Kaas2" => 20.3,
                    "Pasta" => 32.5,
                    "Des" => 11.2,
                    "Glas" => 5.7,
                    "Cash" => 23.2)

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
const Choices = ["Main_Side_Des_Cash","Pasta_optDes"]
const Choprob = Distributions.Categorical([0.8344, 0.1656])
const Des12 = [1,2] #1→des @ utensils; 2→des @ glas
const Des12prob = [0.5 0.5]
const Desprob = 0.0925 #kans op desert indien geen main
# path = (Main,Side,Des,Pasta)
const Paths = Dict(Choices[1]=>[1,1,1,0],
                    Choices[2]=>[0,0,1,1])

mutable struct Mess
    #crew
        staff::Resource
    #Containers
        Main1_1::Container
        Main1_2::Container
        Main1_3::Container
        Main1_4::Container
        Main2_1::Container
        Main2_2::Container
        Main2_3::Container
        Main2_4::Container
        Side1::Container
        Side2::Container
        Side3::Container
        Side4::Container
        Side5::Container
        Side6::Container
        Side7::Container
        Side8::Container
        Side9::Container
        Side10::Container
        Side11::Container
        Side12::Container
        Fries1::Container
        Fries2::Container
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
        queue_Saus::Resource
        queue_Kaas::Resource
        queue_Cha_PastaDes::Resource
        queue_Cha_SideDes1::Resource
        queue_Cha_SideDes2::Resource
        queue_Salad::Resource
        queue_Steak::Resource
        queue_Glas1::Resource
        queue_Glas2::Resource
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
        queuelength_Saus::Array{Tuple{DateTime,Int64},1}
        queuelength_Kaas::Array{Tuple{DateTime,Int64},1}
        queuelength_Salad::Array{Tuple{DateTime,Int64},1}
        queuelength_Steak::Array{Tuple{DateTime,Int64},1}
        queuelength_Glas1::Array{Tuple{DateTime,Int64},1}
        queuelength_Glas2::Array{Tuple{DateTime,Int64},1}
        queuelength_Cash1::Array{Tuple{DateTime,Int64},1}
        queuelength_Cash2::Array{Tuple{DateTime,Int64},1}
    #queuetimes (begin to end of queue)
        queuetime_Entrance::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Utensils1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Utensils2::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Main1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Main2::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Side1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Side2::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Des1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Des2::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Pasta::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Saus::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Kaas::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Salad::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Steak::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Glas1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Glas2::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Cash1::Array{Tuple{DateTime,Millisecond},1}
        queuetime_Cash2::Array{Tuple{DateTime,Millisecond},1}
    #clientcounter
        clientcounter::Int64
    function Mess(env::Environment, nstaff::Int=6)
        #add the crew
            staff = Resource(env,nstaff)
        #Containers
            Main1_1=Container(env,30,30)
            Main1_2=Container(env,30,30)
            Main1_3=Container(env,30,30)
            Main1_4=Container(env,30,30)
            Main2_1=Container(env,30,30)
            Main2_2=Container(env,30,30)
            Main2_3=Container(env,30,30)
            Main2_4=Container(env,30,30)
            Side1=Container(env,30,30)
            Side2=Container(env,30,30)
            Side3=Container(env,30,30)
            Side4=Container(env,30,30)
            Side5=Container(env,30,30)
            Side6=Container(env,30,30)
            Side7=Container(env,30,30)
            Side8=Container(env,30,30)
            Side9=Container(env,30,30)
            Side10=Container(env,30,30)
            Side11=Container(env,30,30)
            Side12=Container(env,30,30)
            Fries1=Container(env,15,15)
            Fries2=Container(env,15,15)
        #add queues
            queue_Utensils1 = Resource(env,3)
            queue_Utensils2 = Resource(env,3)
            queue_Main1 = Resource(env,4)
            queue_Main2 = Resource(env,4)
            queue_Side1 = Resource(env,8)
            queue_Side2 = Resource(env,8)
            queue_Des1 = Resource(env,2)
            queue_Des2 = Resource(env,2)
            queue_Pasta = Resource(env,2)
            queue_Saus = Resource(env,2)
            queue_Kaas = Resource(env,2)
            queue_Cha_PastaDes = Resource(env,5)
            queue_Cha_SideDes1 = Resource(env,3)
            queue_Cha_SideDes2 = Resource(env,3)
            queue_Salad = Resource(env)
            queue_Steak = Resource(env)
            queue_Glas1 = Resource(env,4)
            queue_Glas2 = Resource(env,4)
            queue_Cash1 = Resource(env,1)
            queue_Cash2 = Resource(env,1)
        #no queue at the start of the simulation       
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
            queuelength_Saus = [(nowDatetime(env),0)]
            queuelength_Kaas = [(nowDatetime(env),0)]
            queuelength_Salad = [(nowDatetime(env),0)]
            queuelength_Steak = [(nowDatetime(env),0)]
            queuelength_Glas1 = [(nowDatetime(env),0)]
            queuelength_Glas2 = [(nowDatetime(env),0)]
            queuelength_Cash1 = [(nowDatetime(env),0)]
            queuelength_Cash2 = [(nowDatetime(env),0)]              
        #client waiting times
            queuetime_Entrance = [(nowDatetime(env),Millisecond(0))]
            queuetime_Utensils1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Utensils2 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Main1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Main2 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Side1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Side2 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Des1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Des2 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Pasta = [(nowDatetime(env),Millisecond(0))]
            queuetime_Saus = [(nowDatetime(env),Millisecond(0))]
            queuetime_Kaas = [(nowDatetime(env),Millisecond(0))]
            queuetime_Salad = [(nowDatetime(env),Millisecond(0))]
            queuetime_Steak = [(nowDatetime(env),Millisecond(0))]
            queuetime_Glas1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Glas2 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Cash1 = [(nowDatetime(env),Millisecond(0))]
            queuetime_Cash2 = [(nowDatetime(env),Millisecond(0))]
        #clientcounter starts at 0
            clientcounter = 0                    
        return new(staff,
            Main1_1,Main1_2,Main1_3,Main1_4,Main2_1,Main2_2,Main2_3,Main2_4,Side1,Side2,Side3,Side4,Side5,Side6,Side7,Side8,Side9,Side10,Side11,Side12,Fries1,Fries2,
            queue_Utensils1,queue_Utensils2,queue_Main1,queue_Main2,queue_Side1,queue_Side2,queue_Des1,queue_Des2,queue_Pasta,queue_Saus,queue_Kaas,queue_Cha_PastaDes,queue_Cha_SideDes1,queue_Cha_SideDes2,queue_Salad,queue_Steak,queue_Glas1,queue_Glas2,queue_Cash1,queue_Cash2,
            queuelength_Entrance,queuelength_Utensils1,queuelength_Utensils2,queuelength_Main1,queuelength_Main2,queuelength_Side1,queuelength_Side2,queuelength_Des1,queuelength_Des2,queuelength_Pasta,queuelength_Saus,queuelength_Kaas,queuelength_Salad,queuelength_Steak,queuelength_Glas1,queuelength_Glas2,queuelength_Cash1,queuelength_Cash2,
            queuetime_Entrance,queuetime_Utensils1,queuetime_Utensils2,queuetime_Main1,queuetime_Main2,queuetime_Side1,queuetime_Side2,queuetime_Des1,queuetime_Des2,queuetime_Pasta,queuetime_Saus,queuetime_Kaas,queuetime_Salad,queuetime_Steak,queuetime_Glas1,queuetime_Glas2,queuetime_Cash1,queuetime_Cash2,
            clientcounter)
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


@resumable function clientgenerator(env::Environment, m::Mess; mode::Int=0, impuls::Int=80)
    if mode == 0
        while true 
            if (hour(nowDatetime(env)) < 12) & (minute(nowDatetime(env)) < 30)
                delta = floor(nowDatetime(env), Day) + Hour(11) + Minute(30) - nowDatetime(env)
                @yield timeout(env, delta)
            elseif (hour(nowDatetime(env)) >= 13) & (minute(nowDatetime(env)) >= 30)
                delta = floor(nowDatetime(env), Day) + Day(1) + Hour(11) + Minute(30) - nowDatetime(env)
                @yield timeout(env, delta)
            elseif (hour(nowDatetime(env)) == 12) & (minute(nowDatetime(env)) == 30)
                for _ = 1:75
                    c = Client(env,m)
                end
            end
            tnext = nextarrival(nowDatetime(env))
            @yield timeout(env, tnext)
            m.clientcounter += 1
            c = Client(env,m)
        end
    elseif mode == 1
        for _ = 1:impuls
            m.clientcounter += 1
            c = Client(env,m)
        end
    end
end

@resumable function clientbehavior(env::Environment, m::Mess)
#keuze
    choice = Choices[rand(Choprob)]
    path = Paths[choice]
    if choice == "Main_Side_Des_Cash"
        Deschoice = Des12[rand(Desprob)]
    elseif rand() < Desprob
        Deschoice = 2
    else
        Deschoice = 0
    end
    tin = nowDatetime(env)
#Utensils
    @yield request(m.queue_Utensils1)
        push!(m.queuetime_Entrance, (nowDatetime(env),nowDatetime(env)-tin))
        push!(m.queuelength_Entrance, (nowDatetime(env), length(m.queue_Utensils1.put_queue)))
        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Utensils"]),Min["Utensils"],Max["Utensils"])*10^3))) #verdeling geeft resultaat in seconden dat wordt omgezet naar milliseconden
    tin = nowDatetime(env)
#Main + Side + Des_start
    if path[1] == 1 
        @yield request(m.queue_Main1)
        @yield release(m.queue_Utensils1)  
            if Deschoice == 1
                @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Des"]),Min["Des"],Max["Des"])*10^3)))
            end  
            @yield request(m.staff)
            push!(m.queuetime_Main1, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.queuelength_Main1, (nowDatetime(env), length(m.queue_Main1.put_queue)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Main"]),Min["Main"],Max["Main"])*10^3)))
            @yield release(m.staff)
        tin = nowDatetime(env)
        @yield request(m.queue_Side1)
        @yield release(m.queue_Main1)
            push!(m.queuetime_Side1, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.queuelength_Side1, (nowDatetime(env), length(m.queue_Side1.put_queue)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Side"]),Min["Side"],Max["Side"])*10^3)))
        tin = nowDatetime(env)
            @yield request(m.queue_Cha_SideDes1)
            @yield release(m.queue_Side1)
            @yield timeout(env, Millisecond(2000))
            @yield request(m.queue_Des1)
            @yield release(m.queue_Cha_SideDes1)
#Pasta + Des_start
    elseif path[4] == 1
        @yield release(m.queue_Utensils1)
        @yield request(m.queue_Pasta)
            push!(m.queuetime_Pasta, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.queuelength_Pasta, (nowDatetime(env), length(m.queue_Pasta.put_queue)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Pasta"]),Min["Pasta"],Max["Pasta"])*10^3)))
        tin = nowDatetime(env)
        @yield request(m.queue_Saus)
        @yield release(m.queue_Pasta)    
            push!(m.queuetime_Saus, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.queuelength_Saus, (nowDatetime(env), length(m.queue_Saus.put_queue)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Saus"]),Min["Saus"],Max["Saus"])*10^3)))
        tin = nowDatetime(env)
        @yield request(m.queue_Kaas)
        @yield release(m.queue_Saus)
            push!(m.queuetime_Kaas, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.queuelength_Kaas, (nowDatetime(env), length(m.queue_Kaas.put_queue)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Kaas"]),Min["Kaas"],Max["Kaas"])*10^3)))
        tin = nowDatetime(env)
            @yield request(m.queue_Cha_PastaDes)
            @yield release(m.queue_Kaas)
            @yield timeout(env, Millisecond(4000))
            @yield request(m.queue_Des1)
            @yield release(m.queue_Cha_PastaDes)
    end
#Des_end
        push!(m.queuetime_Des1, (nowDatetime(env),nowDatetime(env)-tin))
        push!(m.queuelength_Des1, (nowDatetime(env), length(m.queue_Des1.put_queue)))
        if Deschoice == 2
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Des"]),Min["Des"],Max["Des"])*10^3)))
        end
    tin = nowDatetime(env)
#Glas
    @yield request(m.queue_Glas1)
    @yield release(m.queue_Des1)
        push!(m.queuetime_Glas1, (nowDatetime(env),nowDatetime(env)-tin))
        push!(m.queuelength_Glas1, (nowDatetime(env), length(m.queue_Glas1.put_queue)))
        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Glas"]),Min["Glas"],Max["Glas"])*10^3)))
    tin = nowDatetime(env)
#Kassa
    @yield request(m.queue_Cash1)
    @yield release(m.queue_Glas1)
        @yield request(m.staff)
        push!(m.queuetime_Cash1, (nowDatetime(env),nowDatetime(env)-tin))
        push!(m.queuelength_Cash1, (nowDatetime(env), length(m.queue_Cash1.put_queue)))
        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Cash"]),Min["Cash"],Max["Cash"])*10^3)))
        @yield release(m.staff)
    @yield release(m.queue_Cash1)
end

function plotqueuelength(m::Mess)
    # some makeup
    tstart = floor(m.queuelength_Entrance[1][1], Day) + Hour(11) + Minute(30)
    tstop  = floor(m.queuelength_Entrance[1][1], Day) + Hour(13) + Minute(30)
    daterange =  tstart : Minute(60) : tstop
    datexticks = [Dates.value(mom) for mom in daterange]
    datexticklabels = Dates.format.(daterange,"HH:MM")
    # queue length
    x1::Array{DateTime,1} = map(v -> v[1], m.queuelength_Entrance)
    y1::Array{Int,1} = map(v -> v[2], m.queuelength_Entrance)
    p = plot(x1, y1, linetype=:steppost, label="Queue length Entrance")
    x2::Array{DateTime,1} = map(v -> v[1], m.queuelength_Utensils1)
    y2::Array{Int,1} = map(v -> v[2], m.queuelength_Utensils1)
    plot!(x2, y2, linetype=:steppost, label="Queue length Utensils 1")
    x3::Array{DateTime,1} = map(v -> v[1], m.queuelength_Main1)
    y3::Array{Int,1} = map(v -> v[2], m.queuelength_Main1)
    plot!(x3, y3, linetype=:steppost, label="Queue length Main 1")
    x4::Array{DateTime,1} = map(v -> v[1], m.queuelength_Side1)
    y4::Array{Int,1} = map(v -> v[2], m.queuelength_Side1)
    plot!(x4, y4, linetype=:steppost, label="Queue length Side 1")
    x5::Array{DateTime,1} = map(v -> v[1], m.queuelength_Des1)
    y5::Array{Int,1} = map(v -> v[2], m.queuelength_Des1)
    plot!(x5, y5, linetype=:steppost, label="Queue length Des 1")
    x6::Array{DateTime,1} = map(v -> v[1], m.queuelength_Cash1)
    y6::Array{Int,1} = map(v -> v[2], m.queuelength_Cash1)
    plot!(x6, y6, linetype=:steppost, label="Queue length Cash 1")

    xticks!(datexticks, datexticklabels,rotation=0)
    xlims!(Dates.value(tstart),Dates.value(tstop))
    ylims!(0,maximum([y2;y3;y4;y5;y6])+5)
    yticks!(0:1:(maximum([y2;y3;y4;y5;y6]))+1)
    

    savefig(p, "./Mess_Images/queuelength.png")
end

function plotqueuetime(m::Mess)
    # some makeup
    tstart = floor(m.queuetime_Entrance[1][1], Day) + Hour(11) + Minute(30)
    tstop  = floor(m.queuetime_Entrance[1][1], Day) + Hour(13) + Minute(30)
    daterange =  tstart : Minute(60) : tstop
    datexticks = [Dates.value(mom) for mom in daterange]
    datexticklabels = Dates.format.(daterange,"HH:MM")
    # queue time
    x1::Array{DateTime,1} = map(v -> v[1], m.queuetime_Entrance)
    y1::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Entrance)
    p = plot(x1, y1/1000, linetype=:steppost, label="Queue time Entrance")
    x2::Array{DateTime,1} = map(v -> v[1], m.queuetime_Utensils1)
    y2::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Utensils1)
    plot!(x2, y2/1000, linetype=:steppost, label="Queue time Utensils 1")
    x3::Array{DateTime,1} = map(v -> v[1], m.queuetime_Main1)
    y3::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Main1)
    plot!(x3, y3/1000, linetype=:steppost, label="Queue time Main 1")
    x4::Array{DateTime,1} = map(v -> v[1], m.queuetime_Side1)
    y4::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Side1)
    plot!(x4, y4/1000, linetype=:steppost, label="Queue time Side 1")
    x5::Array{DateTime,1} = map(v -> v[1], m.queuetime_Des1)
    y5::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Des1)
    plot!(x5, y5/1000, linetype=:steppost, label="Queue time Des 1")
    x6::Array{DateTime,1} = map(v -> v[1], m.queuetime_Cash1)
    y6::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Cash1)
    plot!(x6, y6/1000, linetype=:steppost, label="Queue time Cash 1")

    xticks!(datexticks, datexticklabels,rotation=0)
    xlims!(Dates.value(tstart),Dates.value(tstop))
    ylims!(0,maximum([y2;y3;y4;y5;y6])/1000+5)
    yticks!(0:1:(maximum([y2;y3;y4;y5;y6]))/1000+1)
    

    savefig(p, "./Mess_Images/queuetime.png")
end

function runsim()
    @info "$("-"^20)\nStarting a complete simulation\n$("-"^20)"
    sim = Simulation(floor(Dates.now(),Day))
    m = Mess(sim, 3)
    @process clientgenerator(sim, m)
    # Run the sim for one day
    run(sim, floor(Dates.now(),Day) + Day(1))
    # Illustrations
    @info "Making queue length figure"
    plotqueuelength(m)
    @info "Making queue time figure"
    plotqueuetime(m)
end

runsim()

function multisim(;n::Int=100, staff::Int=6,
    tstart::DateTime=floor(now(),Day), 
    duration::Period=Day(1))
    @info "<multisim>: Running a multisim of $(n) days on $(Threads.nthreads()) threads"

    tstart_data = floor(now(),Day) + Hour(11) + Minute(30);
    tstop_data  = floor(now(),Day) + Hour(14);
    daterange =  tstart_data : Minute(1) : tstop_data;
    L = length(daterange);
    datexticks = [Dates.value(mom) for mom in daterange];
    datexticklabels = Dates.format.(daterange,"HH:MM");
    TotWTpmn = zeros(6,L); TotElpmn = zeros(6,L); MWT = zeros(6,L);
    x1 = Array{DateTime,1}();x2 = Array{DateTime,1}();x3 = Array{DateTime,1}();x4 = Array{DateTime,1}();x5 = Array{DateTime,1}();x6 = Array{DateTime,1}()
    y1 = Array{Int64,1}();y2 = Array{Int64,1}();y3 = Array{Int64,1}();y4 = Array{Int64,1}();y5 = Array{Int64,1}();y6 = Array{Int64,1}()

    # run all simulations (in parallel where available)
    for _ = 1:n
        sim = Simulation(tstart)
        m = Mess(sim, staff)
        @process clientgenerator(sim,m)
        run(sim, tstart + duration)
            # queue time
            x1::Array{DateTime,1} = map(v -> v[1], m.queuetime_Entrance)
            y1::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Entrance)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x1) 
                        if Dates.value(Hour(x1[iter])) == hr && Dates.value(Minute(x1[iter])) == mn
                            TotWTpmn[1,index] += y1[iter]
                            TotElpmn[1,index] += 1
                        end
                    end
                end
            end
            x2::Array{DateTime,1} = map(v -> v[1], m.queuetime_Utensils1)
            y2::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Utensils1)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x2) 
                        if Dates.value(Hour(x2[iter])) == hr && Dates.value(Minute(x2[iter])) == mn
                            TotWTpmn[2,index] += y1[iter]
                            TotElpmn[2,index] += 1
                        end
                    end
                end
            end
            x3::Array{DateTime,1} = map(v -> v[1], m.queuetime_Main1)
            y3::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Main1)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x3) 
                        if Dates.value(Hour(x3[iter])) == hr && Dates.value(Minute(x3[iter])) == mn
                            TotWTpmn[3,index] += y1[iter]
                            TotElpmn[3,index] += 1
                        end
                    end
                end
            end
            x4::Array{DateTime,1} = map(v -> v[1], m.queuetime_Side1)
            y4::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Side1)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x4) 
                        if Dates.value(Hour(x4[iter])) == hr && Dates.value(Minute(x4[iter])) == mn
                            TotWTpmn[4,index] += y1[iter]
                            TotElpmn[4,index] += 1
                        end
                    end
                end
            end
            x5::Array{DateTime,1} = map(v -> v[1], m.queuetime_Des1)
            y5::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Des1)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x5) 
                        if Dates.value(Hour(x5[iter])) == hr && Dates.value(Minute(x5[iter])) == mn
                            TotWTpmn[5,index] += y1[iter]
                            TotElpmn[5,index] += 1
                        end
                    end
                end
            end
            x6::Array{DateTime,1} = map(v -> v[1], m.queuetime_Cash1)
            y6::Array{Int64,1} = map(v -> Dates.value(v[2]), m.queuetime_Cash1)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30dus komen de lengtes overeen
                    for iter = 1:length(x6) 
                        if Dates.value(Hour(x6[iter])) == hr && Dates.value(Minute(x6[iter])) == mn
                            TotWTpmn[6,index] += y1[iter]
                            TotElpmn[6,index] += 1
                        end
                    end
                end
            end
    end

    MWT = TotWTpmn./TotElpmn

    # generate a nice illustration
    @info "Making Mean Waiting Time figure"
    p = plot(daterange, MWT[1,:]/1000, linetype=:steppost, label="MWT_Entrance")
        plot!(daterange, MWT[2,:]/1000, linetype=:steppost, label="MWT_Utensils 1")
        plot!(daterange, MWT[3,:]/1000, linetype=:steppost, label="MWT_Main 1")
        plot!(daterange, MWT[4,:]/1000, linetype=:steppost, label="MWT_Side 1")
        plot!(daterange, MWT[5,:]/1000, linetype=:steppost, label="MWT_Des 1")
        plot!(daterange, MWT[6,:]/1000, linetype=:steppost, label="MWT_Cash 1")

        xticks!(datexticks, datexticklabels,rotation=0)
        xlims!(Dates.value(tstart_data),Dates.value(tstop_data))
        ylims!(0,maximum([y2;y3;y4;y5;y6])/1000+5)
        yticks!(0:1:(maximum([y2;y3;y4;y5;y6]))/1000+1)
        
        savefig(p,"./Mess_Images/MWT.png")
end

multisim()