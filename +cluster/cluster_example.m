folder.ft = '/media/rtgugg/sd/tools/matlabtools/fieldtrip';
addpath(folder.ft)
addpath('/media/rtgugg/sd/tools/matlabtools/mltools')
ft_defaults;
%%
chan.labels = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', 'O1', ...
    'O2', 'F7', 'F8', 'T7', 'T8', 'P7', 'P8', 'Fz', 'Cz', 'Pz', 'Iz', ...
    'FC1', 'FC2', 'CP1', 'CP2', 'FC5', 'FC6', 'CP5', 'CP6', 'TP9', 'TP10', 'FT9', ...
    'FT10', 'F1', 'F2', 'C1', 'C2', 'P1', 'P2', 'AF3', 'AF4', 'FC3',...
    'FC4', 'CP3', 'CP4', 'PO3', 'PO4', 'F5', 'F6', 'C5', 'C6', 'P5',...
    'P6', 'AF7', 'AF8', 'FT7', 'FT8', 'TP7', 'TP8', 'PO7', 'PO8', 'Fpz',...
    'CPz', 'POz', 'Oz',};
chan.eeg = chan.labels(1:64);
chan = configure.channel_layout(chan, folder);
cfg                 = [];
cfg.method          = 'triangulation';
cfg.elec            = chan.elec;
neighbors           = ft_prepare_neighbours(cfg);
%%
% initialize a chan x chan adjacency matrix
% in an adjacency matrix, the identity (i.e the diagonal) and all
% neighbor are marked. This allows later to easily add up the cluster
% sizes. finally, we plot the adjacency matrix
A = zeros(length(neighbors),length(neighbors)); 
for cix = 1 : length(neighbors)
    coi = neighbors(cix).label;
    row_idx= ismember(chan.labels, coi);
    A(row_idx, row_idx) = 1; 
    for nix = 1 : length(neighbors(cix).neighblabel)
        noi = neighbors(cix).neighblabel{nix};
        clm_idx = ismember(chan.labels, noi);        
        A(row_idx, clm_idx) = 1;
    end
end
close all
figure
imagesc(A)
set(gca, 'ytick', 1:length(neighbors), 'yticklabels', {neighbors.label},...
    'yticklabelrot', 45, 'fontsize', 6)
%%
clc

% the cluster threshold defines at which p-values a statistic can belong to a cluster
cluster_threshold = 0.05;
% the alpha threshold will test with a permutation test, whether the 
% cluster statistics (e.g. mean, size, t-sum, etc.) is significant
alpha_threshold = 0.05;

% first, we mock data for each channel by regress the actual measure out
% and feeding the measure into three channels. We should therefore find 
% three significant correlations, of which only two are actually in nearby 
% channels and should therefore find a cluster of size 2 and one of size 1
% Data has subjects x channel , the measures has only subjects x 1
DATA = normrnd(0, 1, 12, 64);
MEASURE = normrnd(0, 1, 12, 1);
true_h = 0;
fprintf('Mocking a dataset: [')
while sum(true_h) ~= 3
    fprintf('.')
    for cix = 1 : size(DATA,2)
        if ~ismember(cix, [1, 39, 64])
            [~, ~, DATA(:, cix)] = regress(DATA(:, cix), MEASURE);
        else
            DATA(:, cix) = normrnd(0, .1, 12, 1) + MEASURE;
        end
    end
    % here we perform the original, unclustered statistical test
    [true_r, true_p] = corr(DATA, MEASURE);
    % and check which pass the traditional threshold
    true_h = true_p < cluster_threshold;    
end
fprintf(']\n')
% using this boolean vector, we create a mask and apply it to the 
% adjacency matrix. only those electrodes which exhibited a significant 
% modulation are then used for the clustering
true_A = A .* (true_h * true_h');
% we subsequently cluster them using the (b)rute (f)orce approach, which
% has the advantage that it returns cluster in order of labels
C = cluster.adj2cluster_bf(true_A); 
% subsequently, we have to decide which statistic to use for testing
% whether the cluster is significant. This is relatively arbitrary.
% common choices are the sum of the original statistic across all channels
% in the cluster, as this accounts for size and magnitude. But similarily,
% only size or the maximal statistics within the cluster has been
% suggested. Ideally, the choice of statistic should follow the original
% research question, and have not much influcence on the final results.
% here, we use the sum of the R² value
stats_val = true_r.^2;
cluster_size = [];
cluster_val = [];
for idx = 1 : length(C)
    c_size = length(C{idx});
    % the function returns alawys the cluster with itself, but we want this
    % one only if it is significant
    if c_size == 1 && ~true_h(idx)
        continue;
    end
    cluster_size(idx) = c_size;
    temp = 0;
    fprintf('A cluster was found comprised of ')
    for cix = C{idx}
        temp = temp + stats_val(cix);
        fprintf(' %s', chan.labels{cix})
    end
    fprintf('.\n')
    cluster_val(idx) = temp;
end
[max_size, argmax] = max(cluster_size);
true_cluster_val = cluster_val(argmax);
%% run permutation test

perm_rep = 1000;
perm_cluster_val = [];
fprintf('Running %4.0f permutation clusters: [', perm_rep);
for rep = 1 : perm_rep
    if mod(rep,ceil(perm_rep/10)) ==0, fprintf('.'); end
    % we sample from the original measure in random order
    % this should break any correlation between DATA and MEASURE
    perm_MEASURE = randsample(MEASURE, length(MEASURE));
    % subsequently, we run the cluster analysis again
    % i.e. calculation of correlations, threshold for mask and clustering
    [perm_r, perm_p] = corr(DATA, perm_MEASURE);
    perm_h = perm_p < cluster_threshold;
    perm_A = A .* (perm_h * perm_h');          
   
    C = cluster.adj2cluster_bf(perm_A); 
    
    stats_val = perm_r.^2;
    cluster_size = [];
    cluster_val = [];
    for idx = 1 : length(C)
        c_size = length(C{idx});
        % the function returns alawys the cluster with itself, but we want this
        % one only if it is significant
        if c_size == 1 && ~perm_h(idx)
            continue;
        end
        cluster_size(idx) = c_size;
        temp = 0;
        for cix = C{idx}
            temp = temp + stats_val(cix);          
        end        
        cluster_val(idx) = temp;
    end
    [max_size, argmax] = max(cluster_size);
    if ~isempty(argmax)        
        perm_cluster_val(rep) = cluster_val(argmax);
    else
        perm_cluster_val(rep) = 0;
    end
    
end
fprintf(']\n');
% we subsequently perform a simple permutation p-value calculation
cluster_p = 1 - mean(true_cluster_val > perm_cluster_val);
% taking into account, that even if the true_cluster_val is always larger,
% it can't be smaller then 1 over the number of repetitions
cluster_p = max(cluster_p, 1-perm_rep);
fprintf('There is a significant cluster with p=%3.4f and a statistic of %3.2f\n', cluster_p, true_cluster_val);

