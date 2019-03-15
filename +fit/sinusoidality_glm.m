function [offset, amplitude, peak_phase, pval, trace, gm] = sinusoidality_glm(x, y)
% x should be in radians, i.e. pi
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fit_foo         = @(x, off, amp, phase) off + (amp * sin(x - phase));
g               = fittype('y_offset + (amplitude * sin(x + start_phase))',...
                        'coefficients',{'y_offset','amplitude','start_phase'});
gopt            = fitoptions(g);

start_y_offset  = mean(y);
start_amplitude = range(y-mean(y))/2;
start_phase     = angle(hilbert(y));
start_phase     = start_phase(1);

gopt.StartPoint = [start_y_offset, start_amplitude, start_phase];
gopt.Lower      = [-Inf 0 -pi] ;
gopt.Upper      = [Inf Inf +pi];
gm              = fit(x, y, g, gopt);


tmp_x           = [0:0.001:2*pi];
trace           = fit_foo(tmp_x, gm.y_offset, gm.amplitude, gm.start_phase);
[~, idx]        = sort(trace, 'descend');

peak_phase      = rad2deg(tmp_x(idx(1)));
amplitude       = gm.amplitude*2;
offset          = gm.y_offset;

   
var_fit     = var(y(1:end-1)-fit_foo(x(1:end-1)', gm.y_offset, gm.amplitude, gm.start_phase)');
var_const   = var(y(1:end-1));
f           = var_const./var_fit;
pval        = fcdf(f, 3, 3, 'upper');

end