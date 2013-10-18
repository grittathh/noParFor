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

load('inputDataStruct.mat')
activeJobs = [];

cwd = pwd;
numNodes = 15;  %change this to set how many nodes you want to use
memPerProc = 5; %change this to set how much memory each processor needs.
                %2 gigs per processor is the optimal number but if your job runs out of memory
                %you may need a larger number
numPPN = floor(24/memPerProc); %24/3 = 8.
                        %24gb is the amount of memory each comp node has. were assuming this
                        %job runs on comp nodes that contain 12 processors. 
                        %8 processors of each of 5 comp nodes will be used for this job.
                        %the scheduler should not schedule any more jobs on the remaining 4 processors
                        %because we requested all of the memory on each of the nodes.
maxConcurrentJobs = numNodes*numPPN;

for(index = 1:maxConcurrentJobs)
    %create scratch directories
    cd(cwd)
    tempScratchName = ['scratch' num2str(index)] 
    try
        rmdir(tempScratchName,'s');
    end
    mkdir(tempScratchName);
    cd(tempScratchName);
    
    %copy all files necessary to run iterations to this particular worker's scratch directory
    system(['cp $PBS_O_WORKDIR/*.m .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.M .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.job .'],'-echo');
    system(['cp $PBS_O_WORKDIR/*.sh .'],'-echo');
    system(['cp /scratch/users/' userID '/tempDir1/* .']);

    
    %finish setting up the worker

    system('touch assignedJobs.ndx','-echo');
    system('touch completedJobs.ndx','-echo')
    myWorker(index).directory = pwd;
    myWorker(index).immediateJobs = [];
    myWorker(index).previousCompletedJobs = inf;
end


cd(pbsOWorkDirStr)
%launch the workers
submissionString = ['qsub -v OWORKDIR=' pbsOWorkDirStr ...
                    ',SCRATCHDIR=' cwd ...
                    ' -l nodes=' num2str(numNodes)  ...
                    ':ppn=' num2str(numPPN) ...
                    ',pmem=' num2str(memPerProc) ...
                    'gb,mem=' num2str(maxConcurrentJobs.*memPerProc) ...
                    'gb myWorkers.job'];

submissionString
[status,result] = system(submissionString);
result

while(1)
    %find completed jobs
    cd(cwd)
    completedJobs = [];
    system('flock -x fileTracker.ndx -c '' cp fileTracker.ndx fileTrackerTemp.ndx '' ');
    fid = fopen('fileTrackerTemp.ndx');
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

        completedJobs = [completedJobs str2num(numToAdd{1})];
    end
    completedJobs = unique(completedJobs);

    %find immediate jobs for each worker
    immediateJobs = [];
    for(index = 1:maxConcurrentJobs)
        previousCompletedJobs = length(intersect(myWorker(index).immediateJobs,completedJobs));

        if(~myWorker(index).previousCompletedJobs && ~previousCompletedJobs)
            disp(['worker ' num2str(index) ' hasnt done anything the last 2 times we checked. likely had error writing results to disk']);
            disp('resetting worker tracking files');
            cd(myWorker(index).directory)
            system('flock -x completedJobs.ndx -c '' > completedJobs.ndx '' ');
            system('flock -x assignedJobs.ndx -c '' > assignedJobs.ndx '' ');
            myWorker(index).previousCompletedJobs = inf;
            myWorker(index).immediateJobs = [];
        else
            disp(['worker ' num2str(index) ' completed ' num2str(previousCompletedJobs) ' jobs since last check']);
            myWorker(index).immediateJobs = setdiff(myWorker(index).immediateJobs,completedJobs);
            myWorker(index).immediateJobs
            myWorker(index).previousCompletedJobs = previousCompletedJobs;
        end
        immediateJobs = [immediateJobs myWorker(index).immediateJobs];
    end

    if(isempty(completedJobs))
        completedJobs = [];
    else
        disp(['completed ' num2str(length(completedJobs)) ' jobs']);
    end

    if(isempty(immediateJobs))
        immediateJobs = [];
    else
        disp(['there are ' num2str(length(immediateJobs)) ' immediate jobs']);
    end

    jobsToRemove = [completedJobs immediateJobs];

    %get complete list of jobs.
    remainingJobs = 1:length(inputDataStruct);

    if(~isempty(jobsToRemove))
        if(sum(jobsToRemove < 1))
            jobsToRemove(jobsToRemove < 1) = [];
        end
        remainingJobs(jobsToRemove) = [];
    end

    index = 1;
    while(index <= maxConcurrentJobs)
        if(isempty(remainingJobs))
            break;
        end
        if(length(myWorker(index).immediateJobs) > 30)
             disp(['worker ' num2str(index) ' is full']);
             myWorker(index).immediateJobs
            index = index + 1;
            continue;
        end
        cd(myWorker(index).directory);
        disp(['starting job ' num2str(remainingJobs(1)) ' on worker ' num2str(index)]);
        newJobName = ['start' num2str(remainingJobs(1))];
        system(['flock -x assignedJobs.ndx -c '' echo ' newJobName ' >> assignedJobs.ndx '' ']);
        myWorker(index).immediateJobs = [myWorker(index).immediateJobs remainingJobs(1)];
        remainingJobs(1) = [];
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
