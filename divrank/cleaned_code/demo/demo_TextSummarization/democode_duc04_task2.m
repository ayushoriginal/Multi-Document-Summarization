clear all
load weight_matrix_duc04_task2

myname = 'duc04_task2';
num_topic = 50;


%% pagerank
for i = 1:num_topic
    lambda_value = 0.3;
    output.pagerank.topic(i) = pagerank(weight_matrix(i).matrix, lambda_value);
end
eval(sprintf('save result_rank_%s output', myname));

%% personalized pagerank
for i = 1:num_topic
    lambda_value = 0.4;
    beta_value = 0.4;
    r = weight_matrix(i).pos_vector.^(-beta_value);
    r = r / sum(r);
    output.pagerank_personalized.topic(i) = pagerank(weight_matrix(i).matrix, lambda_value, r);
end
eval(sprintf('save result_rank_%s output', myname));

%% mmr
for i = 1:num_topic
   gamma_value = 0.6;
   output.mmr.topic(i) = mmr(weight_matrix(i).matrix, output.pagerank.topic(i), gamma_value);
end
eval(sprintf('save result_rank_%s output', myname));

%% divrank
for i = 1:num_topic
    lambda_value = 0.4;
    alpha_value = 0.9;
    beta_value = 0.8;
    r = weight_matrix(i).pos_vector.^(-beta_value);
    r = r / sum(r);
    output.divrank.topic(i) = divrank(weight_matrix(i).matrix, lambda_value, alpha_value, r);
end
eval(sprintf('save result_rank_%s output', myname));

%% divrank cumulative
for i = 1:num_topic
    lambda_value = 0.1;
    alpha_value = 0.9;
    beta_value = 1.8;
    r = weight_matrix(i).pos_vector.^(-beta_value);
    r = r / sum(r);
    output.divrank_accumulate.topic(i) = divrank_accumulate(weight_matrix(i).matrix, lambda_value, alpha_value, r);
end
eval(sprintf('save result_rank_%s output', myname));

%% grasshopper
for i = 1:num_topic
    lambda = 1;
    beta_value = 0.4;
    r = weight_matrix(i).pos_vector.^(-beta_value);
    r = r / sum(r);
    output.grasshopper.topic(i) = grasshopper(weight_matrix(i).matrix, r, lambda, 100);
end
eval(sprintf('save result_rank_%s output', myname));
    




