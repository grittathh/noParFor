noParFor: distribute matlab parfor iterations on PBS without using the distributed computing toolbox
----------

You have matlab with institutional license, and access to a cluster running PBS.

Your code has a parfor that looks like this:

    parfor(index = 1:length(inputDataStruct))
        outputDataStruct(index) = doSomething(inputDataStruct(index));
    end

You are running your parfor using a local matlabpool but find that when you expand to a larger matlabpool running on the cluster, you run out of licenses or run into communication problems.  noParFor may be for you.  This code creates a batch job on the cluster that runs `doSomething` on the pre-computed inputDataStruct.

Advantages over built-in parfor using matlabpool:

* does not use any DCT licenses
* easily scales to multiple nodes, multiple processors (in theory, matlabpool and parfor do this. in practice, you need to deal with the limited number of institutional DCT licenses)
* you don't lose data when the communication to workers fails after awhile (may be specific to certain cluster implementations)

Disadvantages over built-in parfor:

* requires additional setup
* does use additional non-DCT matlab licenses, but this is one per node, not one per processor
* uses a few script files
* in current form, requires /scratch/ directory (may be specific to certain cluster implementations)

Advantages over using regular script to submit many jobs in sequence:
* with noParFor you maximize the usage of matlab licenses. matlab counts one license per node-user. Therefore, it makes sense to fit as many jobs into each node as possible. Instead of relying on the cluster schefuler to do this, you can force this to happen by using noParFor.

How to use this
----------

* save inputDataStruct as "inputDataStruct.mat"
* change the 'changeThis' fields at the top of some of the .m files to match your userid on the cluster.
* copy this along with doSomething.m and all its dependencies to a directory on the cluster. We'll call this the *OWORKDIR*. Note this should be a unique directory name...the script will create a subdirectory in /scratch/users/userid/ with the same name.
* copy the noParFor .job, .sh, and .m files into the same directory
* run "qsub createScratchEnvironmentPFS.job" from *OWORKDIR*
* when it's done, run "qsub myMaster.job" from *OWORKDIR*
* this should spawn myWorkers.job
* when all the jobs are done, **manually** kill myWorkers.job
* collect results by running "qsub consolidateOutput.job" from *OWORKDIR*
* copy the outputDataStruct.mat from *OWORKDIR* to your local computer.
* done!

How it works
-----------

* createScratchEnvironmentPBS creates a set of subdirectories as well as a main tracking file to track progress through the parfor loop.
* each worker instance writes one output file (a single outputDataStruct.mat file) per iteration, to the right subdirectory.
* each subdirectory will hold 1000 output .mat files
* myMaster.job (the "master" job) copies the contents of *OWORKDIR* to worker "working" directories, one per worker: /scratch/users/userid/identifier/scratchN where N is the Nth worker. Each worker's output is logged as a .out file in this directory.
* each worker is a processor of myWorkers.job (a vnode). each node runs myWorkerLogic.m via startWorkerLogic.sh, via pbsdsh.
* workers sit around waiting for the master job to assign an iteration to work on. to do this, the master job simply adds a line to the end of the worker's assignedJobs.ndx file.
* each worker has a assignedJobs.ndx file and a completedJobs.ndx file. the master job makes sure each worker has 30 more assigned jobs than completed jobs.
* when each worker completes a job (iteration), it writes a single outputDataStruct .mat file to the right subfolder under /scratch/users/userid/identifier, adds a line its own completedJobs.ndx file, and adds a line to the master job's tracking file.
* the "master" job keeps assigning jobs to workers until a valid entry is written to the tracking file for every iteration, until all iterations are completed.


Inspired by
-----------

Case Western HPCC https://sites.google.com/a/case.edu/hpc-upgraded-cluster/  
MSU HPCC https://wiki.hpcc.msu.edu/display/hpccdocs/MATLAB+Licenses
