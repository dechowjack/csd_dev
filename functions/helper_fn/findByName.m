function name = findByName(varNames, candidates)
    name = "";
    for c = candidates
        idx = find(strcmpi(varNames, c), 1);
        if ~isempty(idx)
            name = varNames(idx);
            return
        end
    end
end