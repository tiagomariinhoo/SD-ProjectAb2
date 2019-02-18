using Distributed

addprocs(3)

@everywhere begin
    workloads = fill(0.0, nprocs() + 1) 
    master = nprocs() + 1
    leader = nprocs()
    currentNodeElection = 0
    flag = 0
end

@everywhere function setValue(idx, cont)
    workloads[idx] = cont
end

@everywhere function nextCalc(currentIdx)
    atual = (currentIdx + 1)%(nprocs() + 1)
    if(atual <= 1)
        return 2
    end
    return atual
end

@everywhere function election(currentIdx, currentWorkload, currentLeader)
    if currentIdx != currentNodeElection
        flag = 1

        if workload[currentIdx]
        end
    elseif currentIdx == currentNodeElection && flag == 1
        leader = currentNodeElection
        return 0
    end
end

@everywhere function checkWorkload(idx, currentWorkload)
    if(workloads[leader] >= 0.8 && workloads[idx] < 0.8)
        global currentNodeElection = idx
        global flag = 0
        election(idx, currentWorkload, 0)
    end
end

@everywhere function main()

    idAtual = myid()
    while true
        atual = round(rand(), digits = 1)
        #checkWorkload(idAtual)
        for i in workers()
            @spawnat i setValue(idAtual, atual)
        end
        sleep(2)
        @spawnat 1 println("Workload from Worker ", idAtual, ": ", workloads[2:nprocs()])
        checkWorkload(idAtual, workloads[idAtual]);
    end
end

#workers porque não inclue o pid 1
for i in workers()
    @spawnat i main()
end
