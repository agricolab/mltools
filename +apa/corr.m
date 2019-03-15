function corr(r, p)
    for ix = 1 : length(r)
        fprintf('r= %+.3f   ', p(ix))
    end
    fprintf('\n')
    for ix = 1 : length(r)
        fprintf('p= %.2f     ', p(ix))
    end
    fprintf('\n')
end