clear all

myname = 'researcher_cit';
eval(sprintf('load weight_matrix_%s', myname));
n = size(weight_matrix, 1);
r = ones(1, n) / n;


%% PageRank
lambda_value = 0.1;
output.pagerank = pagerank(weight_matrix, lambda_value);
eval(sprintf('save result_rank_%s output', myname));

%% divrank
lambda_value = 0.1;
alpha_value = 0.25;
output.divrank = divrank(weight_matrix, lambda_value, alpha_value, r);
eval(sprintf('save result_rank_%s output', myname));

%% Cumulative DivRank
lambda_value = 0.1;
alpha_value = 0.5;
output.divrank_cumulative = divrank_accumulate(weight_matrix, lambda_value, alpha_value, r);
eval(sprintf('save result_rank_%s output', myname));

%% mmr
gamma_value = 0.5;
output.mmr = mmr(weight_matrix, output.pr, gamma_value);
eval(sprintf('save result_rank_%s output', myname));
     
