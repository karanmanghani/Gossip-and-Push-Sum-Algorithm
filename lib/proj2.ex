defmodule Project do
  use GenServer

  def start(data) do
    n = Enum.at(data, 0)
    inp = n
    topology = Enum.at(data, 1)
    algorithm = Enum.at(data, 2)
    starttime = System.monotonic_time(:millisecond)
    # STEP 1: INITIALIZATIONL Change the input number of nodes based on the topology
    #change number of nodes based on the algorithm. For HC, randomHC we bring it to nearest odd lined HC
    n =
      cond do
        topology == "honeycomb" || topology == "randhoneycomb" ->
          n = round(:math.ceil(:math.pow(n, 1 / 2)))

          n =
            cond do
              rem(n, 2) != 0 ->
                n + 1

              true ->
                n
            end
          n * n + n
        true ->
          n
    end
    #create registry for storing processes and ets table for storing the spread value. 
    # Spread is a parameter we use to know how many of the given input nodes have received the message
    Registry.start_link(name: :my_registry, keys: :unique)
    _table = :ets.new(:table, [:named_table, :public])
    :ets.insert(:table, {:spreadvalue, 0})

	#We call the startnodes() to iteratively spawn processes and store them in our registry 
    Enum.map(1..n, fn x ->
      pid = startnodes([0, [], "", 0.0, 0.0, x, 1, x, 1, x, 1])
      {:ok, _} = Registry.register(:my_registry, "worker#{x}", pid)
    end)
    #The state contains the following values: count, neighbors, message, x,y cordinates, 3 S,W pairs for pushsum
    #Since we're using worker values, we make that the key and pid the value
    # plist is the list of pids spawned , wlist is list of workers associated with that pid
    wlist = Registry.select(:my_registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    _plist = Registry.select(:my_registry, [{{:_, :_, :"$2"}, [], [:"$2"]}])
    # Enum.each(wlist, fn x-> IO.inspect(getState(x)) end)

    # Establish neigbors of a process
    cond do
      topology == "full" -> #Every node has every node as its neighbor other than itself
        Enum.each(wlist, fn x -> updateNeighbors(x, List.delete(wlist, x)) end)

      topology == "line" -> #Every node has 2 neighbors (Left and right) except first and last node
        Enum.each(1..n, fn x ->
          neighbour =
            cond do
              x == 1 ->
                ["worker" <> Integer.to_string(x + 1)]

              x == n ->
                ["worker" <> Integer.to_string(x - 1)]

              true ->
                ["worker" <> Integer.to_string(x - 1), "worker" <> Integer.to_string(x + 1)]
            end

          updateNeighbors("worker" <> Integer.to_string(x), neighbour)
        end)

      topology == "rand2D" ->
        Enum.each(wlist, fn x ->         #For each element, create a random x, y coordinate
          xcord = :rand.uniform()
          ycord = :rand.uniform()
          GenServer.cast(getpid(x), {:updatecoords, xcord, ycord})
          # IO.inspect getState(x)
        end)
        Enum.each(wlist, fn x ->
          _dneighbors = []
          ourx = Enum.at(getState(x), 3)
          oury = Enum.at(getState(x), 4)
          	# Find its neighbors using Euclidean Distance Formula
          dneighbors =
            Enum.map(List.delete(wlist, x), fn y ->
              testx = Enum.at(getState(y), 3)
              testy = Enum.at(getState(y), 4)
              d = :math.sqrt(:math.pow(testx - ourx, 2) + :math.pow(testy - oury, 2))

              if d <= 0.1 do
                y
              end
            end)
            |> Enum.filter(&(&1 != nil))


          updateNeighbors(x, dneighbors)
        end)

      topology == "honeycomb" -> #Every node has at max 3 neighbors in a hexagon-like topology
        w = round(:math.ceil(:math.pow(inp, 1 / 2)))

        w =
          cond do
            rem(w, 2) != 0 ->
              w + 1

            true ->
              w
          end

        for i <- 0..w do
          for j <- (i * w + 1)..(w * (i + 1)) do
            list = []

            cond do
              (j == 1 || j == w) && i == 0 ->
                list = ["worker#{j + w}" | list]
                updateNeighbors("worker#{j}", list)

              i == 0 ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j + w}" | ["worker#{j + 1}" | list]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - 1}" | list]]
                    updateNeighbors("worker#{j}", list)
                end

              i == w && (j == i * w + 1 || j == w * (i + 1)) ->
                list = ["worker#{j - w}" | list]
                updateNeighbors("worker#{j}", list)

              i == w ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j - w}" | ["worker#{j + 1}" | list]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j - w}" | ["worker#{j - 1}" | list]]
                    updateNeighbors("worker#{j}", list)
                end

              rem(i, 2) != 0 ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j - 1}" | list]]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j + 1}" | list]]]
                    updateNeighbors("worker#{j}", list)
                end

              rem(i, 2) == 0 ->
                cond do
                  j == i * w + 1 || j == w * (i + 1) ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | list]]
                    updateNeighbors("worker#{j}", list)

                  rem(j, 2) != 0 ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j - 1}" | list]]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j + 1}" | list]]]
                    updateNeighbors("worker#{j}", list)
                end
            end
          end
        end
        #randhc is same as hc with an extra random neighbor added to the list
      topology == "randhoneycomb" ->
        w = round(:math.ceil(:math.pow(inp, 1 / 2)))

        w =
          cond do
            rem(w, 2) != 0 ->
              w + 1

            true ->
              w
          end

        for i <- 0..w do
          for j <- (i * w + 1)..(w * (i + 1)) do
            list = []
            list = [Enum.random(wlist) | list]

            cond do
              (j == 1 || j == w) && i == 0 ->
                list = ["worker#{j + w}" | list]
                updateNeighbors("worker#{j}", list)

              i == 0 ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j + w}" | ["worker#{j + 1}" | list]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - 1}" | list]]
                    updateNeighbors("worker#{j}", list)
                end

              i == w && (j == i * w + 1 || j == w * (i + 1)) ->
                list = ["worker#{j - w}" | list]
                updateNeighbors("worker#{j}", list)

              i == w ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j - w}" | ["worker#{j + 1}" | list]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j - w}" | ["worker#{j - 1}" | list]]
                    updateNeighbors("worker#{j}", list)
                end

              rem(i, 2) != 0 ->
                cond do
                  rem(j, 2) == 0 ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j - 1}" | list]]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j + 1}" | list]]]
                    updateNeighbors("worker#{j}", list)
                end

              rem(i, 2) == 0 ->
                cond do
                  j == i * w + 1 || j == w * (i + 1) ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | list]]
                    updateNeighbors("worker#{j}", list)

                  rem(j, 2) != 0 ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j - 1}" | list]]]
                    updateNeighbors("worker#{j}", list)

                  true ->
                    list = ["worker#{j + w}" | ["worker#{j - w}" | ["worker#{j + 1}" | list]]]
                    updateNeighbors("worker#{j}", list)
                end
            end
          end
        end
    end
    #select a startnode from the list of workers
    startnode = Enum.random(wlist)

    if algorithm == "gossip" do
      GenServer.cast(getpid(startnode), {:sendmessageto, "Hi", startnode, wlist}) #give the message to the startnode
      gossipspreader(wlist, n, topology, starttime)
    else
      GenServer.cast(getpid(startnode), {:sendmessagetops1, "Hi"})
      gossipspreaderps(wlist, n, topology, starttime)
    end
  end

  def gossipspreader(wlist, n, topo, starttime) do
    Enum.each(wlist, fn x ->
      if(Enum.at(getState(x), 0) > 0) do
        randomneighbor = Enum.random(Enum.at(getState(x), 1))
        GenServer.cast(getpid(randomneighbor), {:sendmessageto, "Hi", randomneighbor, wlist})
      end
    end)

    convergence =
      cond do
        topo == "line" ->
          0.6

        topo == "full" ->
          0.9

        true ->
          0.8
      end

    [{_spread, value}] = :ets.lookup(:table, :spreadvalue)

    if(value / n < convergence) do
      gossipspreader(wlist, n, topo, starttime)
    else
      endtime = System.monotonic_time(:millisecond)
      ct = endtime - starttime
      IO.inspect("Converged at #{ct}ms")
      # Enum.each(wlist, fn x -> IO.inspect(getState(x)) end)
      System.halt(1)
    end
  end

  def gossipspreaderps(wlist, n, topo, starttime) do
    Enum.each(wlist, fn z ->
      if(Enum.at(getState(z), 2) == "Hi") do
        [_count, neigh, _msg, _x, _y, snew, wnew, _sold, _wold, _sold1, _wold1] = getState(z)
        randomneighbor = Enum.random(neigh)
        GenServer.cast(
          getpid(randomneighbor),
          {:sendmessagetops, "Hi", randomneighbor, wlist, snew / 2, wnew / 2}
        )

        GenServer.cast(getpid(z), {:sendmessagetops2, snew / 2, wnew / 2})
      end
    end)

    convergence =
      cond do
        topo == "line" ->
          0.6

        topo == "full" ->
          0.9

        true ->
          0.8
      end

    [{_spread, value}] = :ets.lookup(:table, :spreadvalue)

    if(value / n < convergence) do
      gossipspreaderps(wlist, n, topo, starttime)
    else
      endtime = System.monotonic_time(:millisecond)
      ct = endtime - starttime
      IO.inspect("Converged at #{ct}ms")
      # Enum.each(wlist, fn x -> IO.inspect(getState(x)) end)
      System.halt(1)
    end
  end

  def startnodes(state) do
    {:ok, pid} = GenServer.start_link(__MODULE__, state)
    pid
  end

  def init(state) do
    {:ok, state}
  end

  def updateNeighbors(worker, list) do
    GenServer.cast(getpid(worker), {:updateNeighbors, list})
  end

  def handle_cast({:updateNeighbors, list}, state) do
    [count, _neigh, msg, x, y, s1, w1, s2, w2, s3, w3] = state
    state = [count, list, msg, x, y, s1, w1, s2, w2, s3, w3]
    {:noreply, state}
  end

  def handle_cast({:updatecoords, x, y}, state) do
    [count, neigh, msg, _initx, _inity, s1, w1, s2, w2, s3, w3] = state
    state = [count, neigh, msg, x, y, s1, w1, s2, w2, s3, w3]
    {:noreply, state}
  end

  def handle_cast({:sendmessageto, message, randomneighbor, wlist}, state) do
    [count, neigh, _msg, x, y, s1, w1, s2, w2, s3, w3] = state
    state = [count + 1, neigh, message, x, y, s1, w1, s2, w2, s3, w3]
    count = count + 1
    [{_spread, value}] = :ets.lookup(:table, :spreadvalue)
    # HERE I HAVE TO CHECK COUNT OF RANDOM NEIGHBOR NOT THE STARTNODE
    if(count == 1) do
      :ets.insert(:table, {:spreadvalue, value + 1})
    end

    if(count > 10) do
      List.delete(wlist, randomneighbor)
    end
    {:noreply, state}
  end

  def handle_cast({:sendmessagetops1, message}, state) do
    [count, neigh, _msg, x, y, snew, wnew, sold, wold, sold1, wold1] = state
    state = [count, neigh, message, x, y, snew, wnew, sold, wold, sold1, wold1]
    {:noreply, state}
  end

  def handle_cast({:sendmessagetops2, s, w}, state) do
    [count, neigh, msg, x, y, snew, wnew, sold, wold, _sold1, _wold1] = state
    state = [count, neigh, msg, x, y, s, w, snew, wnew, sold, wold]
    {:noreply, state}
  end

  def handle_cast({:sendmessagetops, message, randomneighbor, wlist, s, w}, state) do
    [count, neigh, _msg, x, y, snew, wnew, sold, wold, sold1, wold1] = state
    s1 = snew + s
    w1 = wnew + w
    if(
      abs(s1 / w1 - snew / wnew) < :math.pow(10, -10) &&
        abs(snew / wnew - sold / wold) < :math.pow(10, -10) &&
        abs(sold / wold - sold1 / wold1) < :math.pow(10, -10)
    ) do
      List.delete(wlist, randomneighbor)
      [{_spread, value}] = :ets.lookup(:table, :spreadvalue)
      :ets.insert(:table, {:spreadvalue, value + 1})
      {:noreply, state}
    else
      state = [count, neigh, message, x, y, s1, w1, snew, wnew, sold, wold]
      {:noreply, state}
    end
  end

  def getState(worker) do
    GenServer.call(getpid(worker), {:getState}, :infinity)
  end

  def handle_call({:getState}, _from, state) do
    {:reply, state, state}
  end
	# the getpid function receives workerid for eg, Worker1 and returns the pid value for that worker
  def getpid(worker) do
    [{_id, wpid}] = Registry.lookup(:my_registry, worker)
    wpid
  end
end