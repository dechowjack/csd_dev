function rejectIfProjected(info)
    vars = info.Variables;
    
    % Heuristic A: presence of CF projection variables / grid mapping
    allNames = lower(string({vars.Name}));
    if any(allNames == "crs") || any(contains(allNames, "grid_mapping")) || any(allNames == "spatial_ref")
        error("Projected dataset detected (crs/grid_mapping/spatial_ref present). Rejecting.");
    end
    
    % Heuristic B: look for x/y coordinate variables with meter-like units or axis X/Y
    for v = vars
        nm = lower(string(v.Name));
        [units, axisVal, standardName] = getAttrs(v);
    
        isXYName = any(nm == ["x","y","easting","northing"]);
        isXYAxis = any(axisVal == ["x","y"]);
        isProjectedUnits = contains(units,"metre") || contains(units,"meter") || strcmp(units,"m") || contains(units,"km");
    
        if (isXYName || isXYAxis) && isProjectedUnits
            error("Projected dataset detected (%s with units '%s'). Rejecting.", v.Name, units);
        end
    
        % Another common hint: standard_name = projection_x_coordinate / projection_y_coordinate
        if any(standardName == ["projection_x_coordinate","projection_y_coordinate"])
            error("Projected dataset detected (standard_name=%s). Rejecting.", standardName);
        end
    end
end