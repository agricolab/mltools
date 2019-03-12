function  [offset, amplitude, peak_phase, pval, trace, model] = sinusoidality_nlm(x, y)
    B0 = mean(y);
    B1 = range(y)/2;
    B2 = 0;
    foo =  @(b,x)(b(1) + b(2)*sin(x + b(3)));
    model = NonLinearModel.fit(x, y, foo, [B0, B1, B2]);
    b = model.Coefficients.Estimate;
    if b(2) < 0
        b(2) = -b(2);
        b(3) = b(3) + pi;
    end
    
    tmp_x           = [0:0.001:2*pi];
    trace           = foo(b, tmp_x);
    [~, idx]        = sort(trace, 'descend');
    peak_phase      = rad2deg(tmp_x(idx(1)));
    amplitude       = b(2)*2;
    offset          = b(1);
    
    
    
    var_fit     = var(y(1:4)-foo(b, x(1:4)));
    var_const   = var(y(1:4));
    f           = var_const./var_fit;
    pfit        = fcdf(f, 3, 3, 'upper');
    pval        = cat(1, model.Coefficients.pValue(1:3), pfit); %offset, amplitude, phase, versus_const
    
end