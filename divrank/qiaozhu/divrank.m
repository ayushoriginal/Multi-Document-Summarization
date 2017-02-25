function output = divrank(W, lambda_value, alpha_value, r)
%% Input arguments:
%%%%    -- W: the adjacency matrix of the graph
%%%%    -- lambda_value: paramteter lambda
%%%%    -- alpha_value: paramter alpha
%%%%    -- r: the personalized score. By default, r = ones(1, n)/n;
%% Output arguments:
%%%%    -- output: matlab object variable:
%%%%    -- output.num_iter: number of iterations before convergence
%%%%    -- output.pr: the score ranked by DivRank. Notice that
%%%%    sum(output.pr)==1
%%%%    -- output.rank: intergers, the position ranked by DivRank. 

%% Arguments
n = size(W, 2);
if nargin < 4
    r = ones(1, n)/n;
end

%% Specify some constants
pr = ones(1, n)/n;
num_iter = 0;
max_iter = 1000;
diff_value = 1e+10;
tol_value = 1e-3;

%% Get p0(v -> u)
tmp = sum(W, 2);
idx_nan = find(tmp == 0);
W0 = W ./ repmat(tmp, 1, n);
W0(idx_nan, :) = 0;

%% Algorithm
while ((num_iter < max_iter) & (diff_value > tol_value))
% for i = 1:1000
    W1 = alpha_value * W0 .* repmat(pr, n, 1);
    W1 = W1 - diag(diag(W1)) + (1 - alpha_value) * diag(pr);
    tmp1 = sum(W1, 2);
%     idx_nan = find(tmp1 == 0);
    P = W1 ./ repmat(tmp1, 1, n);
    %P(idx_nan, :) = repmat(r, length(idx_nan), 1);
%     P(idx_nan, :) = 0;
    P = (1-lambda_value) * P + lambda_value * repmat(r, n, 1);

    pr_new = pr * P;
    num_iter = num_iter + 1;
    diff_value = sum(abs(pr_new - pr)) / sum(pr);
    pr = pr_new;
%     fprintf('%d    %f\n', num_iter, diff_value);
end

%% Output
output.num_iter = num_iter;
output.pr = pr;
[tmp, output.rank] = sort(pr, 2, 'descend');
