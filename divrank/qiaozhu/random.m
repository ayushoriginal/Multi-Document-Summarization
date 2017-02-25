function output = random(W)
%% Input arguments:
%%%%    -- W: the adjacency matrix of the graph
%%%%    -- lambda_value: paramteter lambda
%%%%    -- r: the personalized score. By default, r = ones(1, n)/n;
%% Output arguments:
%%%%    -- output: matlab object variable:
%%%%    -- output.num_iter: number of iterations before convergence
%%%%    -- output.pr: the score ranked by DivRank. Notice that
%%%%    sum(output.pr)==1
%%%%    -- output.rank: intergers, the position ranked by DivRank. 
%% Specify some constants
n = size(W, 2);
pr = [1:1:n];
s = RandStream('mt19937ar','Seed',12345);
output.rank = randperm(s, length(pr));
