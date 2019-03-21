function print(hdl, folder, fname, arg)
    os.mkdir(folder);
    print(gcf,[folder, filesep, fname], arg);
end