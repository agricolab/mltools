function s = ttest(p, stats)
    s = sprintf('p = %5.3f, t(%.0f) = %4.2f',p, stats.df, stats.tstat);
    fprintf('%s\n',s);
end