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
%cd $PBS_O_WORKDIR
%module load matlabR2011b
%date
%matlab -nodesktop
format compact
%[status,result] = system('$NUMPROCS')
%numProcs = textscan(result,'/bin/bash: %d');
%numProcs = numProcs{1}
%maxNumCompThreads(numProcs)
maxNumCompThreads(1)

tic
cwd = pwd;
cd ..
disp('loading inputDataStruct');
load('inputDataStruct.mat');
disp('loaded');
cd(cwd)

while(1)
    %find completed jobs
    completedJobs = [];
    system('flock -x completedJobs.ndx -c '' cp completedJobs.ndx completedJobsTemp.ndx '' ');
    completedFID = fopen('completedJobsTemp.ndx');
    completedTest = textscan(completedFID,'%s');
    fclose(completedFID);
    completedTest = completedTest{1};
    for(index = 1:length(completedTest))
        str = completedTest{index};
        numToAdd = regexp(str,'\d+','match');
        completedJobs = [completedJobs str2num(numToAdd{1})];
    end
    completedJobs = unique(completedJobs);

    %find assigned jobs
    assignedJobs = [];
    system('flock -x assignedJobs.ndx -c '' cp assignedJobs.ndx assignedJobsTemp.ndx '' ');
    assignedFID = fopen('assignedJobsTemp.ndx');
    assignedTest = textscan(assignedFID,'%s');
    fclose(assignedFID);
    assignedTest = assignedTest{1};
    for(index = 1:length(assignedTest))
        str = assignedTest{index};
        numToAdd = regexp(str,'\d+','match');
        assignedJobs = [assignedJobs str2num(numToAdd{1})];
    end
    assignedJobs = unique(assignedJobs);

    if(sum(assignedJobs) < 0)
       exit
    end
 
    immediateJobs = setdiff(assignedJobs,completedJobs);

    if(isempty(immediateJobs))
       pause(1);
       continue;
    end
    inputDataStructSingle = inputDataStruct(immediateJobs(1))
    toc
    tic
	try
	    disp('starting new iteration');
	    outputDataStructSingle = clusterTSsim(inputDataStructSingle)
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