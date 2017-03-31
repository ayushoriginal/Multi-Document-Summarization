function output = mmr(W, obj_pr, gamma_value, num_top)
%% Input arguments:
%%%%    -- W: the adjacency matrix of the graph
%%%%    -- obj_pr: object variale output from pagerank()
%%%%    -- gamma_value: paramter gamma
%%%%    -- num_top: number of top ranked items by MMR
%% Output arguments:
%%%%    -- output: matlab object variable:
%%%%    -- output.rank_set: the ranked position of top num_top nodes

%%
if nargin < 4
    num_top = n;
end
W = W/n;

full_set = 1:n;
rank_set = obj_pr.rank(1);
remaining_set = setdiff(full_set, rank_set);

for i = 2:num_top
    tmp1 = max(W(remaining_set, rank_set), [], 2);
    tmp2 = obj_pr.pr(remaining_set)';
    [tmp3, selected_item] = max(gamma_value * tmp2 - (1 - gamma_value) * tmp1);
    rank_set = [rank_set, remaining_set(selected_item)];
    remaining_set = setdiff(full_set, rank_set);
end

output.rank = rank_set;
