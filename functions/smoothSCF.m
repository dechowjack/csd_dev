function smoothSCF = smoothSCF(SCF,twindow,nt,mode)
    if isa(SCF,'double')
        SCF = single(SCF);
    end
    smoothSCF = single(zeros(size(SCF)));
    if(length(size(SCF))) == 3
        for i = 1+twindow : nt-twindow
            checkWin = i - twindow : i + twindow;
            if strcmp(mode,'mean')
                smoothSCF(:,:,i) = mean(SCF(:,:,checkWin),3,'omitnan');
            elseif strcmp(mode,'median')
                smoothSCF(:,:,i) = median(SCF(:,:,checkWin),3,'omitnan');
            end
        end
    else
        for i = 1+twindow : nt-twindow
            checkWin = i - twindow : i + twindow;
            if strcmp(mode,'mean')
                smoothSCF(i) = mean(SCF(checkWin),'omitnan');
            elseif strcmp(mode,'median')
                smoothSCF(i) = median(SCF(checkWin),'omitnan');
            end
        end
    end
end