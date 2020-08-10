function C = adj2cluster_mp(A)    
    % http://raphael.candelier.fr/?blog=Adj2cluster
    % Symmetrize adjacency matrix
    S = A + A';

    % Create fully-connected subnetworks
    P = S;
    R = S;
    i = 1;
    while true
        P = P*S;
        T = R + P;
        if any((T(:))~=(R(:)))
            R = T;
        else
            break
        end
    end

    % Extract the clusters
    C = {};
    I = 1:size(A,1);
    while ~isempty(I)
        J = [I(1) find(R(I(1),:))];
        C{end+1} = J;
        I = setdiff(I,J);
end