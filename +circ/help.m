function help()
    readme = [fileparts(mfilename('fullpath')), filesep,'readme.txt'];
    fprintf('%s', readme)
    f = fopen(readme);
    line = ' ';
    display = false;
    while line ~= -1
        if any(ismember(line, 'Contents'))
            display = true;
        end
        if display
            fprintf('%s', line)            
        end
        if any(ismember(line, 'The implementation'))
            display = false;
        end
                
        line = fgets(f);
    end
    fclose(f);
end