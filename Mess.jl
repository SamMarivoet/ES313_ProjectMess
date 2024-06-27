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

#Parameters for simulation
    const Kaasprob = 6/35           #kans op moeten rondlopen voor kaas
    const LRprob = [0.5 0.5 0.5 0.5]    #kans op L(=1) @ Utensils Side Cash Pasta
    const Des12prob = Distributions.Categorical([0.5, 0.5])
#Constants
    const arrivals = Dict("[1130-1200[" => Distributions.Exponential(30),
                        "[1200-1230[" => Distributions.Exponential(20),
                        "[1230-1300[" => Distributions.Exponential(5),
                        "[1300-1330[" => Distributions.Exponential(10))
    const Use = Dict("Utensils" => Distributions.Normal(5.9,2.1),
                    "Main" => Distributions.Gamma(8.83,0.92),
                    "Side_veg" => Distributions.Gamma(7.86,0.86),
                    "Side_carbs1" => Distributions.Gamma(18.29,0.37), #(26/59)
                    "Side_carbs2" => Distributions.Gamma(42.89,0.29), #(33/59)
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
    const Carbsprob = 26/59
    const Choices = ["Main_Side_Des_Cash","Pasta_optDes"]
    const Choprob = Distributions.Categorical([0.8344, 0.1656])
    const Des12 = [1,2]                         #1→des @ utensils; 2→des @ glas
    const Desprob = 0.0925                      #kans op desert indien geen main
    const Paths = Dict(Choices[1]=>[1,1,1,0],   # path = (Main,Side,Des,Pasta)
                        Choices[2]=>[0,0,1,1])

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
        Q_Utensils1::Resource
        Q_Utensils2::Resource
        Q_Main1::Resource
        Q_Main2::Resource
        Q_Cha_Main1Side::Resource
        Q_Cha_Main2Side::Resource
        Q_Side1::Resource
        Q_Side2::Resource
        Q_Des1::Resource
        Q_Des2::Resource
        Q_Pasta1::Resource
        Q_Pasta2::Resource
        Q_Saus1::Resource
        Q_Saus2::Resource
        Q_Kaas1::Resource
        Q_Kaas2::Resource
        Q_Cha_PastaDes::Resource
        Q_Cha_SideDes1::Resource
        Q_Cha_SideDes2::Resource
        Q_Salad::Resource
        Q_Steak::Resource
        Q_Glas1::Resource
        Q_Glas2::Resource
        Q_Cash1::Resource
        Q_Cash2::Resource
    #queuelengths
        Qlength_Entrance::Array{Tuple{DateTime,Int64},1}
        Qlength_Utensils1::Array{Tuple{DateTime,Int64},1}
        Qlength_Utensils2::Array{Tuple{DateTime,Int64},1}
        Qlength_Main1::Array{Tuple{DateTime,Int64},1}
        Qlength_Main2::Array{Tuple{DateTime,Int64},1}
        Qlength_Side1::Array{Tuple{DateTime,Int64},1}
        Qlength_Side2::Array{Tuple{DateTime,Int64},1}
        Qlength_Des1::Array{Tuple{DateTime,Int64},1}
        Qlength_Des2::Array{Tuple{DateTime,Int64},1}
        Qlength_Pasta1::Array{Tuple{DateTime,Int64},1}
        Qlength_Pasta2::Array{Tuple{DateTime,Int64},1}
        Qlength_Saus1::Array{Tuple{DateTime,Int64},1}
        Qlength_Saus2::Array{Tuple{DateTime,Int64},1}
        Qlength_Kaas1::Array{Tuple{DateTime,Int64},1}
        Qlength_Kaas2::Array{Tuple{DateTime,Int64},1}
        Qlength_Salad::Array{Tuple{DateTime,Int64},1}
        Qlength_Steak::Array{Tuple{DateTime,Int64},1}
        Qlength_Glas1::Array{Tuple{DateTime,Int64},1}
        Qlength_Glas2::Array{Tuple{DateTime,Int64},1}
        Qlength_Cash1::Array{Tuple{DateTime,Int64},1}
        Qlength_Cash2::Array{Tuple{DateTime,Int64},1}
    #queuetimes (from requesting a place in a queue/service to getting it)
        Qtime_Entrance::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Utensils1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Utensils2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Main1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Main2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Side1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Side2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Des1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Des2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Pasta1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Pasta2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Saus1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Saus2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Kaas1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Kaas2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Salad::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Steak::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Glas1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Glas2::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Cash1::Array{Tuple{DateTime,Millisecond},1}
        Qtime_Cash2::Array{Tuple{DateTime,Millisecond},1}
    #clientcounter
        clientcounter::Int64
    function Mess(env::Environment, nstaff::Int=6; nkassa::Int=2)
        #add the crew
            staff = Resource(env,nstaff)
        #Containers
            Main1_1=Container(env,30,level=30)
            Main1_2=Container(env,30,level=30)
            Main1_3=Container(env,30,level=30)
            Main1_4=Container(env,30,level=30)
            Main2_1=Container(env,30,level=30)
            Main2_2=Container(env,30,level=30)
            Main2_3=Container(env,30,level=30)
            Main2_4=Container(env,30,level=30)
            Side1=Container(env,30,level=30)
            Side2=Container(env,30,level=30)
            Side3=Container(env,30,level=30)
            Side4=Container(env,30,level=0)
            Side5=Container(env,30,level=30)
            Side6=Container(env,30,level=30)
            Side7=Container(env,30,level=30)
            Side8=Container(env,30,level=30)
            Side9=Container(env,30,level=30)
            Side10=Container(env,30,level=30)
            Side11=Container(env,30,level=30)
            Side12=Container(env,30,level=30)
            Fries1=Container(env,15,level=15)
            Fries2=Container(env,15,level=15)
        #add queues
            Q_Utensils1 = Resource(env,3)
            Q_Utensils2 = Resource(env,3)
            Q_Main1 = Resource(env,4)
            Q_Main2 = Resource(env,4)
            Q_Cha_Main1Side = Resource(env,6)
            Q_Cha_Main2Side = Resource(env,9)
            Q_Side1 = Resource(env,8)
            Q_Side2 = Resource(env,8)
            Q_Des1 = Resource(env,2)
            Q_Des2 = Resource(env,2)
            Q_Pasta1 = Resource(env,2)
            Q_Pasta2 = Resource(env,2)
            Q_Saus1 = Resource(env,2)
            Q_Saus2 = Resource(env,2)
            Q_Kaas1 = Resource(env,2)
            Q_Kaas2 = Resource(env,2)
            Q_Cha_PastaDes = Resource(env,5)
            Q_Cha_SideDes1 = Resource(env,3)
            Q_Cha_SideDes2 = Resource(env,3)
            Q_Salad = Resource(env)
            Q_Steak = Resource(env)
            Q_Glas1 = Resource(env,4)
            Q_Glas2 = Resource(env,4)
            Q_Cash1 = Resource(env,nkassa-1)
            Q_Cash2 = Resource(env,1)
        #initiate queuelengths 
            Qlength_Entrance = [(nowDatetime(env),0)]
            Qlength_Utensils1 = [(nowDatetime(env),0)]
            Qlength_Utensils2 = [(nowDatetime(env),0)]
            Qlength_Main1 = [(nowDatetime(env),0)]
            Qlength_Main2 = [(nowDatetime(env),0)]
            Qlength_Side1 = [(nowDatetime(env),0)]
            Qlength_Side2 = [(nowDatetime(env),0)]
            Qlength_Des1 = [(nowDatetime(env),0)]
            Qlength_Des2 = [(nowDatetime(env),0)]
            Qlength_Pasta1 = [(nowDatetime(env),0)]
            Qlength_Pasta2 = [(nowDatetime(env),0)]
            Qlength_Saus1 = [(nowDatetime(env),0)]
            Qlength_Saus2 = [(nowDatetime(env),0)]
            Qlength_Kaas1 = [(nowDatetime(env),0)]
            Qlength_Kaas2 = [(nowDatetime(env),0)]
            Qlength_Salad = [(nowDatetime(env),0)]
            Qlength_Steak = [(nowDatetime(env),0)]
            Qlength_Glas1 = [(nowDatetime(env),0)]
            Qlength_Glas2 = [(nowDatetime(env),0)]
            Qlength_Cash1 = [(nowDatetime(env),0)]
            Qlength_Cash2 = [(nowDatetime(env),0)]              
        #initiate queuetimes
            Qtime_Entrance = [(nowDatetime(env),Millisecond(0))]
            Qtime_Utensils1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Utensils2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Main1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Main2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Side1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Side2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Des1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Des2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Pasta1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Pasta2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Saus1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Saus2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Kaas1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Kaas2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Salad = [(nowDatetime(env),Millisecond(0))]
            Qtime_Steak = [(nowDatetime(env),Millisecond(0))]
            Qtime_Glas1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Glas2 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Cash1 = [(nowDatetime(env),Millisecond(0))]
            Qtime_Cash2 = [(nowDatetime(env),Millisecond(0))]
        #clientcounter starts at 0
            clientcounter = 0                    
        return new(staff,
            Main1_1,Main1_2,Main1_3,Main1_4,Main2_1,Main2_2,Main2_3,Main2_4,Side1,Side2,Side3,Side4,Side5,Side6,Side7,Side8,Side9,Side10,Side11,Side12,Fries1,Fries2,
            Q_Utensils1,Q_Utensils2,Q_Main1,Q_Main2,Q_Cha_Main1Side,Q_Cha_Main2Side,Q_Side1,Q_Side2,Q_Des1,Q_Des2,Q_Pasta1,Q_Pasta2,Q_Saus1,Q_Saus2,Q_Kaas1,Q_Kaas2,Q_Cha_PastaDes,Q_Cha_SideDes1,Q_Cha_SideDes2,Q_Salad,Q_Steak,Q_Glas1,Q_Glas2,Q_Cash1,Q_Cash2,
            Qlength_Entrance,Qlength_Utensils1,Qlength_Utensils2,Qlength_Main1,Qlength_Main2,Qlength_Side1,Qlength_Side2,Qlength_Des1,Qlength_Des2,Qlength_Pasta1,Qlength_Pasta2,Qlength_Saus1,Qlength_Saus2,Qlength_Kaas1,Qlength_Kaas2,Qlength_Salad,Qlength_Steak,Qlength_Glas1,Qlength_Glas2,Qlength_Cash1,Qlength_Cash2,
            Qtime_Entrance,Qtime_Utensils1,Qtime_Utensils2,Qtime_Main1,Qtime_Main2,Qtime_Side1,Qtime_Side2,Qtime_Des1,Qtime_Des2,Qtime_Pasta1,Qtime_Pasta2,Qtime_Saus1,Qtime_Saus2,Qtime_Kaas1,Qtime_Kaas2,Qtime_Salad,Qtime_Steak,Qtime_Glas1,Qtime_Glas2,Qtime_Cash1,Qtime_Cash2,
            clientcounter)
    end
end

mutable struct Client
    kant::Int
    proc::Process
    mode::Int
    function Client(env::Environment,m::Mess; mode::Int=1)
        if mode < 0 || mode >2
            error("client mode should be 0,1 or 2")
        end
        client = new()
        client.mode = mode #0→LRProb 1→kortste 2→kortste+begeleiding
        client.kant = 1
        client.proc = @process clientbehavior(env, m, client)
        return client
    end
end

@resumable function clientgenerator(env::Environment, m::Mess; mode::Int=0, impuls::Int=80, clientmode::Int=1)
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
        @info "Simulation on impuls of $(impuls) clients on mode $(clientmode)"
        for _ = 1:impuls
            m.clientcounter += 1
            c = Client(env,m,mode=clientmode)
        end
    end
end

@resumable function clientbehavior(env::Environment, m::Mess, client::Client)
    #keuze
        choice = Choices[rand(Choprob)]
        path = Paths[choice]
        if choice == "Main_Side_Des_Cash"
            Deschoice = Des12[rand(Des12prob)]
        elseif rand() < Desprob
            Deschoice = 2
        else
            Deschoice = 0
        end
        tin = nowDatetime(env)
    #Utensils
        if (client.mode == 0 && rand()<LRprob[1]) || (client.mode >= 1 && length(m.Q_Utensils1.put_queue) <= length(m.Q_Utensils2.put_queue))
            @yield request(m.Q_Utensils1)
                push!(m.Qtime_Entrance, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Entrance, (nowDatetime(env), length(m.Q_Utensils1.put_queue)))
        else
            client.kant = 2
            @yield request(m.Q_Utensils2)
                push!(m.Qtime_Entrance, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Entrance, (nowDatetime(env), length(m.Q_Utensils1.put_queue)))
        end
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Utensils"]),Min["Utensils"],Max["Utensils"])*10^3))) #verdeling geeft resultaat in seconden dat wordt omgezet naar milliseconden
        tin = nowDatetime(env)
    #Main + Side + Des_start
        if path[1] == 1
        #Main    
            if client.kant == 1 
                @yield request(m.Q_Main1)
                    @yield release(m.Q_Utensils1)  
                    if Deschoice == 1
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Des"]),Min["Des"],Max["Des"])*10^3)))
                    end  
                    @yield request(m.staff)
                    push!(m.Qtime_Main1, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Main1, (nowDatetime(env), length(m.Q_Main1.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Main"]),Min["Main"],Max["Main"])*10^3)))
                    @yield release(m.staff)
                tin = nowDatetime(env)
                @yield request(m.Q_Cha_Main1Side)
                    @yield release(m.Q_Main1)
                    @yield timeout(env, Millisecond(3000))
            else   
                @yield request(m.Q_Main2)
                    @yield release(m.Q_Utensils2)  
                    if Deschoice == 1
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Des"]),Min["Des"],Max["Des"])*10^3)))
                    end  
                    @yield request(m.staff)
                    push!(m.Qtime_Main2, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Main2, (nowDatetime(env), length(m.Q_Main2.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Main"]),Min["Main"],Max["Main"])*10^3)))
                    @yield release(m.staff)
                tin = nowDatetime(env)
                @yield request(m.Q_Cha_Main2Side)
                    @yield release(m.Q_Main2)
                    @yield timeout(env, Millisecond(5000))
            end
        #Side
            if (client.mode == 0 && rand()<LRprob[2]) || (client.mode == 1 && length(m.Q_Side1.put_queue) <= length(m.Q_Side2.put_queue)) || (client.mode == 2 && client.kant == 1)
                @yield request(m.Q_Side1)
                if client.kant == 1
                    @yield release(m.Q_Cha_Main1Side)
                else
                    @yield release(m.Q_Cha_Main2Side)
                    client.kant = 1
                end
                    push!(m.Qtime_Side1, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Side1, (nowDatetime(env), length(m.Q_Side1.put_queue)))
            else
                @yield request(m.Q_Side2)
                if client.kant == 2
                    @yield release(m.Q_Cha_Main2Side)
                else
                    @yield release(m.Q_Cha_Main1Side)
                    client.kant = 2
                end
                    push!(m.Qtime_Side2, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Side2, (nowDatetime(env), length(m.Q_Side2.put_queue)))
            end
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Side_veg"]),Min["Side_veg"],Max["Side_veg"])*10^3)))
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Side_veg"]),Min["Side_veg"],Max["Side_veg"])*10^3)))
            if rand() < Carbsprob
                @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Side_carbs1"]),Min["Side_carbs"],Max["Side_carbs"])*10^3)))
            else
                @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Side_carbs2"]),Min["Side_carbs"],Max["Side_carbs"])*10^3)))
            end
        #Des_start
            tin = nowDatetime(env)
            if (client.mode == 0 && rand()<LRprob[3]) || (client.mode == 1 && length(m.Q_Des1.put_queue) <= length(m.Q_Des2.put_queue)) || (client.mode == 2 && client.kant == 1)
                @yield request(m.Q_Cha_SideDes1)
                if client.kant == 1
                    @yield release(m.Q_Side1)
                else
                    @yield release(m.Q_Side2)
                    client.kant = 1
                end
                    @yield timeout(env, Millisecond(2000))
                @yield request(m.Q_Des1)
                    @yield release(m.Q_Cha_SideDes1)
            elseif client.mode == 2 && client.kant == 2 && length(m.Q_Des1.put_queue) <= length(m.Q_Des2.put_queue)
                @yield request(m.Q_Cha_SideDes1)
                    @yield release(m.Q_Side2)
                    client.kant = 1
                    @yield timeout(env, Millisecond(2500))
                @yield request(m.Q_Des1)
                    @yield release(m.Q_Cha_SideDes1)
            else
                @yield request(m.Q_Cha_SideDes2)
                if client.kant == 2
                    @yield release(m.Q_Side2)
                else
                    @yield release(m.Q_Side1)
                    client.kant = 2
                end
                    @yield timeout(env, Millisecond(2000))
                @yield request(m.Q_Des2)
                    @yield release(m.Q_Cha_SideDes2) 
            end
    #Pasta + Des_start
        elseif path[4] == 1
            if client.kant == 1
                @yield release(m.Q_Utensils1)
            else 
                @yield release(m.Q_Utensils2)
            end
        #Pasta + Saus + Kaas
            if (client.mode == 0 && rand()<LRprob[4]) || (client.mode == 1 && length(m.Q_Pasta1.put_queue) <= length(m.Q_Des2.put_queue)) || (client.mode == 2 && client.kant == 1)
                @yield request(m.Q_Pasta1)
                    push!(m.Qtime_Pasta1, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Pasta1, (nowDatetime(env), length(m.Q_Pasta1.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Pasta"]),Min["Pasta"],Max["Pasta"])*10^3)))
                tin = nowDatetime(env)
                @yield request(m.Q_Saus1)
                    @yield release(m.Q_Pasta1)    
                    push!(m.Qtime_Saus1, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Saus1, (nowDatetime(env), length(m.Q_Saus1.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Saus"]),Min["Saus"],Max["Saus"])*10^3)))
                tin = nowDatetime(env)
                @yield request(m.Q_Kaas1)
                    @yield release(m.Q_Saus1)
                    push!(m.Qtime_Kaas1, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Kaas1, (nowDatetime(env), length(m.Q_Kaas1.put_queue)))
                    if rand() > Kaasprob
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Kaas1"]),Min["Kaas1"],Max["Kaas1"])*10^3)))
                    else
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Kaas2"]),Min["Kaas2"],Max["Kaas2"])*10^3)))
                    end
                tin = nowDatetime(env)
                @yield request(m.Q_Cha_PastaDes)
                    @yield release(m.Q_Kaas1)
            else
                @yield request(m.Q_Pasta2)
                    push!(m.Qtime_Pasta2, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Pasta2, (nowDatetime(env), length(m.Q_Pasta2.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Pasta"]),Min["Pasta"],Max["Pasta"])*10^3)))
                tin = nowDatetime(env)
                @yield request(m.Q_Saus2)
                    @yield release(m.Q_Pasta2)    
                    push!(m.Qtime_Saus2, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Saus2, (nowDatetime(env), length(m.Q_Saus2.put_queue)))
                    @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Saus"]),Min["Saus"],Max["Saus"])*10^3)))
                tin = nowDatetime(env)
                @yield request(m.Q_Kaas2)
                    @yield release(m.Q_Saus2)
                    push!(m.Qtime_Kaas2, (nowDatetime(env),nowDatetime(env)-tin))
                    push!(m.Qlength_Kaas2, (nowDatetime(env), length(m.Q_Kaas2.put_queue)))
                    if rand() > Kaasprob
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Kaas1"]),Min["Kaas1"],Max["Kaas1"])*10^3)))
                    else
                        @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Kaas2"]),Min["Kaas2"],Max["Kaas2"])*10^3)))
                    end
                tin = nowDatetime(env)
                @yield request(m.Q_Cha_PastaDes)
                    @yield release(m.Q_Kaas2)
            end
                @yield timeout(env, Millisecond(4000))
        #Des_start
            if (client.mode == 0 && rand()<LRprob[3]) || (client.mode == 1 && length(m.Q_Des1.put_queue) <= length(m.Q_Des2.put_queue))
                @yield request(m.Q_Cha_SideDes1)
                    client.kant = 1
                    @yield release(m.Q_Cha_PastaDes)
                    @yield timeout(env, Millisecond(2000))
                @yield request(m.Q_Des1)
                    @yield release(m.Q_Cha_SideDes1)
            else
                @yield request(m.Q_Cha_SideDes2)
                    client.kant = 2
                    @yield release(m.Q_Cha_PastaDes)
                    @yield timeout(env, Millisecond(2000))
                @yield request(m.Q_Des2)
                    @yield release(m.Q_Cha_SideDes2) 
            end
        end
    #Des_end
        if client.kant == 1
            push!(m.Qtime_Des1, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.Qlength_Des1, (nowDatetime(env), length(m.Q_Des1.put_queue)))
        else
            push!(m.Qtime_Des2, (nowDatetime(env),nowDatetime(env)-tin))
            push!(m.Qlength_Des2, (nowDatetime(env), length(m.Q_Des2.put_queue)))
        end
        if Deschoice == 2
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Des"]),Min["Des"],Max["Des"])*10^3)))
        end
        tin = nowDatetime(env)
    #Glas
        if client.kant == 1
            @yield request(m.Q_Glas1)
                @yield release(m.Q_Des1)
                push!(m.Qtime_Glas1, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Glas1, (nowDatetime(env), length(m.Q_Glas1.put_queue)))
        else
            @yield request(m.Q_Glas2)
                @yield release(m.Q_Des2)
                push!(m.Qtime_Glas2, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Glas2, (nowDatetime(env), length(m.Q_Glas2.put_queue)))
        end
            @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Glas"]),Min["Glas"],Max["Glas"])*10^3)))
        tin = nowDatetime(env)
    #Kassa
        if client.kant == 1
            @yield request(m.Q_Cash1)
                @yield release(m.Q_Glas1)
                @yield request(m.staff)
                push!(m.Qtime_Cash1, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Cash1, (nowDatetime(env), length(m.Q_Cash1.put_queue)))
                @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Cash"]),Min["Cash"],Max["Cash"])*10^3)))
                @yield release(m.staff)
                @yield release(m.Q_Cash1)
        else
            @yield request(m.Q_Cash2)
                @yield release(m.Q_Glas2)
                @yield request(m.staff)
                push!(m.Qtime_Cash2, (nowDatetime(env),nowDatetime(env)-tin))
                push!(m.Qlength_Cash2, (nowDatetime(env), length(m.Q_Cash2.put_queue)))
                @yield timeout(env, Millisecond(round(Int64,clamp(rand(Use["Cash"]),Min["Cash"],Max["Cash"])*10^3)))
                @yield release(m.staff)
                @yield release(m.Q_Cash2)
        end
end

function plotQL(Qdat::Vector{Tuple{DateTime,Int}}, label::String)
    x = map(v -> v[1], Qdat)
    y = map(v -> v[2], Qdat)
    plot!(x, y, linestyle=:solid, label=label)
end

function format_datetime_to_mmss(dt::DateTime)
    return Dates.format(dt, "MM:SS")
end

function plotQlength(m::Mess)
    p = plot()

    plotQL(m.Qlength_Entrance, "Queue length Entrance")
    plotQL(m.Qlength_Utensils1, "Queue length Utensils 1")
    plotQL(m.Qlength_Main1, "Queue length Main 1")
    plotQL(m.Qlength_Side1, "Queue length Side 1")
    plotQL(m.Qlength_Des1, "Queue length Des 1")
    plotQL(m.Qlength_Cash1, "Queue length Cash 1")

    current_xticks = xticks(p)[1][1]
    x_ticks_datetime = [Dates.unix2datetime(Int(round(x/1000))) for x in current_xticks]
    formatted_xticks = [format_datetime_to_mmss(x_ticks_datetime[i]) for i in 1:length(current_xticks)]
    xticks!(p, current_xticks, formatted_xticks)
    xlabel!(p, "Time of the simulation in MM:SS")
    ylabel!(p, "Length of the queue in # clients")

    savefig(p, "./Mess_Images/queuelength.png")
end

function plotQT(Qdat::Vector{Tuple{DateTime,Millisecond}}, label::String)
    x = map(v -> v[1], Qdat)
    y = map(v -> v[2]/Second(1), Qdat)
    plot!(x, y, linestyle=:solid, label=label, legend=:right)
end

function plotQtime(m::Mess)
    p = plot(size=(800,400),margin=5Plots.mm)

    plotQT(m.Qtime_Entrance, "Queue time Entrance")
    plotQT(m.Qtime_Utensils1, "Queue time Utensils 1")
    plotQT(m.Qtime_Main1, "Queue time Main 1")
    plotQT(m.Qtime_Side1, "Queue time Side 1")
    plotQT(m.Qtime_Des1, "Queue time Des 1")
    plotQT(m.Qtime_Cash1, "Queue time Cash 1")

    current_xticks = xticks(p)[1][1]
    x_ticks_datetime = [Dates.unix2datetime(Int(round(x/1000))) for x in current_xticks]
    formatted_xticks = [format_datetime_to_mmss(x_ticks_datetime[i]) for i in 1:length(current_xticks)]
    xticks!(p, current_xticks, formatted_xticks)
    xlabel!(p, "Time of the simulation in MM:SS")
    ylabel!(p, "Queue time in seconds")
    plot!(p, legend=:outerright)

    savefig(p, "./Mess_Images/queuetime.png")
end

function runsim(;nstaff::Int=6,nkassa::Int=2,genmode::Int=1,clientmode::Int=1)
    @info "$("-"^20)\nStarting a complete simulation\n$("-"^26)"
    sim = Simulation(floor(Dates.now(),Day))
    m = Mess(sim, nstaff, nkassa=nkassa)
    @process clientgenerator(sim, m, mode=genmode, clientmode = clientmode)
    # Run the sim for one day
    run(sim, floor(Dates.now(),Day) + Day(1))
    # Illustrations
    @info "Making queue length figure"
    plotQlength(m)
    @info "Making queue time figure"
    plotQtime(m)
end

runsim(nkassa=3)

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
            x1::Array{DateTime,1} = map(v -> v[1], m.Qtime_Entrance)
            y1::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Entrance)
            for hr = 11:13
                for mn = 0:59
                    index = (hr-11)*60 + mn-30 + 1 #geen data voor 11:30 of na 13:30 dus komen de lengtes overeen
                    for iter = 1:length(x1) 
                        if Dates.value(Hour(x1[iter])) == hr && Dates.value(Minute(x1[iter])) == mn
                            TotWTpmn[1,index] += y1[iter]
                            TotElpmn[1,index] += 1
                        end
                    end
                end
            end
            x2::Array{DateTime,1} = map(v -> v[1], m.Qtime_Utensils1)
            y2::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Utensils1)
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
            x3::Array{DateTime,1} = map(v -> v[1], m.Qtime_Main1)
            y3::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Main1)
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
            x4::Array{DateTime,1} = map(v -> v[1], m.Qtime_Side1)
            y4::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Side1)
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
            x5::Array{DateTime,1} = map(v -> v[1], m.Qtime_Des1)
            y5::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Des1)
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
            x6::Array{DateTime,1} = map(v -> v[1], m.Qtime_Cash1)
            y6::Array{Int64,1} = map(v -> Dates.value(v[2]), m.Qtime_Cash1)
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
    p = plot(daterange, MWT[1,:]/1000, linestyle=:solid, label="MWT_Entrance")
        plot!(daterange, MWT[2,:]/1000, linestyle=:solid, label="MWT_Utensils 1")
        plot!(daterange, MWT[3,:]/1000, linestyle=:solid, label="MWT_Main 1")
        plot!(daterange, MWT[4,:]/1000, linestyle=:solid, label="MWT_Side 1")
        plot!(daterange, MWT[5,:]/1000, linestyle=:solid, label="MWT_Des 1")
        plot!(daterange, MWT[6,:]/1000, linestyle=:solid, label="MWT_Cash 1")

        xticks!(datexticks, datexticklabels,rotation=0)
        xlims!(Dates.value(tstart_data),Dates.value(tstop_data))
        ylims!(0,maximum([y2;y3;y4;y5;y6])/1000+5)
        yticks!(0:1:(maximum([y2;y3;y4;y5;y6]))/1000+1)
        
        savefig(p,"./Mess_Images/MWT.png")
end

#multisim()