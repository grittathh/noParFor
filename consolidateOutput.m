userID = 'changeThis';
format compact
[status,result] = system('$PBS_O_WORKDIR')
if(~isempty(result))
    endIndex = strfind(result,': is a directory') - 1;
    startIndex = strfind(result,['/home/' userID '/']) + length(['/home/' userID '/']);
    identifier = result(startIndex:endIndex);
else
    [~,identifier,~] = fileparts(pwd);
end
disp(identifier)

% pwd
% addpath(pwd)


cd('/scratch/users');
ls
cd([userID '/' identifier]);
cwd = pwd;

cd('scratch1')
addpath(pwd)
cd ..

inputObj = matfile('inputDataStruct.mat');
theFieldName = setxor('Properties',fieldnames(inputObj));
theSize = size(inputObj,theFieldName{1});
clear inputObj;

fileName = ['outputDataStruct' identifier '.mat'];
% matObj = matfile(fileName,'Writable',true);


if(sum(theSize == 1) == 1)
    maxDirectoryNumber = ceil(max(theSize) / 1000);
else
    maxDirectoryNumber = ceil(theSize(2)/1000);
end

totalJobs = max(theSize);

%get complete list of jobs.
allJobs = 1:totalJobs;
    
%find completed jobs
tstart = tic;
completedJobs = checkNDX('fileTracker.ndx');
disp(['scanned fileTracker.ndx in ' num2str(toc(tstart)) ' seconds']);

incompleteJobs = setdiff(allJobs,completedJobs);
if(~isempty(incompleteJobs))
    disp(['please run directoryTestPFS.job in order to finish the following jobs:']);
    incompleteJobs
    exit
end


tOverallStart = tic;
try
    matlabpool close force
end
matlabpool open local 12
warning off MATLAB:mir_warning_maybe_uninitialized_temporary

overallErrorVector = [];

for(directoryNumber = 1:maxDirectoryNumber)
    tstart = tic;
    cd(cwd)
    cd(num2str(directoryNumber));
    fileNames=eval('java.io.File(pwd).list()');
    disp(['found all filenames in ' num2str(toc(tstart)) ' seconds']);

    tstart = tic;
    outputDataStructInit = loadOutputStruct(char(fileNames(1)));
    matObj_index = zeros(1,length(fileNames));
    matObj_brIndex = zeros(1,length(fileNames));
    errorVector = zeros(1,length(fileNames));

    canSafelySkip = 0;
    for(index = 1:length(fileNames))
        if(isequal(char(fileNames(index)),fileName))
            disp(['already loaded directory ' num2str(directoryNumber) ' before, moving on']);
            canSafelySkip = 1;
            break;
        end
    end
    
    if(canSafelySkip)
        cd ..
        continue;
    end

    parfor(parIndex = 1:length(fileNames)) %par
        cd(cwd);
        cd(num2str(directoryNumber));
        try
            outputDataStructSingle = loadOutputStruct(char(fileNames(parIndex)));
        catch
            %error handling
            disp(['error loading ' char(fileNames(parIndex))]);
            outputDataStructSingle = outputDataStructInit;
            jobNumber = regexp(char(fileNames(parIndex)),'\d+','match');
            errorVector(parIndex) = jobNumber{1};
            outputDataStructSingle.index = jobNumber;
            outputDataStructSingle.brIndex = nan;
        end
        
        if(~isstruct(outputDataStructSingle))
            disp('error not struct?');
        end

        %outputDataStructSingle

        matObj_index(parIndex) = outputDataStructSingle.index;
        matObj_brIndex(parIndex) = outputDataStructSingle.brIndex;
    end
    overallErrorVector = [overallErrorVector errorVector(errorVector > 0)];

    if(sum(errorVector) > 0)
        disp('found error, skipping directory');
        cd ..
        continue;
    end
    %[msglast,msgidlast] = lastwarn

    [completedJobNumberVector,I] = sort(matObj_index.');
    if(sum(diff(diff(completedJobNumberVector))) ~= 0)
        disp('this should not happen');
    end

    completedJobNumberVectorOverall = completedJobNumberVector;
    completedJobNumberVector = completedJobNumberVector - completedJobNumberVector(1) + 1;

  
    matObj.index(completedJobNumberVector,1) = matObj_index(I).';
    matObj.brIndex(completedJobNumberVector,1) = matObj_brIndex(I).';



    disp(['loaded directory ' num2str(directoryNumber) ' in ' num2str(toc(tstart)) ' seconds']);
    disp(['collected ' num2str(completedJobNumberVectorOverall(end)) ...
          ' of '       num2str(totalJobs) ...
          ', '         num2str(100*completedJobNumberVectorOverall(end)/totalJobs) ...
          '% at '      num2str(length(completedJobNumberVector)/toc(tstart)) ...
          ' jobs per second']);

    %'% at '      num2str(completedJobNumberVectorl(end)/toc(tOverallStart)) ...
    %      ' jobs per second']);

    %    tic; save(fileName,'matObj','-v7.3'); toc
    tic; save(fileName,'matObj'); toc
    cd ..
end
%%
%load everything
for(directoryNumber = 1:maxDirectoryNumber)
    if(directoryNumber == 1)
        tstart = tic;
        clear matObjFinal;
        matObjFinal.index(allJobs(end),1) = uint32(0);
        matObjFinal.brIndex(allJobs(end),1) = uint8(0);
    end
    tstart = tic;
    cd(cwd)
    cd(num2str(directoryNumber));
    fileNames=eval('java.io.File(pwd).list()');
    disp(['   found all filenames in ' num2str(toc(tstart)) ' seconds']);
    loadedMatObj = 0;
    for(index = 1:length(fileNames))
        if(isequal(fileName,char(fileNames(index))))
            load(fileName)
            loadedMatObj = 1;
            break;
        end
    end
    
    if(~loadedMatObj)
        disp('directory matObj was not found');
        disp('how to handle this case?');
    end

    for(index = 2:length(matObj.index))
        if(matObj.index(index) == 0)
            matObj.index(index) = matObj.index(index-1) + 1;
                matObj.brIndex(index) = nan;
        end
    end
    if(matObj.index(1) == 0)
        matObj.index(1) = matObj.index(2) - 1;
        matObj.brIndex(index) = nan;
    end
    try
        matObjFinal.index(matObj.index,1) = matObj.index;
    catch
        size(matObj.index)
        matObj.index
        keyboard
    end

    matObjFinal.brIndex(matObj.index,1) = matObj.brIndex;



    disp(['finished directory ' num2str(directoryNumber) ' in '  num2str(toc(tstart)) ' seconds']);
end

%%
%check if anything is missing. should only happen if there was a missing file for a job that was
%listed as complete in the fileTracker.ndx file

erroredJobs = matObjFinal.index(isnan(matObjFinal.brIndex));
if(~isempty(erroredJobs))
    
    for(index = erroredJobs)
        cd(cwd)
        cd(num2str(ceil(index/1000)));
        [~,result] = system(['rm ' fileName]);
        disp(result);
    end

    allJobs(erroredJobs) = [];
    cd(cwd)
    
    fileID = fopen('fileTracker.ndx','w');
    fprintf(fileID,'outputDataStructSingle%d.mat\n',allJobs);
    fclose(fileID);
    disp('rerun myMaster.job');
else
    disp('all jobs are complete');
    
    cd(cwd)
    matObj = matObjFinal;
    %tic; save(fileName,'matObj','-v7.3'); toc
    tempParam1 = rmfield(outputDataStructInit.params,paramFieldsToRemove);
    tic; savefast(fileName,'matObj','tempParam1'); toc
    [status,result] = system(['cp ' fileName ' $PBS_O_WORKDIR'])
end
