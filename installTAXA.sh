#!/usr/bin/bash

# Everything will be installed here
# The NCBI database is ~40GB so plan accordingly
WORKDIR=/home/scratch

# Install the necessary applications
if [ ! -f taxUpdated ]
then
    yum install vim git bc wget w3m kernel yum-utils ruby mysql mysql-server mysql-libs gcc g++ make automake autoconf curl-devel openssl-devel zlib-devel httpd-devel apr-devel apr-util-devel sqlite-devel ruby-doc ruby-devel rubygems -y
fi


echo "=========== Start mySQL ==========="
service mysqld start

# Probably not necessary
# mysql_secure_installation

if [ ! -f /etc/yum.repos.d/home:tange.repo ]
then
    echo "=========== Install GNU parallel ==========="
    cd /etc/yum.repos.d/
    wget http://download.opensuse.org/repositories/home:/tange/CentOS_CentOS-6/home:tange.repo
    yum install parallel -y
fi

cd $WORKDIR

# Install blast
# This will install the dependencies
if [ ! -f $WORKDIR/ncbi-blast-2.6.0+-1.x86_64.rpm ]
then
    echo "=========== Install Blast Dependencies ============"
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-1.x86_64.rpm
    yum install ncbi-blast-2.6.0+1.x86_64.rpm -y
fi

# Build the package from source
if [ ! -f $WORKDIR/ncbi-blast-2.6.0+-x64-linux.tar.gz ]
then
    echo "=========== Build Blast ==========="
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-x64-linux.tar.gz
    tar xvf ncbi-blast-2.6.0+-x64-linux.tar.gz

    mkdir ncbi-blast-2.6.0+/db
fi

# Skip if all the db files have been downloaded
if [ ! -f $WORKDIR/ncbi-blast-2.6.0+/db/nt.47.tar.gz.md5 ]
then
    cd $WORKDIR/ncbi-blast-2.6.0+/db

    # Update the nt database
    ../bin/update_blastdb.pl nt
    sync

    # Uncompress then all
    FILES=$(find . -type f -name "*.tar.gz")
    for f in $FILEs;
    do tar -xz "$f" .
    done

    cd $WORKDIR
fi

# Get BioSQL
if [ ! -f $WORKDIR/biosql-1.0.1.tar.gz ]
then 
    echo "=========== Download BioSQL ==========="
    wget http://biosql.org/DIST/biosql-1.0.1.tar.gz
    tar -xvf biosql-1.0.1.tar.gz
fi

# Get a default config file
if [ ! -f /etc/my.cnf ]
then
    echo "=========== Creating mySQL Config ============"
    # Could be my-(small, medium, large, or huge)
    cp /usr/share/mysql/my-large.cnf /etc/my.cnf
fi

# Create the DB
if [ ! -d /var/lib/mysql/bioseqdb ]
then 
    echo "=========== Creating Database ============"
    mysqladmin -u root create bioseqdb
fi

# Load the DB
echo "=========== Load BioSQL Database =========="
mysql -u root bioseqdb < $WORKDIR/biosql-1.0.1/sql/biosqldb-mysql.sql


# Update the NCBI taxonomy
if [ ! -f taxUpdated ]
then
    echo "========== Update Taxonomy ==========="
    $WORKDIR/biosql-1.0.1/scripts/load_ncbi_taxonomy.pl --dbname bioseqdb --driver mysql --dbuser root --download true
    echo "Done" >> taxUpdated
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
fi

# Make a directory for storing test output
mkdir testOutput

cd testOutput

# Test the installation
bash $WORKDIR/TAXAassign/TAXAassign.sh -p -c 10 -t 70 -m 60 -a "60,70,80,95,95,97" -f $WORKDIR/TAXAassign/data/test.fasta
