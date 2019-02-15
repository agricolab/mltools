function [amp, b, y_hat, x] = sinusoidality_fit(values)
% b = [dc offset, amplitude, numberofpeaks, phase]
Y = [values',values(1)]; %replicate first value because 0° = 360°
X = [0 90 180 270 360];
B0 = mean(values);  % vertical shift
B1 = (max(values) - min(values))/2;  % amplitude
B2 = 1;  % phase (number of peaks)
B3 = pi;  % phase shift (adjust from 0 if fit is clearly wrong)

% determine coefficients for modulation function
myFit = NonLinearModel.fit(X, Y, @(b,x)(b(1) + b(2)*sin(b(3)*x + b(4))), [B0, B1, B2, B3]); 

x =  0:0.01:2*pi;
b = myFit.Coefficients.Estimate; % load calculated values
y_hat = (b(1) + b(2)*sin(b(3)*x + b(4)));
amp = range(y_hat);

end