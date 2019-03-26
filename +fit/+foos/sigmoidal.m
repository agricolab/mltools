function trace = sigmoidal(offset, amplitude, slope, threshold, x)
trace = offset + (amplitude./ ( 1 + exp(-slope*(x-threshold))));
end