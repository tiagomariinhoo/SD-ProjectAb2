using Distributed

addprocs(3)

#Declarations, workloads, leader and currentWorkerElection
#The currentWorkerElection is false because in the beginning
#no worker is participating in the election
#the leader begins with nrpocs (4 in this case)
@everywhere begin
    workloads = fill(0.0, nprocs()) 
    leader = nprocs()
    currentWorkerElection = false
end

#Updates workloads value in worker with id "idx"
@everywhere function setValue(idx, cont)
    global workloads[idx] = cont
end

#Calculates next worker's id
#If CurrentIdx == nprocs (4), idx is 2 (next worker)
@everywhere function nextCalc(currentIdx)
    if(currentIdx == nprocs()) 
        return 2
    end
    return currentIdx+1
end

#If currentWorkerElection is true, updates leader to currentLeader
#and currentWorkerElection to false
#All workers are set to false to indicate that the election is over
@everywhere function changeLeader(currentLeader)
    if(currentWorkerElection == true)
        global currentWorkerElection = false
        global leader = currentLeader
    end
end

#If currentWorkerElection is true, updates leader to
#currentLeader and currentWorkerElection to false
#Updates the leader value in each worker
@everywhere function endElection(currentLeader)
    for i in workers()
        @spawnat i changeLeader(currentLeader)
    end
end

#Run the ring-based election algorithm
#currentIdx -> Former worker Id
#currentWorkload -> The lowest workload so far (from the leader)
#currentLeader -> Leader Id so far
@everywhere function election(currentIdx, currentWorkload, currentLeader)

    next = nextCalc(currentIdx)

    global currentWorkerElection = true
    
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

#Check if another election is already happening and
#check if the condition is met to run the election
@everywhere function checkWorkload(idx, currentWorkload)

    #If an election is already taking place, the function ends
    #This is becaus if an election has already taken place
    #All currentWorkerElection are set to false (endElection -> changeLeader) 
    for i in workers()
        if(@fetchfrom i currentWorkerElection == true) return 0
        end
    end

    #Condition to run the election
    if(workloads[leader] >= 0.8 && workloads[idx] < 0.8 && currentWorkerElection == false)
        global next = nextCalc(idx)
        global currentWorkerElection = true
        @spawnat next election(next, currentWorkload, idx)
    end
end

#Function to form the output string
@everywhere function printWorkloads(id, workloadsAux)

    ans = string("Workload from Worker ", id, ": ");
    ans *= string("[")

    for i in 2:nprocs()
            ans *= string(workloadsAux[i])

        if(i <= nworkers()) 
            ans *= string(", ")
        end
    end
    ans *= string("]")

    return ans
end

#Function "main", where are generated the new values
#for each worker, called the function of setting the values
#and print function
@everywhere function main()

    idCur = myid()
    while true
        cont = round(rand(), digits = 1)

        for i in workers()
            @spawnat i setValue(idCur, cont)
        end
        sleep(2)

        remotecall(println, 1, printWorkloads(idCur, workloads))
        checkWorkload(idCur, workloads[idCur]);
    end
end

println("Leader: ", nprocs())

#running the function main in each worker
for i in workers()
    @spawnat i main()
end
