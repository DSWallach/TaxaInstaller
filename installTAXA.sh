#!/usr/bin/bash

# Everything will be installed here
WORKDIR=/home/scratch

# FOR VM
#cd /etc/sysconfig/network-scripts/

#sed -i "DNS1=8.8.8.8" ifcfg-eth0
#sed -i "DNS2=8.8.4.4" ifcfg-eth0

#yum groupinstall "Development Tools" -y

yum install vim git wget w3m kernel yum-utils ruby mysql mysql-server gcc g++ make automake autoconf curl-devel openssl-devel zlib-devel httpd-devel apr-devel apr-util-devel sqlite-devel ruby-doc ruby-devel rubygems -y

echo "Ensure mySQL is started"
service mysqld start

# Probably not necessary
# mysql_secure_installation

if [ ! -f /etc/yum.repos.d/home:tange.repo ]
then
    echo "Install GNU parallel"
    cd /etc/yum.repos.d/
    wget http://download.opensuse.org/repositories/home:/tange/CentOS_CentOS-6/home:tange.repo
    yum install parallel -y
fi

cd $WORKDIR

# Install blast
# This will install the dependencies
if [ ! -f ncbi-blast-2.6.0+-1.x86_64.rpm ]
then
    echo "Install blast"
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-1.x86_64.rpm
    yum install ncbi-blast-2.6.0+1.x86_64.rpm
fi

# Build the package from source
if [ ! -f ncbi-blast-2.6.0+-x64-linux.tar.gz ]
then
    echo "=========== Build Blast ==========="
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.6.0/ncbi-blast-2.6.0+-x64-linux.tar.gz
    tar xvf ncbi-blast-2.6.0+-x64-linux.tar.gz

    # Update the nt database
    sh ncbi-blast-2.6.0+/bin/update_blastdb.pl nt
fi

# Get BioSQL
if [ ! -f biosql-1.0.1.tar.gz ]
then 
    echo "=========== Download BioSQL ==========="
    wget http://biosql.org/DIST/biosql-1.0.1.tar.gz
    tar -xvf biosql-1.0.1.tar.gz
fi


if [ ! -f /etc/my.cnf ]
then
    # Could be my-(small, medium, large, or huge)
    cp /usr/local/mysql/support-files/my-large.cf /etc/my.cnf

    sed -i 'innodb_data_home_dir = /usr/local/mysql/var/' /etc/my.cnf
    sed -i 'innodb_data_file_path = ibdata1:10M:autoextend' /etc/my.cnf
    sed -i 'innodb_log_group_home_dir = /usr/local/mysql/var/' /etc/my.cnf
    sed -i 'innodb_log_arch_dir = /usr/local/mysql/var/' /etc/my.cnf
    sed -i 'set-variable = innodb_buffer_pool_size=16M' /etc/my.cnf
    sed -i 'set-variable = innodb_additional_mem_pool_size=2M' /etc/my.cnf
fi

# Create the DB
if [ ! -d /var/lib/mysql/bioseqdb ]
then 
    echo "=========== Creating Database ============"
    mysqladmin -u root create bioseqdb
fi

# Load the DB
echo "=========== Load BioSQL Database =========="
mysql -u root bioseqdb < sql/biosqldb-mysql.sql

# Update the NCBI taxonomy
if [ ! -f taxUpdated ]
then
    echo "========== Update Taxonomy ==========="
    ./scripts/load_ncbi_taxonomy.pl --dbname bioseqdb --driver mysql --dbuser root --download true
    echo "Done" >> taxUpdated
fi

# Clone the TAXAassign repo
if [ ! -d $WORKDIR/TAXAassign ]
then 
    echo "=========== Clone TAXAassign ==========="
    git clone https://github.com/umerijaz/TAXAassign $WORKDIR/TAXAassign

    # Modify the run script
    sed -i "s|\`pwd\`|${WORKDIR}/TAXAassign|" $WORKDIR/TAXAassign/TAXAassign.sh
    sed -i "s|/home/opt|${WORKDIR}/Dancbi\-blast\-2\.2\.28\+|" $WORKDIR/TAXAassign/TAXAassign.sh
    sed -i "s|/home/opt|${WORKDIR}/ncbi\-blast\-2\.2\.28\+|" $WORKDIR/TAXAassign/TAXAassign.sh
fi

