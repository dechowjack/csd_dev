function val = scaleAlgoSubRoutine(tileSCF,tileDEM)

    val = 0;
    checkDEM = 13; checkSCF = 15;

    mean_tileSCF = mean(tileSCF(:),'all','omitmissing');
    range_tileDEM = max(tileDEM(:)) - min(tileDEM(:));
    mean_tileDEM = mean(tileDEM(:),'all','omitmissing');
    % v2-3 >0.35
    if mean_tileSCF>0.35
        checkSCF = 1;
        val = 1;
        if mean_tileDEM>=1250
            val = 1;
            checkDEM = 1;
        else
    end
    % v2-3 < 250
    if range_tileDEM < 250  
        val = 2;
        checkDEM = 0;
    end

    if checkSCF == checkDEM
        val = 3;
    end
    
end