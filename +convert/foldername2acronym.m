function acronym = foldername2acronym(foldername)
    parts = strsplit(foldername,'_');
    acronym = parts{end};
    acronym = acronym(1:end-2);
end