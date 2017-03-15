function [l v] = grasshopper(W, r, lambda, k)
%
% Reranking items by random walk on graph with absorbing states.
%
% INPUT 
% 
%   W: n*n weight matrix with non-negative entries.
%      W(i,j) = edge weight for the edge i->j
%      The graph can be directed or undirected.  Self-edges are allowed.
%   r: user-supplied initial ranking of the n items.  
%      r is a probability vector of size n.
%      highly ranked items have larger r values.
%   lambda: 
%      trade-off between relying completely on W and ignoring r (lambda=1) 
%      and completely relying on r and ignoring W (lambda=0).
%   k: return top k items as ranked by Grasshopper.  
%
% OUTPUT 
%
%   l: the top k indices after reranking.  
%      l(1) is the best item's index (into W), l(2) the second best, and so on
%   v: v(1) is the first item's stationary probability;
%      v(2)..v(k) are the next k-1 item's average number of visits during
%      absorbing random walks, in the respective iterations when they were 
%      selected.

 n = size(W,1);

 % sanity check first
 if (min(min(W))<0),
   error('Found a negative entry in W! Stop.');
 elseif (abs(sum(r)-1)>1e-5),
   error('The vector r does not sum to 1! Stop.');
 elseif (lambda<0 | lambda>1)
   error('lambda is not in [0,1]! Stop.');
 elseif (k<0 | k>n)
   error('k is not in [0,n]! Stop.');
 end

 
 % creating the graph-based transition matrix P
 P = W ./ repmat(sum(W,2), 1, n); % row normalized
 
 % incorporating user-supplied initial ranking by adding teleporting 
 hatP = lambda*P + (1-lambda)*repmat(r', n, 1);
 
 % finding the highest ranked item from the stationary distribution
 % of hatP:  q=hatP'*q.  The item with the largest stationary probability
 % is our higest ranked item.
 q = stationary(hatP);
 % the most probably state is our first absorbing node. Put it in l.
 [v, l]=max(q);
 
 % reranking k-1 more items by picking out the most-visited node one by one.
 % once picked out, the item turns into an absorbing node.
 while (length(l)<k),

   % Computing the expected number of times each node will be visited 
   % before random walk is absorbed by absorbing nodes.  Averaged over
   % all start nodes.  hatP defines the transition matrix, while l specifies 
   % the absorbing nodes.

   % Compute the inverse of the fundamental matrix
   uidx=setdiff(1:n,l);
   if length(l) == 1
        % Standard inversion if this is the first one
        N = inv(eye(length(uidx)) - hatP(uidx, uidx));
   else
        % using matrix inversion lemma henceforth
        old_uidx=setdiff(1:n,l(1:end-1));
        N = minv(eye(length(old_uidx)) - hatP(old_uidx, old_uidx), N, find(old_uidx==l(end)));
   end

   % Compute the expected visit counts
   nuvisit = 1/length(uidx) * N'*ones(length(uidx),1);

   % nuvisit = N'*ones(length(uidx),1); % old version, up to scaling
   nvisit = zeros(n,1);
   nvisit(uidx)=nuvisit;

   % Find the new absorbing state
   [tmpy tmpi]=max(nvisit);
   l=[l;tmpi];
   v=[v;tmpy];
 end

end


%------------------------------------------------------------------------
function q = stationary(P)
% find the stationary distribution of the transition matrix P
% the stationary distribution is q=P'*q
 [V,D]=eigs(sparse(P'),1,'LR');
 q=abs(V); % to avoid an all-negative vector
 q=q/sum(q); % make it a prob dist
end



%------------------------------------------------------------------------
function R = minv(A, Ainv, indx)
% Computes the inverse of a matrix with one row and column removed using 
% the matrix inversion lemma. It needs a matrix A, the inverse of A and the
% row and column index which needs to be removed.

 n = size(A,1);
 
 % Compute the inverse with one row removed
 u = zeros(n,1);
 u(indx) = -1;
 
 v = A(indx, :);
 v(indx) = v(indx) - 1;
 
 T = Ainv - ((Ainv * u) * (v * Ainv))/(1+v*Ainv*u);
 
 % Compute the inverse with one column removed
 w = A(:,indx);
 w(indx) = 0;
 
 R = T - ((T * w) * (u' * T))/(1+u'*T*w);
 
 % Remove redundant rows in resulting matrix
 R(indx,:) = []; R(:,indx) = [];

end