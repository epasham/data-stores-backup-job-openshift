#FROM openshift/origin:v1.4.1
#FROM openshift/origin-base
FROM registry.access.redhat.com/rhel7


MAINTAINER <kanedafromparis@gmail.com>

#ARG  YUM_UPDATE=1 
ARG  MYSQL_BACKUP=1 
ARG  MONGODB_BACKUP=1
ARG  POSTGRES_BACKUP=1
ARG  MYSQL_VERSION=57
ARG  MONGODB_VERSION=32
ARG  POSTGRES_VERSION=95


ENV  DEFAULT=MYSQL \
      MYSQLDUMP_OPTIONS=" --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384 " \
      MYSQLDUMP_DATABASE=" --all-databases " \
      MYSQL_HOST="mysql" \
      MYSQL_PORT="3306" \
      MYSQL_USER=""  \
      MYSQL_PASSWORD=""  \
      POSTGRES_OPTIONS=" --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384 " \
      POSTGRES_DATABASE=" --all-databases " \
      POSTGRES_HOST="postgres" \
      POSTGRES_PORT="3306" \
      POSTGRES_USER=""   \
      POSTGRES_PASSWORD=""  


LABEL io.k8s.display-name="OpenShift backup cron job" \
      io.k8s.description="This a utility image for OpenShift It should be use in order to backup / restore data from the project to various store S3, Azure, others..."

COPY ./src/main/repo.d/ /etc/yum.repos.d/

# RUN if [ $YUM_UPDATE -eq 1 ]; then \
#       echo " yum update " && yum --setopt=tsflags=nodocs clean all && yum --setopt=tsflags=nodocs upgrade -y ; \
#     else \    
#       echo " no yum update "; \
#    fi;

RUN echo "Installing required packages ..." \
 && INSTALL_PKGS=" s3cmd gnupg2 tar rsync mailx jq " \
 && if [ $MYSQL_VERSION -eq 57 ]; then \
        echo ""; \
    fi \ 
 && if [ $MYSQL_BACKUP -eq 1 ]; then \
      INSTALL_PKGS=$INSTALL_PKGS+" mysql " ; \ 
    else  \
      echo " no MYSQL_BACKUP ";  \
    fi \    
 && if [ $MONGODB_VERSION -eq 34 ]; then  \
      yum-config-manager --enable mongodb-org-3.4;  \
    fi \  
 && if [ $MONGODB_VERSION -eq 32 ]; then  \
      yum-config-manager --enable mongodb-org-3.2;  \
    fi \ 
 && if [ $MONGODB_BACKUP -eq 1 ]; then \
       INSTALL_PKGS=$INSTALL_PKGS+" mongodb-org-shell mongodb-org-tools " ;  \
    else  \
      echo " no MONGODB_BACKUP ";  \
    fi \ 
 && if [ $POSTGRES_VERSION -eq 95 ]; then \
      yum-config-manager --enable pgdg95;  \
    fi \ 
 && if [ $MONGODB_BACKUP -eq 1 ]; then \
      INSTALL_PKGS=$INSTALL_PKGS+" postgresql95 " ;  \
    else  \
      echo " no POSTGRES_BACKUP ";  \
    fi \
 && getent ahostsv4 mirrorlist.centos.org \
 && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
 && (sed -i 's/enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf || true ) \                                                         
 && sed -i 's/^#baseurl/baseurl/g' /etc/yum.repos.d/*.repo \                                                                            
 && sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/*.repo \                                                                      
 && sed -i '/^metalink/d' /etc/yum.repos.d/*.repo \                                                                                     
 && sed -i 's/^baseurl=.*$/baseurl=http\:\/\/ftp\.tu\-chemnitz\.de\/pub\/linux\/fedora\-epel\/7\/x86_64/g' /etc/yum.repos.d/epel.repo \ 
 && yum -y upgrade \
 && yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS \
 && yum clean all ;   
    
RUN echo "Setup of the default user ..." \
 && useradd -u 1001 -r -g 0 -d /opt/data -s /sbin/nologin -c "Default Application User" default \                  
 && mkdir -p /opt/data/bin \
 && mkdir -p /opt/data/source \
 && chown -R 1001:0 /opt
 
COPY ./src/main/scripts/ /opt/data/bin

RUN chmod ag+x /opt/data/bin/*.sh \
    && chmod g+wX /opt/data

WORKDIR /opt/data

USER 1001   

ENV HOME /opt/data

ENTRYPOINT ["/opt/data/bin/entrypoint.sh"]

CMD ["/opt/data/bin/run.sh"]
