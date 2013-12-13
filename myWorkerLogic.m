function myWorkerLogic(vNodeNum,scratchDir)
disp('in myWorkerLogic.m')
disp(num2str(vNodeNum))
disp(scratchDir)
%echo "$NUMPROCS"

cd(scratchDir)
cd(['scratch' num2str(vNodeNum)])
ls
pwd
disp(pwd)

format compact
%[status,result] = system('$NUMPROCS')
%numProcs = textscan(result,'/bin/bash: %d');
%numProcs = numProcs{1}
%maxNumCompThreads(numProcs)
maxNumCompThreads(1)

cwd = pwd;
disp('loading inputDataStruct');

matObj = matfile('inputDataStruct.mat');
theFieldName = setxor('Properties',fieldnames(matObj));
theSize = size(matObj,theFieldName{1});

disp('loaded');

while(1)
    [~,result] = system('[ -e kill.txt ] && echo "true" || echo "false"');
    
    if(~isempty(strfind(result,'true')))
        disp('found kill.txt, attempting a graceful exit');
        return;
    end

    tstart = tic;

    end
    completedJobs = checkNDX('completedJobs.ndx');
    assignedJobs  = checkNDX('assignedJobs.ndx');
 
    immediateJobs = setdiff(assignedJobs,completedJobs);
    disp(['rechecked index files in ' num2str(toc(tstart)) ' seconds']);

    if(isempty(immediateJobs))
        disp('No immediateJobs, nothing to do, waiting for new assignment...');
        pause(1);
        continue;
    end

    while(~isempty(immediateJobs))
    
    if(sum(theSize == 1) == 1)
        inputDataStructSingle = matObj.(theFieldName{1})(immediateJobs(1));
    else
        inputDataStructSingle = matObj.(theFieldName{1})(:,immediateJobs(1));
    end
    end
    inputDataStructSingle = inputDataStruct(immediateJobs(1))
    toc
    tic
    tstart = tic;
	try
	    disp('starting new iteration');
	    outputDataStructSingle = doSomething(inputDataStructSingle)
	    disp('done with clusterTSsim');
	    outputFileName = ['outputDataStructSingle' num2str(immediateJobs(1)) '.mat'];
	catch
	    disp('error!')
	    outputDataStructSingle.index = immediateJobs(1);
	    outputDataStructSingle.message = 'errored';
	    outputFileName = ['errored' num2str(immediateJobs(1)) '.mat'];
	end

    workDir = pwd;
    cd ..
    tempDirName = num2str(ceil(immediateJobs(1)/1000));
    
    cd(tempDirName);
    save(outputFileName,'outputDataStructSingle');
    cd ..
    system(['flock -x fileTracker.ndx -c '' echo ' outputFileName ' >> fileTracker.ndx '' ']);
    cd(workDir)
    system(['flock -x completedJobs.ndx -c '' echo ' outputFileName ' >> completedJobs.ndx '' ']);

    toc
    tic
end
    disp(['finished job ' num2str(immediateJobs(1)) ' in ' num2str(toc(tstart)) ' seconds']);
    immediateJobs(1) = [];

    end
    %system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
    %system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
end