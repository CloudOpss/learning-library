#!/bin/bash

# keep track of script usage with a simple curl query
# the remote host runs nginx and uses a javascript function to mask your public ip address
# see here for details: https://www.nginx.com/blog/data-masking-user-privacy-nginscript/
#
file_path=`realpath "$0"`
curl -Is --connect-timeout 3 http://150.136.21.99:6868${file_path} > /dev/null


# generate an output based on the script name
outfile=$(basename -s .sh $0)".out"
#echo $outfile
rm -f $outfile 2>&1
exec > >(tee -a $outfile) 2>&1

if [ -z "$1" ]; then
 echo
 echo
 echo "You did not include a PDB name for master key creation."
 echo "Press [return] to continue."
 echo
 exit 1
else
 pdb_name=$1
 echo
 echo
fi

CURDATE="`date +%Y%m%d_%H%M`"
TAG_DATA="${pdb_name}: Master Key rekey on ${CURDATE}"
echo $TAG_DATA


echo
echo "Rekey the master key for the pluggable database ${pdb_name} ..."
echo

sqlplus -s / as sysdba <<EOF
--
set lines 140
set pages 9999
column wrl_type format a12
column wrl_parameter format a40
column activation_time format a36
column key_id format a36
column pdb_name format a10
column tag format a52
--
alter session set container=${pdb_name};
show con_name;
--
select a.con_id, b.name pdb_name, a.wrl_type, a.wrl_parameter, a.status from v\$encryption_wallet a, v\$containers b where a.con_id=b.con_id order by a.con_id;
--
ADMINISTER KEY MANAGEMENT SET KEY USING TAG '${TAG_DATA}' FORCE KEYSTORE IDENTIFIED BY Oracle123 WITH BACKUP container=current;
--
select a.con_id, b.name pdb_name, a.wrl_type, a.wrl_parameter, a.status from v\$encryption_wallet a, v\$containers b where a.con_id=b.con_id order by a.con_id;
--
--
select b.name pdb_name, a.key_id, a.activation_time, a.tag from v\$encryption_keys a, v\$containers b where a.con_id=b.con_id order by a.con_id, a.activation_time;
--
EOF
