function jobs = checkNDX(theFileName,varargin)

tempExtension = '.temp';
if(~isempty(varargin))
    tempExtension = varargin{1};
end

theFileNameTemp = [theFileName tempExtension];
jobs = [];
system(['flock -x ' theFileName ' -c '' cp ' theFileName ' ' theFileNameTemp '  '' ']);
fid = fopen(theFileNameTemp);
tTest = textscan(fid,'%s');
fclose(fid);
tTest = tTest{1};
for(index = 1:length(tTest))
    str = tTest{index};
    numToAdd = regexp(str,'\d+','match');
    if(isempty(numToAdd))
        continue;
    end
    if(isequal(numToAdd,0))
        disp('a completed job is of number zero. weird.');
        continue;
    end
    didError = regexp(str,'error','match');
    if(~isempty(didError)) %if there is an error, didError will be not empty
                           %disp(['found error with job ' numToAdd{1} ', skipping']);
        continue;
    end
    
    jobs = [jobs str2num(numToAdd{1})];
end
jobs = unique(jobs);

end