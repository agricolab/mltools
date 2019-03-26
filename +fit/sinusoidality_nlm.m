% function  [offset, amplitude, peak_phase, pval, model] = sinusoidality_nlm(x, y)
%
% args
% ----
% x: vector
%   vector of timepoints / degrees in radian
% y: vector
%   vector of measured values
% 'peak': 'numerical', 'analytical' (default)
%   method to derive the phase of the peak
% 'freq': float 
%   frequency of the sine in Hz. If set,  calculates time to peak in ms and
%   adds the field to the model output
%
% return
% ------
% offset: double
%   constant DC component, or main effect
% amplitude: double
%   peak to peak amplitude of the sine
% peak_phase: float
%   if argument 'peak' is 'analytical' (default), returns the phase in 
%   degree of the analytical peak of the sine. If argument is 'numerical',
%   it returns the numerical peak. In both, subtract 90° to derive the 
%   phase with which the sine starts.
% pval: vector
%   the 4 analytical pvalues for the coefficients (offset, amplitude, peak)
%   to be different from zero, and the model fit compared to a constant
% model: struct
%   field b is the model parameters
%   field foo is the fitting function
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function  [offset, amplitude, peak_phase, pval, model] = sinusoidality_nlm(x, y, varargin)

    

    
    args = struct('peak','analytical',...
                  'nanaction','average');
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end          

    remnan = isnan(y);
    if strcmpi(args.nanaction, 'average')        
        y(remnan) = nanmean(y);
    elseif strcmpi(args.nanaction, 'remove')
        y(remnan) = [];
        x(remnan) = [];
    else
        throw(MException('ARG:NAN',sprintf('nanaction %s is not implementend', args.nanaction)))
    end
    
    B0 = mean(y);
    B1 = range(y)/2;
    B2 = 0;
    foo =  @(b,x)(b(1) + b(2)*sin(x - b(3)));
    model = NonLinearModel.fit(x, y, foo, [B0, B1, B2]);
    b = model.Coefficients.Estimate;
    % the amplitude is not bounded by zero, therefore a negative amplitude 
    % can occur. In that case, flip by 180°.
    if b(2) < 0
       b(2) = -b(2);
       b(3) = b(3) + pi;       
    end    
    
    % create model parameter output
    amplitude       = b(2)*2;
    offset          = b(1);

    if strcmpi(args.peak, 'analytical')
        peak_phase = mod(rad2deg(b(3))+90, 360);
    elseif strcmpi(args.peak, 'numerical')
        tmp_x           = [0:0.0001:2*pi];
        trace           = foo(b, tmp_x);
        [~, idx]        = max(trace);
        peak_phase      = rad2deg(tmp_x(idx));
    else
        throw(MException('ARG:PEAK',sprintf('"%s" is not implemented for peak detection', args.peak)))
    end

    var_fit     = var(y(1:end-1)-foo(b, x(1:end-1)));
    var_const   = var(y(1:end-1));
    f           = var_const./var_fit;
    pfit        = fcdf(f, length(y)-1, length(y)-1, 'upper');
    pval        = cat(1, model.Coefficients.pValue(1:3), pfit); %offset, amplitude, phase, versus_const
    model       =  struct('b', b, 'foo', foo);
    
end