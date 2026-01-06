function [latName, lonName] = findLatLonVars(info)
    vars = info.Variables;
    varNames = string({vars.Name});
    
    % First pass: common names (case-insensitive)
    latCandidates = ["lat","latitude","y","nav_lat"];
    lonCandidates = ["lon","longitude","x","nav_lon"];
    
    latName = findByName(varNames, latCandidates);
    lonName = findByName(varNames, lonCandidates);
    
    % Second pass: CF standard_name or units
    if latName == "" || lonName == ""
        for v = vars
            [units, ~, standardName] = getAttrs(v);
            nm = string(v.Name);
    
            if latName == ""
                if standardName == "latitude" || contains(units, "degrees_north") || strcmp(units,"degree_north")
                    latName = nm;
                end
            end
    
            if lonName == ""
                if standardName == "longitude" || contains(units, "degrees_east") || strcmp(units,"degree_east")
                    lonName = nm;
                end
            end
        end
    end
    
    if latName == "" || lonName == ""
        error("Could not confidently identify lat/lon variables in %s.", info.Filename);
    end
end