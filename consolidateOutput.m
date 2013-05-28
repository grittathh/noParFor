userID = 'changeThis';
format compact
[status,result] = system('$PBS_O_WORKDIR')
endIndex = strfind(result,': is a directory') - 1
startIndex = strfind(result,['/home/' userID '/']) + length(['/home/' userID '/'])

identifier = result(startIndex:endIndex)
disp(identifier)

cd('/scratch/users');
ls
cd([userID '/' identifier]);

load('inputDataStruct.mat')

%get complete list of jobs.
allJobs = 1:length(inputDataStruct);
    
%find completed jobs
completedJobs = [];
fid = fopen('fileTracker.ndx');
tTest = textscan(fid,'%s');
fclose(fid);
tTest = tTest{1};

for(index = 1:length(tTest))
    str = tTest{index};
    numToAdd = regexp(str,'\d+','match');
    if(isempty(numToAdd))
        continue
    end

    completedJobNumber = str2num(numToAdd{1});

    cwd = pwd;

    tempDirName = [num2str(ceil(completedJobNumber/1000))];

    cd(tempDirName);
    try
        load(['outputDataStructSingle' num2str(completedJobNumber) '.mat']);
    catch
        %error handling
        disp(['error loading outputDataStructSingle' num2str(completedJobNumber) '.mat']);
    end

    cd(cwd);

    outputDataStruct(completedJobNumber) = outputDataStructSingle;

    if(mod(index,400))
        disp(['collected ' num2str(100*index/length(tTest)) '%']);
    end
    completedJobs = [completedJobs completedJobNumber];
end

completedJobs = unique(completedJobs);
allJobs(completedJobs) = [];


try
    allJobs(1)
    disp(['please run directoryTestPFS.job in order to finish the following jobs:']);
    allJobs
catch
    disp('all jobs are complete and consolidated!');

    fileName = ['outputDataStruct' identifier '.mat'];
    save(fileName,'outputDataStruct');        
    
    [status,result] = system(['cp ' fileName ' $PBS_O_WORKDIR'])

end
