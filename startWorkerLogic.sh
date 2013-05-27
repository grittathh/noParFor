#!/bin/bash -login
export PATH=$PATH:$PBS_O_PATH
echo 'inside individual worker'
echo ${PBS_O_WORKDIR}
echo ${OWORKDIR}
echo ${SCRATCHDIR}
echo ${PBS_VNODENUM}

let PBS_VNODENUM=$PBS_VNODENUM+1

echo ${PBS_VNODENUM}

echo "${SCRATCHDIR}/scratch${PBS_VNODENUM}"

cd ${OWORKDIR}
matlab -nodisplay -nosplash -r "myWorkerLogic(${PBS_VNODENUM},'${SCRATCHDIR}')" > \
"${SCRATCHDIR}/scratch${PBS_VNODENUM}/out${PBS_VNODENUM}.out"

echo "myWorkerLogic function has returned"

date

echo "End"
