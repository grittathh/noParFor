This is a pretty specific use case.  You have matlab with institutional license, and access to a cluster running PBS.

Your code has a parfor that looks like this:

    parfor(index = 1:length(inputDataStruct))
        output(index) = doSomething(inputDataStruct(index));
    end

This code creates a batch job on the cluster that runs doSomething on the pre-computed inputDataStruct.

Advantages over built-in parfor using matlabpool:

* does not use any DCT licenses
* easily scales to multiple nodes, multiple processors
* you don't lose data when the communication to workers fails after awhile (may be specific to certain cluster implementations)

Disadvantages over built-in parfor:

* requires additional setup
* does use additional non-DCT matlab licenses, but this is one per node, not one per processor
* uses a few script files
* in current form, requires /scratch/ directory (may be specific to certain cluster implementations)
