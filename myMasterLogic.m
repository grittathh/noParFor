userID = 'changeThis';
format compact
[status,pbsOWorkDirStr] = system('$PBS_O_WORKDIR')

endIndex = strfind(pbsOWorkDirStr,': is a directory') - 1
startIndex = strfind(pbsOWorkDirStr,['/home/' userID '/']) + length(['/home/' userID '/'])

identifier = pbsOWorkDirStr(startIndex:endIndex)
disp(identifier)

startIndex = strfind(pbsOWorkDirStr,['/home/' userID]);
pbsOWorkDirStr = pbsOWorkDirStr(startIndex:endIndex);
disp(pbsOWorkDirStr)

cd('/scratch/users');
cd(userID);

system(['find ' identifier  ' -prune -exec touch -m {} \;']); %update timestamp
system(['find tempDir1 -prune -exec touch -m {} \;']); %update timestamp
cd(identifier);

matObj = matfile('inputDataStruct.mat');
theFieldName = setxor('Properties',fieldnames(matObj));
theSize = size(matObj,theFieldName{1});

if(sum(theSize == 1) == 1)
    totalNumJobs = max(theSize);
else
    totalNumJobs = theSize(2);
end

activeJobs = [];

cwd = pwd;
usePbsdsh = 1;
workerQueueLength = 60;
iterationsBetweenResets = 150; %not sure this is necessary anymore
numNodes = 20; %12
memPerProc = 2;
numPPN = floor(24/memPerProc); %24/3 = 8. 
                        %24gb is the amount of memory each comp node has. were assuming this
                        %job runs on comp nodes.
maxConcurrentJobs = numNodes*numPPN;

for(index = 1:maxConcurrentJobs)
    %create scratch directories
    cd(cwd)
    tempScratchName = ['scratch' num2str(index)] 
    try
        tstart = tic;
        rmdir(tempScratchName,'s');
        disp(['rmdirred existing scratch directory in ' num2str(toc(tstart)) ' seconds']);
    end

    tstart = tic;
    mkdir(tempScratchName);
    cd(tempScratchName);
    disp(['mkdirred scratch directory in ' num2str(toc(tstart)) ' seconds']);

    tstart = tic;
    %copy all files necessary to run iterations to this particular worker's scratch directory
    system(['cp $PBS_O_WORKDIR/*.m .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.M .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.job .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.sh .'],'-echo');
    system(['cp /scratch/users/' userID '/tempDir1/* .']);
    disp(['copied files to scratch directory in ' num2str(toc(tstart)) ' seconds']);

    system('touch assignedJobs.ndx','-echo');
    system('touch completedJobs.ndx','-echo');
    system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
    system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
    myWorker(index).directory = pwd;
    myWorker(index).immediateJobs = [];
    myWorker(index).previousCompletedJobs = inf;
end

    if(index == 1)
        addpath(pwd)
    end

    if(~usePbsdsh)
        tstart = tic;
        cd(pbsOWorkDirStr)
        submissionString = ['qsub -v OWORKDIR=' pbsOWorkDirStr ...
                            ',SCRATCHDIR=' cwd ...
                            ',USEPBSDSH=' num2str(usePbsdsh) ...
                            ',MY_VNODENUM=' num2str(index-1) ...
                            ' -l nodes=' num2str(1)  ...
                            ':ppn=' num2str(ceil(memPerProc/2)) ...
                            ',mem=' num2str(memPerProc) ...
                            'gb myWorkers.job'];
        
        submissionString
        [status,result] = system(submissionString);
        result
        disp(['qsubbed myWorkers.job in ' num2str(toc(tstart)) ' seconds']);
    end
    
    if(usePbsdsh && (mod(index,12) == 0))
        cd(pbsOWorkDirStr)
        submissionString = ['qsub -v OWORKDIR=' pbsOWorkDirStr ...
                            ',SCRATCHDIR=' cwd ...
                            ',USEPBSDSH=' num2str(usePbsdsh) ...
                            ',MY_VNODENUM=' num2str(index - 11) ...
                            ' -l nodes=' num2str(1)  ...
                            ':ppn=' num2str(12) ...
                            ',mem=' num2str(24) ...
                            'gb myWorkers.job'];
    
        submissionString
        [status,result] = system(submissionString);
        result
    end
end

%if(usePbsdsh)
%    cd(pbsOWorkDirStr)
%    submissionString = ['qsub -v OWORKDIR=' pbsOWorkDirStr ...
%                        ',SCRATCHDIR=' cwd ...
%                        ',USEPBSDSH=' num2str(usePbsdsh) ...
%                        ' -l nodes=' num2str(numNodes)  ...
%                        ':ppn=' num2str(numPPN) ...
%                        ',mem=' num2str(maxConcurrentJobs.*memPerProc) ...
%                        'gb myWorkers.job'];
%    
%    submissionString
%    [status,result] = system(submissionString);
%    result
%end

tOverallStart = tic;
iterations = 0;
prevCompletedJobs = [];
completedJobs = [];
while(1)
    %find completed jobs
    tstart = tic;
    tIterationStart = tic;
    cd(cwd)
    prevCompletedJobs = completedJobs;
    completedJobs = checkNDX('fileTracker.ndx');
    disp(['scanned fileTracker.ndx in ' num2str(toc(tstart)) ' seconds']);

    %find immediate jobs for each worker
    tstart = tic;
    immediateJobs = [];
    maxNumCompletedJobs = 0;
    for(index = 1:maxConcurrentJobs)
        cd(myWorker(index).directory);
        workerCompletedJobs = checkNDX('completedJobs.ndx','.master');
        workerAssignedJobs  = checkNDX('assignedJobs.ndx','.master');
        
        myWorker(index).immediateJobs = setdiff(workerAssignedJobs,completedJobs);
        numCompletedJobs = length(intersect(workerAssignedJobs,completedJobs));
        maxNumCompletedJobs = max([maxNumCompletedJobs numCompletedJobs]);
        disp(['worker ' num2str(index) ' completed ' num2str(numCompletedJobs) ' jobs since last check']);
        %        previousCompletedJobs = length(intersect(myWorker(index).immediateJobs,completedJobs));
        %
        %if(~myWorker(index).previousCompletedJobs && ~previousCompletedJobs)
        %    disp(['worker ' num2str(index) ...
        %          ' hasnt done anything the last 2 times we checked. likely had error writing results to disk']);
        %    disp('resetting worker tracking files');
        %    cd(myWorker(index).directory);
        %    system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
        %    system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
        %    myWorker(index).previousCompletedJobs = inf;
        %    myWorker(index).immediateJobs = [];
        %else
        %    disp(['worker ' num2str(index) ' completed ' num2str(previousCompletedJobs) ...
        %          ' jobs since last check']);
        %    myWorker(index).immediateJobs = setdiff(myWorker(index).immediateJobs,completedJobs);
        %    myWorker(index).previousCompletedJobs = previousCompletedJobs;
        %end
        immediateJobs = [immediateJobs myWorker(index).immediateJobs];

        newAssignedJobName = [];
        for(tempIndex = myWorker(index).immediateJobs)
            newAssignedJobName = [newAssignedJobName 'start' num2str(tempIndex) '\n'];
        end
        system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
        system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
        system(['flock -x assignedJobs.ndx -c '' printf "' newAssignedJobName '" >> assignedJobs.ndx '' ']);

    end
    disp(['scanned all worker NDX files in ' num2str(toc(tstart)) ' seconds']);

    if(isempty(completedJobs))
        completedJobs = [];
    else
        disp(['completed ' num2str(length(completedJobs)) ' jobs at ' ...
              num2str(length(completedJobs)/toc(tOverallStart)) ' jobs per second']);
        lastIterationSpeed = (length(completedJobs) - length(prevCompletedJobs))/toc(tIterationStart);
        disp(['last iteration speed: ' num2str(lastIterationSpeed) ' jobs per second']);
        numJobsPerIterationPerWorker = (length(completedJobs) - length(prevCompletedJobs))/ ...
            maxConcurrentJobs;
        disp(['last iteration jobsPerWorker: ' num2str(numJobsPerIterationPerWorker)]);
        if(length(prevCompletedJobs) ~= 0)
            %if not first iteration...
            %workerQueueLength = max([workerQueueLength ceil(numJobsPerIterationPerWorker * 3)]);
            workerQueueLength = max([workerQueueLength ceil(maxNumCompletedJobs * 2)]);
        end
        disp(['workerQueueLength: ' num2str(workerQueueLength)]);
    end

    iterations = iterations + 1;
    if(iterations > iterationsBetweenResets)
        disp('resetting worker tracking files because of iterationsBetweenResets');
        iterations = 0;
        immediateJobs = [];
        for(index = 1:maxConcurrentJobs)
            cd(myWorker(index).directory);
            system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
            system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
            myWorker(index).immediateJobs = [];
            myWorker(index).previousCompletedJobs = inf;
        end
    end

    if(isempty(immediateJobs))
        immediateJobs = [];
    else
        disp(['there are ' num2str(length(immediateJobs)) ' immediate jobs']);
    end

    jobsToRemove = [completedJobs immediateJobs];

    %get complete list of jobs.
    remainingJobs = 1:totalNumJobs;

    if(~isempty(jobsToRemove))
        if(sum(jobsToRemove < 1))
            jobsToRemove(jobsToRemove < 1) = [];
        end
        remainingJobs(jobsToRemove) = [];
    end

    index = 1;
    newJobName = [];
    while(index <= maxConcurrentJobs)
        tstart = tic;

        if((length(myWorker(index).immediateJobs) < workerQueueLength) && ~isempty(remainingJobs))
            newJobName = [newJobName 'start' num2str(remainingJobs(1)) '\n'];
            myWorker(index).immediateJobs = [myWorker(index).immediateJobs remainingJobs(1)];
            remainingJobs(1) = [];
            continue;
        end
        
        newJobName
        cd(myWorker(index).directory);
        system(['flock -x assignedJobs.ndx -c '' printf "' newJobName '" >> assignedJobs.ndx '' ']);
        disp(['filled worker ' num2str(index) ' in ' num2str(toc(tstart)) ' seconds']);
        index = index + 1;
        newJobName = [];

        if(isempty(remainingJobs))
            break;
        end
    end
    if(isempty(remainingJobs))
        stillActiveJobs = [];
        for(index = 1:maxConcurrentJobs)
            stillActiveJobs = [stillActiveJobs myWorker(index).immediateJobs];            
        end
        if(isempty(stillActiveJobs))
            break; %exit the main while loop
        end
    end
    pause(10)
end

cd(cwd)
cd ..
system(['find ' identifier  ' -prune -exec touch -m {} \;']); %update timestamp
