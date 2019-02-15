function complex_value = sinusoidality_fft(values)
    fxx             = fft(values);   % Fourier transformation of DELTA
    complex_value   = fxx(2);   % calculate effect  
end