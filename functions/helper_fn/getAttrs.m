function [units, axisVal, standardName] = getAttrs(v)
    units = "";
    axisVal = "";
    standardName = "";
    if ~isfield(v, "Attributes") || isempty(v.Attributes), return; end
    
    for a = v.Attributes
        key = lower(string(a.Name));
        val = a.Value;
        if ischar(val) || isstring(val)
            sval = lower(string(val));
        else
            sval = "";
        end
    
        switch key
            case "units"
                units = sval;
            case "axis"
                axisVal = sval;
            case "standard_name"
                standardName = sval;
        end
    end
end