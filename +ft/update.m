function update(folder)

    curdir = pwd;
    cd(folder)
    system('git pull')
    cd(curdir)

end
