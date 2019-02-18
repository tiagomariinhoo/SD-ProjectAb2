using Distributed

addprocs(3)

@everywhere begin
    workloads = fill(0.0, nprocs() + 1) 
    global leader = nprocs()
    currentNodeElection = false
end

@everywhere function setValue(idx, cont)
    global workloads[idx] = cont
end

@everywhere function nextCalc(currentIdx)
    if(currentIdx == nprocs()) 
        return 2
    end
    return currentIdx+1
end

@everywhere function changeLeader(currentLeader)
    if(currentNodeElection == true)
        global currentNodeElection = false
        global leader = currentLeader
    end
end

@everywhere function endElection(currentLeader)
    for i in workers()
        @spawnat i changeLeader(currentLeader)
    end
end

@everywhere function election(currentIdx, currentWorkload, currentLeader)
    
    next = nextCalc(currentIdx)
    global currentNodeElection = true
    if currentIdx != currentLeader
        if workloads[currentIdx] < currentWorkload
            @spawnat next election(next, workloads[currentIdx], currentIdx)
        elseif workloads[currentIdx] == currentWorkload && currentIdx > currentLeader
            @spawnat next election(next, currentWorkload, currentIdx)
        else
            @spawnat next election(next, currentWorkload, currentLeader)
        end
    elseif currentIdx == currentLeader
        @spawnat 1 println("New leader elected! Worker ", currentIdx)

        endElection(currentIdx)
    end
end

@everywhere function checkWorkload(idx, currentWorkload)

    for i in workers()
        if(@fetchfrom i currentNodeElection == true) return 0
        end
    end

    if(workloads[leader] >= 0.8 && workloads[idx] < 0.8 && currentNodeElection == false)
        global next = nextCalc(idx)
        global currentNodeElection = true
        @spawnat next election(next, currentWorkload, idx)
    end
end

@everywhere function printWorkloads(idAtual, workloadsAux)

    ans = string("Workload from Worker ", idAtual, ": ");
    ans *= string("[")

    for i in 2:nprocs()
        if(i == leader) 
            ans *= string("{ ", workloadsAux[i], " }")
        else 
            ans *= string(workloadsAux[i])
        end

        if(i <= nworkers()) 
            ans *= string(", ")
        end
    end
    ans *= string("]")

    return ans
end

@everywhere function main()

    idAtual = myid()
    while true
        atual = round(rand(), digits = 1)

        for i in workers()
            @spawnat i setValue(idAtual, atual)
        end
        sleep(2)

        remotecall(println, 1, printWorkloads(idAtual, workloads))
        checkWorkload(idAtual, workloads[idAtual]);
    end
end

#workers porque não inclue o pid 1
for i in workers()
    @spawnat i main()
end
