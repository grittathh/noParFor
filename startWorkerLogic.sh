#!/bin/bash -login
export PATH=$PATH:$PBS_O_PATH
echo 'inside individual worker'

if [ $USEPBSDSH -eq 1 ]
then
echo 'yes pbsdsh'
let PBS_VNODENUM=$PBS_VNODENUM+$MY_VNODENUM
export TMPDIR=${SCRATCHDIR}/scratch${PBS_VNODENUM}
else
echo  'no pbsdsh'
let PBS_VNODENUM=$MY_VNODENUM+1
fi


echo ${PBS_VNODENUM}

#printenv

echo "${SCRATCHDIR}/scratch${PBS_VNODENUM}"
echo ${TMPDIR}

cd ${OWORKDIR}
matlab -nodisplay -nosplash -r "myWorkerLogic(${PBS_VNODENUM},'${SCRATCHDIR}'); exit" > \
"${SCRATCHDIR}/scratch${PBS_VNODENUM}/out${PBS_VNODENUM}.out"

echo "myWorkerLogic function has returned"

date

echo "End"
