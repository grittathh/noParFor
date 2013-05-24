This is a pretty specific use case.  You have matlab with institutional license, and access to a cluster running PBS.

Your code has a parfor that looks like this:

parfor(index = 1:length(inputDataStruct))
    output(index) = doSomething(inputDataStruct(index));
end

This code creates a batch job on the cluster that runs doSomething on the pre-computed inputDataStruct.

Advantages over built-in parfor using matlabpool: this method does not use any DCT licenses.