function  [offset, amplitude, peak_phase, pval, trace, model] = sinusoidality_nlm(x, y)
    % test
%     cnt = 0;
%     figure
%     for shift = 1 : 10 : 360
%         x = [0:0.01:2*pi]';
%         y = sin(x+deg2rad(shift));
%         [o, a, pp, pval, trace, model_nlm] = fit.sinusoidality_nlm(x,y);
%         [o, a, pp, pval, trace, model_glm] = fit.sinusoidality_glm(x,y);
%         cnt =  cnt+1
%         subplot(6,6,cnt)
%         hold on
%         plot(x,y)
%         plot([0:0.001:2*pi], .5.*trace)
%     end


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
    

    
    var_fit     = var(y(1:end-1)-foo(b, x(1:end-1)));
    var_const   = var(y(1:end-1));
    f           = var_const./var_fit;
    pfit        = fcdf(f, 3, 3, 'upper');
    pval        = cat(1, model.Coefficients.pValue(1:3), pfit); %offset, amplitude, phase, versus_const
    
end