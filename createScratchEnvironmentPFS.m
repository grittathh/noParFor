% function createScratchEnvironment
userID = 'changeThis';
format compact
[status,result] = system('$PBS_O_WORKDIR')
endIndex = strfind(result,': is a directory') - 1
startIndex = strfind(result,['/home/' userID '/']) + length(['/home/' userID '/'])

identifier = result(startIndex:endIndex)
disp(identifier)

cd('/scratch/users');
ls
mkdir([userID '/' identifier]);
cd([userID '/' identifier]);

system('cp $PBS_O_WORKDIR/inputDataStruct.mat .','-echo');
system('rm *.ndx','-echo');
system('touch fileTracker.ndx','-echo');

matObj = matfile('inputDataStruct.mat');
theFieldName = setxor('Properties',fieldnames(matObj));
theSize = size(matObj,theFieldName{1});

if(sum(theSize == 1) == 1)
    maxDirectoryNumber = ceil(max(theSize) / 1000);
else
    maxDirectoryNumber = ceil(theSize(2)/1000);
end

directoryCreationString = '';
for(index = 1:maxDirectoryNumber)
    directoryCreationString = [directoryCreationString ' ' num2str(index)];
end

system(['mkdir ' directoryCreationString]);