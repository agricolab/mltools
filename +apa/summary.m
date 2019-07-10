function summary(val)
    fprintf('M= %.2f, SD= %.2f, ranging from %.2f to %.2f\n',...
            mean(val), std(val), min(val), max(val))
end