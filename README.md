This is a pretty specific use case.  You have matlab with institutional license, and access to a cluster running PBS.

Your code has a parfor that looks like this:

    parfor(index = 1:length(inputDataStruct))
        outputDataStruct(index) = doSomething(inputDataStruct(index));
    end

This code creates a batch job on the cluster that runs doSomething on the pre-computed inputDataStruct.

Advantages over built-in parfor using matlabpool:

* does not use any DCT licenses
* easily scales to multiple nodes, multiple processors (in theory, matlabpool and parfor do this. in practice, you need to deal with the limited number of institutional DCT licenses)
* you don't lose data when the communication to workers fails after awhile (may be specific to certain cluster implementations)

Disadvantages over built-in parfor:

* requires additional setup -- you have to copy everything you need to run the job to a directory on the cluster before you can begin.
* does use additional non-DCT matlab licenses, but this is one per node, not one per processor
* uses a few script files
* in current form, requires /scratch/ directory (may be specific to certain cluster implementations)

Setup:

* save inputDataStruct as "inputDataStruct.mat"
* copy this along with the .m files you need to run your job to a directory on the cluster. Note this should be a unique directory name...the script will create a subdirectory in /scratch/users/userid/ with the same name.
* copy the .job, .sh, and .m files of noParFor into the same directory
* run "qsub createScratchEnvironmentPFS.job"
* when it's done, run "qsub directoryTestPFS_multi.job"
* this should spawn myMulti2.job
* when all the jobs are done, manually kill myMulti2.job
* collect results by running "qsub directoryConsolidatePFS.job"
* copy the outputDataStruct.mat to your local computer, done.
