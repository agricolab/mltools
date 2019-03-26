function s = ttest(p, stats, ci)
    fprintf('p = %5.3f, t(%.0f) = %4.2f',p, stats.df, stats.tstat);
    if nargin > 2
        fprintf(' CI = %.2f to %.2f',ci(1), ci(2))
    end
    fprintf('\n');
end