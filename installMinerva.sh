#!/usr/bin/bash

# Everything will be installed here
# The NCBI database is ~40GB so plan accordingly
# BioSQL will require an active account on the HPC SQL server
# Change this to run on a different account / different location
WORKDIR=/sc/orga/projects/clemej05a/wallach
USER=wallad07
DBI_USER=wallad07_db1
# Set with the password for your DB account
#DBI_PASSWORD=wallad07_db1

module load bioperl
module load parallel
module load CPAN
module load blast

cd $WORKDIR

# Build the package from source
if [ ! -d $WORKDIR/ncbi-blast-2.6.0+ ]
then
    echo "=========== Build Blast ==========="
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-x64-linux.tar.gz
    tar xvf ncbi-blast-2.6.0+-x64-linux.tar.gz
    rm -f ncbi-blast-2.6.0+-x64-linux.tar.gz

    mkdir ncbi-blast-2.6.0+/db
fi

# Skip if all the db files have been downloaded
if [ ! -f $WORKDIR/ncbi-blast-2.6.0+/db/nt.47.tar.gz.md5 ]
then
    cd $WORKDIR/ncbi-blast-2.6.0+/db

    # Update the nt database
    ../bin/update_blastdb.pl nt
    sync

#3 Uncompress all the archives
    for f in *.tar.gz; do
    tar -zxvf "$f";
    done

    cd $WORKDIR
fi

# Get the latest version of BioSQL
if [ ! -d $WORKDIR/biosql ]
then 
    git clone https://github.com/biosql/bioql
    cd biosql
    sqlite3 database.sqlite3 < biosqldb-sqlite.sql
fi

# Clone the TAXAassign repo
if [ ! -d $WORKDIR/TAXAassign ]
then 
    echo "=========== Clone TAXAassign ==========="
    git clone https://github.com/umerijaz/TAXAassign $WORKDIR/TAXAassign

    # Modify the run script to use the install location
    sed -i "s|\`pwd\`|${WORKDIR}/TAXAassign|" $WORKDIR/TAXAassign/TAXAassign.sh
    sed -i "s|/home/opt/ncbi\-blast\-2\.2\.28|${WORKDIR}/ncbi\-blast\-2\.6\.0|" $WORKDIR/TAXAassign/TAXAassign.sh
    sed -i "s|/home/opt/ncbi\-blast\-2\.2\.28|${WORKDIR}/ncbi\-blast\-2\.6\.0|" $WORKDIR/TAXAassign/TAXAassign.sh

    # Modfiy the python script to use sqlite3 instead of MySQL
    sed -i "s|use_MySQL=True|use_MySQL=False|" $WORKDIR/TAXAassign/scripts/blast_concat_taxon.py
fi

# Get the sqlite3 database
if [ ! -f $WORKDIR/TAXAassign/database/db.sqlite ]
then
    cd TAXAassign
    mkdir database
    cd database
    wget http://userweb.eng.gla.ac.uk/umer.ijaz/bioinformatics/db.sqlite.gz
    gunzip sqlite.db.gz
    cd $WORKDIR
fi

# Update the NCBI taxonomy
if [ ! -f taxUpdated ]
then
    echo "========== Update Taxonomy ==========="
    $WORKDIR/biosql/scripts/load_ncbi_taxonomy.pl --dbname $WORKDIR/TAXAassign/database/db.sqlite --driver SQLite --dbuser $USER --download true
    echo "Done" >> taxUpdated
fi

# Remove test directory if it exists
if [ -d testOutput ]
then
	rm -rf testOutput
fi

# Make a directory for storing test output
mkdir testOutput

cd testOutput

# Test the installation
bash $WORKDIR/TAXAassign/TAXAassign.sh -p -c 10 -t 70 -m 60 -a "60,70,80,95,95,97" -f $WORKDIR/TAXAassign/data/test.fasta
