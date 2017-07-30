FROM centos:latest

MAINTAINER "John Bryan Sazon"

# Swarm Env Variables (defaults)
ENV JENKINS_CONTEXT_PATH=/jenkins
ENV SWARM_MASTER=http://jenkins:8080/${JENKINS_CONTEXT_PATH}
ENV SWARM_USER=jenkins
ENV SWARM_PASSWORD=jenkins

# Slave Env Variables
ENV SLAVE_NAME="Swarm_Slave"
ENV SLAVE_LABELS="docker aws ldap ansible nodejs ruby"
ENV SLAVE_MODE="exclusive"
ENV SLAVE_EXECUTORS=1
ENV SLAVE_DESCRIPTION="Core Jenkins Slave"

# Build Variables
ARG JAVA_PKG_DOWNLOAD="https://s3-eu-west-1.amazonaws.com/pdc-oracle-fmw/installers/jdk-8u144-linux-x64.tar.gz"
ARG JAVA_PKG="jdk-8u*-linux-x64.tar.gz"
ARG NODEJS_PKG_DOWNLOAD="https://nodejs.org/dist/v7.10.0/node-v7.10.0-linux-x64.tar.gz"
ARG RUBY_PKG_DOWNLOAD="ftp://195.220.108.108/linux/centos/7.3.1611/os/x86_64/Packages/ruby-devel-2.0.0.648-29.el7.x86_64.rpm"
ARG DOCKER_VERSION=1.12.3
ARG SWARM_CLIENT_VERSION=2.2

# Pre-requisites
RUN yum -y install epel-release
RUN yum install -y which \
    git \
    wget \
    tar \
    zip \
    unzip \
    openldap-clients \
    openssl \
    python-pip \
    libxslt && \
    yum clean all 

RUN pip install awscli==1.10.19

# Create slave user
RUN useradd -u 1001 -r -m -d /opt/jenkins-slave -c "Jenkins Slave" jenkins-slave && \
    groupadd -g 1010 docker && \
    gpasswd -a jenkins-slave docker

# Install docker
RUN curl -s -o /usr/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION} && \
    chmod +x /usr/bin/docker

# Install Jenkins Swarm Client
RUN curl -s -o /bin/swarm-client.jar -k https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${SWARM_CLIENT_VERSION}/swarm-client-${SWARM_CLIENT_VERSION}-jar-with-dependencies.jar

# Install EPEL release
RUN curl -O https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    rpm -Uvh $(ls | grep epel-release*rpm) && rm -f $(ls | grep epel-release*rpm) && \
    rm -f epel*.rpm

# Set binaries home
ENV JAVA_HOME=/usr/java/default \
    NODEJS_HOME=/opt/nodejs \
    PATH=$PATH:/usr/java/default/bin:/opt/nodejs/bin

# Install Java
RUN wget $JAVA_PKG_DOWNLOAD && \
    mkdir -p /usr/java/ && \
    tar -xzf $JAVA_PKG -C /usr/java/ && \
    mv $(ls -1 -d /usr/java/*) $JAVA_HOME && \
    rm -f $JAVA_PKG

# Install Ruby Development Packages
RUN yum -y install gcc ruby-2.0.0.648-29.el7

RUN wget ${RUBY_PKG_DOWNLOAD} && \
    rpm -Uvh $(ls | grep ruby-devel) && \
    rm -f ruby-devel*.rpm

# Install NodeJS
RUN cd /opt && \
    wget ${NODEJS_PKG_DOWNLOAD} && \
    tar xzvf node-v* && \
    rm -fr *.tar.gz && \
    mv $(ls | grep node) nodejs

# Install Ruby Gems
RUN gem install sass compass --no-ri --no-rdoc

# Install NodeJS Packages
RUN npm install -g gulp-cli set-version

# Install JQ CLI
RUN curl -fsSL -o /usr/bin/jq "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" && \
    chmod +x /usr/bin/jq

# Install Ansible
RUN yum -y install ansible && \
    yum -y install python-boto && \
    sed -i 's/#host_key_checking/host_key_checking/g' /etc/ansible/ansible.cfg && \
    ansible --version

# Install OpenShift CLI Tool
RUN curl -fsSL https://github.com/openshift/origin/releases/download/v1.5.1/openshift-origin-client-tools-v1.5.1-7b451fc-linux-64bit.tar.gz | tar xzf - -C /usr/bin/ --strip-components 1 openshift-origin-client-tools-v1.5.1-7b451fc-linux-64bit/oc

# Clean up and change ownership
RUN chown -R 755 /opt/jenkins-slave && \
    chown -R jenkins-slave:0 /opt/jenkins-slave && \
    rm -rf /tmp/* && \
    yum clean all

USER 1001

ADD resources/* /opt/jenkins-slave/

CMD ["/opt/jenkins-slave/container-cmd"]
