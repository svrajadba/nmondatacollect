#!/bin/ksh
# input validation
if [ $# -lt 2 ];
then
    echo "Expecting atleast 2 inputs.
          1. CLIENT or MASTER
          2. SAMPLE FREQUENCY IN SECONDS"; exit 1;
elif [ $# -eq 2 ];
then
    if [[ "$1" == "MASTER" ]]; then
        echo "Expecting atleast 3 inputs for MASTER nmon node.
                1. CLIENT or MASTER
                2. SAMPLE FREQUENCY IN SECONDS
                3. RAW DATA RETENTION IN DAYS"; exit 1;
    fi
fi

# verify needed binary found and are accessible

which nmcli >/dev/null 2>&1 || echo "nmcli isnt found, please install;" exit 1;



# variable declaration below
# nmon deployment type below
export instyp=$1;
# nmon sample frequency below
export smpfrq=$2;
# nmon raw data retention window
export dtrtn=$3;

# directory definations
basdir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export basdir;
hrdir=${basdir}/rawdata;
export hrdir;
daydir=${basdir}/daydata;
export daydir;
chartop=${basdir}/nmonchartop;
export chartop;
bindir=${basdir}/nmonbin;
export bindir;

# NMON Flow
# nmondata/rawdata/<hst>/<hr>.nmon > nmonmerge > nmondata/daydata/<hst>_<day>.nmon > nmonchart > nmonchartop/<hst>/<day>.html

startnmon ()
{
cd ${hrdir}/${hstip};
numsmp=$(echo "300/${smpfrq}" | bc);
nmon -f -tT -s${smpfrq} -c${numsmp};
#nmonpid=$!;
#export nmonpid;
#echo "nmonprocess_id: " ${nmonpid} > ./nmonpidfile.out;
}

mergefile ()
{
cd ${daydir};
for i in $(find ${hrdir}/${hstip}/ -maxdepth 1 -name '*.nmon' -print)
do
    dy=$(echo ${i}|cut -d '_' -f 2);
    if ! [ -f ./${hstip}_${dy}.nmon ]; then
        cp $i ./${hstip}_${dy}.nmon;
    else
        $basdir/nmonbin/nmonmrg/nmonmerge -a ./${hstip}_${dy}.nmon $i;
    fi
#    fmod=$(date -r ${i} +%s);
#    cudt=$(date +%s);
#    fage=$(echo "${cudt} - ${fmod}" | bc);
#    if [ ${fage} -gt 4000 ]; then
        mv $i $i.done 2>/dev/null;
#    fi
done
}

genhtml()
{
cd ${daydir};
for i in $(ls -tr *.nmon 2>/dev/null);
do
    phst=$(echo ${i}|cut -d '_' -f 1);
    flnm=$(echo ${i}|cut -d '_' -f 2|cut -d '.' -f 1);
    ls -ld ${chartop}/${phst} >/dev/null 2>&1 || mkdir ${chartop}/${phst};
    $basdir/nmonbin/nmonchrt/nmonchart $i ${chartop}/${phst}/${flnm}.html;
    fmod=$(date -r ${i} +%s);
    cudt=$(date +%s);
    fage=$(echo "${cudt} - ${fmod}" | bc);
    if [ ${fage} -gt 86500 ]; then
        mv $i $i.done 2>/dev/null;
    fi
done
}

filemaintain()
{
cd ${hrdir};
find . -maxdepth 2 -mtime +${dtrtn} -print > ./hrfilelist_$(date '+%d%m%y%H%M%S').out;
find . -maxdepth 2 -mtime +${dtrtn} -delete;
cd ${daydir};
find . -maxdepth 1 -mtime +${dtrtn} -print > ./dayfilelist_$(date '+%d%m%y%H%M%S').out;
find . -maxdepth 1 -mtime +${dtrtn} -delete;
}

# Main function routine below

# irrespective weather its client or master, we need the nmon process kicked off.

# identify the host ip for the data collection

numint=$(nmcli device status|grep -Ev "lo|DEVICE"|awk '{print $1}'|wc -l);
if [ ${numint} -ne 1 ]; then
    echo "More than 1 interface found"; exit 1;
fi
inm=$(nmcli device status|grep -Ev "lo|DEVICE"|awk '{print $1}');
hstip=$(/usr/sbin/ip a|grep ${inm}|grep inet|awk '{print $2}'|cut -d '/' -f 1);
export hstip;

# let us merge files which were already generated

echo "merging files:";
mergefile;

# let us process the nmon output files here

if [[ "${instyp}" == "MASTER" ]]; then
echo "Merging nmon files";
genhtml;
filemaintain;
fi

# nmon start routine on local machine

echo "Verify if nmon is already running with options we need...";
nmnstr=$(echo "nmon -f -tT -s${smpfrq} -c${numsmp}");
pcnt=$(ps -ef|grep -- '${nmnstr}'|grep -v grep|wc -l);
if [ ${pcnt} -eq 0 ]; then
    echo "starting nmon:"
    startnmon;
    echo "nmon started"
else
    nmonprid=$(ps -ef|grep ${nmnstr}|awk '{print $2}');
    echo "nmon is already running under pid ${nmonprid}.Thanks";
fi


# This closes the main function routine
