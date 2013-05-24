% function createScratchEnvironment
format compact
[status,result] = system('$PBS_O_WORKDIR')
endIndex = strfind(result,': is a directory') - 1
startIndex = strfind(result,'/home/userid/') + length('/home/userid/')

identifier = result(startIndex:endIndex)
disp(identifier)

cd('/scratch/users');
ls
mkdir(['userid/' identifier]);
cd(['userid/' identifier]);

system('cp $PBS_O_WORKDIR/inputDataStruct.mat .','-echo');
system('rm *.ndx','-echo');
system('touch fileTracker.ndx','-echo');

load('inputDataStruct.mat')

maxDirectoryNumber = ceil(length(inputDataStruct)/1000);
directoryCreationString = '';
for(index = 1:maxDirectoryNumber)
    directoryCreationString = [directoryCreationString ' ' num2str(index)];
end

system(['mkdir ' directoryCreationString]);