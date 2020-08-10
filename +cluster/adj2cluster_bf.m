function C = adj2cluster_bf(A)
% http://raphael.candelier.fr/?blog=Adj2cluster
% Symmetrize adjacency matrix
S = A + A';

% Initialization
C = {};
I = 1:size(S,1);

% The main loop
while ~isempty(I)
    C{end+1} = [];
    J = I(1);
    while ~isempty(J)
        C{end}(end+1) = J(1);
        J = setdiff(union(J, find(S(J(1),:))), C{end});
    end
    I = setdiff(I, C{end});
end
