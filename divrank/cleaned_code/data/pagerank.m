function output = pagerank(W, lambda_value, r)
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
if nargin < 3
    r = ones(1, n)/n;
end
pr = ones(1, n)/n;
num_iter = 0;
max_iter = 1000;
diff_value = 1e+10;
tol_value = 1e-5;

%% Algorithm
tmp1 = sum(W, 2);
idx_nan = find(tmp1 == 0);
P = W ./ repmat(tmp1, 1, n);
P(idx_nan, :) = repmat(r, length(idx_nan), 1);
P = (1-lambda_value) * P + lambda_value * repmat(r, n, 1);

while ((num_iter < max_iter) & (diff_value > tol_value))
  pr_new = pr * P;
  num_iter = num_iter + 1;
  diff_value = sum(abs(pr_new - pr)) / sum(pr);
  pr = pr_new;
end

%% Output
output.num_iter = num_iter;
output.diff_value = diff_value;
output.pr = pr;
[tmp, output.rank] = sort(pr, 2, 'descend');
