#!/bin/bash -login
export PATH=$PATH:$PBS_O_PATH
echo 'inside spawned job'
echo ${PBS_O_WORKDIR}
echo ${OWORKDIR}
echo ${SCRATCHDIR}
echo ${PBS_VNODENUM}

let PBS_VNODENUM=$PBS_VNODENUM+1

echo ${PBS_VNODENUM}

echo "${SCRATCHDIR}/scratch${PBS_VNODENUM}"

cd ${OWORKDIR}
matlab -nodisplay -nosplash -r "myTask(${PBS_VNODENUM},'${SCRATCHDIR}')" > \
"${SCRATCHDIR}/scratch${PBS_VNODENUM}/out${PBS_VNODENUM}.out"

echo "echo after myTask line"
date

echo "End"
