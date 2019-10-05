
# PROJECT 2:  IMPLEMENTATION OF GOSSIP PROTOCOL AND PUSH SUM ALGORITHM

### COP5615 - Distributed Operating Systems Principles

The goal of the project was to implement the Gossip Protocol and Push-Sum Algorithm for various topologies such as Full Network, Line, Random 2D grid, Honeycomb and RandomHoneycomb .

### Date: October 1, 2019

## Team Members:
1.	Karan Manghani (UFID: 7986-9199) Email: karanmanghani@ufl.edu
2.	Yaswanth Bellam (UFID: 2461-6390) Email: yaswanthbellam@ufl.edu

##Implementation: 
We have implemented the 2 given information exchange protocols/algorithms:
1.	Gossip Algorithm
2.	Push-Sum Algorithm
We have implemented these protocols for various topologies such as:
1.	Line: Each node has 2 neighbors.
2.	Full: Each actor has every other actor as its neighbor.
3.	Random2D: An actor has another actor as its neighbor when the distance between the two is 0.1
4.	Honeycomb: Actors are arranged in hexagonal shape where an actor can have a maximum degree 3
5.	Honeycomb with random neighbor: An additional random neighbor is included in the neighbor list of a node 
<br/>
The Gossip Algorithm works on the basic idea that initially a node receives a 	rumor (in our case, the message “Hi”).  This node then propagates the gossip message to one of its neighbors. The initial node and the its selected neighbor further propagate this gossip. This continues till the convergence condition is met.  
<br/>
The Push Sum algorithm is based on the following algorithm (given in the research paper “Gossip-Based Computation of Aggregate Information” by David Kempe, Alin Dobra, and Johannes Gehrke)

## Convergence Criteria based on topologies: 
Line: 0.6
Full: 0.9
Random2D: 0.8
Honeycomb: 0.8
Random Honeycomb: 0.8

## TIME CALCULATION: 
We have measured the time of the algorithm using the difference in the value given by the System.monotonic_time () function at the start-time and end-time. 

#GRAPHS:
 
1. GOSSIP PROTOCOL
![gossip-graph](/Graphs/gossip-graph.jpeg)

2. PUSH-SUM AlGORITHM
![pushsum-graph](/Graphs/pushsum-graph.jpeg)


## Maximum number of nodes tested for the following algorithms and topologies:

1.	GOSSIP
a.	Line:  7000 
b.	Full: 9000
c.	Random2D: 7000
d.	Honeycomb: 10000
e.	Random Honeycomb: 10000

2.	PUSH-SUM
a.	Line:  500
b.	Full: 5000
c.	Random2D: 7000
d.	Honeycomb: 10000
e.	Random Honeycomb:  10000
