function s = ttest(p, stats, ci)
    if nargin ==1
        fprintf('p = %5.3f', p);
    end
    if nargin >1
        fprintf('t(%.0f) = %4.2f, p = %5.3f',stats.df, stats.tstat, p);
    end
    if nargin > 2
        fprintf(', CI95%% = %.2f to %.2f',ci(1), ci(2))
    end
    fprintf('\n');
end