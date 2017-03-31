clear all

myname = 'imdb';
eval(sprintf('load grasshopper_%s', myname));
n = size(costar, 1);
r = actor_movie_counts' / sum(actor_movie_counts);

%% pagerank
lambda_value = 0.1;
output.pr = pagerank(costar, lambda_value);
fprintf(fpw1, 'pr:\n');
eval(sprintf('save result_rank_%s output', myname));

%% personalized pagerank
lambda_value = 0.1;
output.ppr = pagerank(costar, lambda_value, r);
fprintf(fpw1, 'ppr:\n');
eval(sprintf('save result_rank_%s output', myname));

%% divrank
lambda_value = 0.1;
alpha_value = 0.25;
output.dr = divrank(costar, lambda_value, alpha_value, r);
fprintf(fpw1, 'dr:\n');
eval(sprintf('save result_rank_%s_diffalpha output', myname));

%% divrank accumulative
lambda_value = 0.1;
alpha_value = 0.5;
output.adr = divrank_accumulate(costar, lambda_value, alpha_value, r);
fprintf(fpw1, 'adr:\n');
eval(sprintf('save result_rank_%s output', myname));

%% mmr
gamma_value = 0.5;
output.mmr = mmr(costar, output.pr, gamma_value);
fprintf(fpw1, 'mmr:\n');
eval(sprintf('save result_rank_%s output', myname));

