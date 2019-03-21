function [amplitude, slope, threshold, offset, pval, lr, trace] = sigmoidal(x, y, varargin)
    
    arg = struct('offset', 0);
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end  

    x(isnan(y))     = [];
    y(isnan(y))     = [];
    xx              = linspace(min(x), max(x), 1000);    
    foo             = @(offset, amplitude, slope, threshold, x) ...
                        offset + (amplitude./ ( 1 + exp(-slope*(x-threshold))));
    if arg.offset
        model   = fit(x, y, foo, ...
                      'StartPoint', [0, max(y) range(y)./length(x) mean(x)],...
                      'Lower', [min(y) min(y) -range(y) min(x)],...
                      'Upper', [max(y) max(y) range(y) max(x)]);
    else
        model   = fit(x, y, foo, ...
                      'StartPoint', [0 max(y) range(y)./length(x) mean(x)],...
                      'Lower', [0 min(y) -range(y) min(x)],...
                      'Upper', [0 max(y) range(y) max(x)]);
    
    end
    
    offset      = model.offset;
    amplitude   = model.amplitude;
    slope       = model.slope;
    threshold   = model.threshold;
    trace       = foo(offset, amplitude, slope, threshold, xx);
    
    errorfit    = var(y-foo(offset, amplitude, slope, threshold, x));
    errorconst  = var(y);
    pval        = fcdf(errorfit./errorconst, length(y)-1, length(y)-1);
    lr          = chi2pdf(errorconst, length(y)-1) ./ chi2pdf(errorfit, length(y)-1);
end