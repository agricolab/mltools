function [peak_phase, amplitude, trace, fxx] = sinusoidality_fft(values)
    fxx             = fft(values);   % Fourier transformation of DELTA
    complex_value   = fxx(2);   % calculate effect  

    
    offset = fxx(1)./length(fxx);
    A  = abs(complex_value)/2;
    angle_shift = angle(complex_value);
    tmp_x = [0.001:0.001:2*pi];
    trace = offset + (A .* cos(tmp_x + angle_shift));
    [~, idx]        = sort(trace, 'descend');
    
    amplitude  = A;
    peak_phase = rad2deg(tmp_x(idx(1)));
end