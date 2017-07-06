#!/usr/bin/bash

WORKDIR=/sc/orga/projects/clemej05a/wallach

# Set with the password for your DB account
#DBI_PASSWORD=wallad07_db1

module load parallel
module load python
module load py_packages
module load blast


# Remove test directory if it exists
if [ -d $WORKDIR/testOutput ]
then
	rm -rf $WORKDIR/testOutput
fi

# Make a directory for storing test output
mkdir $WORKDIR/testOutput

cd $WORKDIR/testOutput

# Test the installation
bash $WORKDIR/TAXAassign/TAXAassign.sh -p -c 10 -t 70 -m 60 -a "60,70,80,95,95,97" -f $WORKDIR/TAXAassign/data/test.fasta

