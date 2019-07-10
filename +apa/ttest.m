function s = ttest(p, stats, ci)
    
    if nargin ==1
        s = sprintf('p = %5.3f', p);
    else
        s = '';
    end
    if nargin >1
        s = [s, sprintf('t(%.0f) = %4.2f, p = %5.3f',stats.df, stats.tstat, p)];
    end
    if nargin > 2
        s = [s, sprintf(', CI95%% = %.2f to %.2f',ci(1), ci(2))];
    end
    fprintf('%s\n',s);
end