FROM ubuntu:16.04

# test mandatory args
ARG RELEASE_MAJOR
ARG RELEASE_MINOR
ARG RELEASE


RUN [ -n "${RELEASE}" ] && [ -n "${RELEASE_MAJOR}" ] && [ -n "${RELEASE_MINOR}" ]

# Image Label
LABEL maintainer="konvergence.com" \
      website="https://www.konvergence.com" \
      description="volume backup with duplicity using openstack swift, sftp or filesystem volume" \
      release="${RELEASE}" 
 
ENV GOPATH=/opt/go \
    DEBIAN_FRONTEND=noninteractive

ARG JOBBER_VERSION="v1.2"
ARG DUPLICITY_RELEASE=${RELEASE}

RUN apt-get update \
   && apt-get install -y --no-install-recommends apt-utils \
   && apt-get install -y  tzdata \
                          gettext-base \
                          postgresql-client-9.5 \
                          mysql-client-5.7 \
                          python-swiftclient \
                          msmtp \
                          git curl  golang-go \
                          jq \
&& echo "#### intall duplicity ppa " \
   && apt-get install -y software-properties-common python-software-properties \
   && add-apt-repository -y ppa:duplicity-team/ppa \
   && apt-get update \
   && apt-get install -y  duplicity=0.7.17-0ubuntu0ppa1353~ubuntu16.04.1 \
&& echo "#### install sftp/scp paramiko module" \
   && apt-get install -y python-paramiko python-gobject-2 \
&& echo "#### install sftp/scp pexpect module" \
   && apt-get install -y openssh-client python-pexpect \
&& echo "#### create Go home" \
    && mkdir -p /opt/go \
    && chmod 775 /opt/go \
    && chown root:staff /opt/go \
&& echo "#### install jobber" \
    && mkdir -p /opt/go/src/github.com/dshearer/jobber/ \
    && curl -sSL "https://github.com/dshearer/jobber/archive/${JOBBER_VERSION}.tar.gz" | tar -xz -C /opt/go/src/github.com/dshearer/jobber/ --strip-components=1 \
    && make --directory=/opt/go/src/github.com/dshearer/jobber \
    && useradd --home / -M --system --shell /sbin/nologin jobber_client \
    && cd /opt/go/bin/ \
    && cp jobber /usr/local/bin/. \
    && cp jobberd /usr/local/sbin/. \
    && cd /usr/local/bin \
    && chown jobber_client:root jobber \
    && chmod 4775 jobber \
    && cd /usr/local/sbin \
    && chown root:root jobberd \
    && chmod 0755 jobberd  \
 && echo "#### clean " \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/* \
     && rm -rf /tmp/*



# Add Tini
ARG TINI_VERSION="v0.16.1"
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini


# Add scripts
COPY assets/scripts/ /bin/
RUN chmod +x /bin/*.sh


# template of msmtprc config
COPY assets/msmtprc/ /usr/share/msmtprc/


# Readme and changelog
##COPY releases/${RELEASE}/USAGE.md  releases/${RELEASE}/CHANGELOG.md /
COPY USAGE.md  CHANGELOG.md /




ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RELEASE=${RELEASE} \
    TZ=Europe/Paris \
    DATA_FOLDER=/data \
    EXCLUDE_PATHS="" \
    VERBOSE=yes \
    VERBOSE_PROGRESS=yes \
    CLEAN_BEFORE_RESTORE=no \
    DB_TYPE=none \
    DB_DUMP_FILE=dumpall.out \
    OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    OS_TENANT_ID=yourTenantID \
    OS_TENANT_NAME=yourTenantName \
    OS_USERNAME=yourUserName \
    OS_PASSWORD=yourUserPassword \
    BACKUP_VOLUME_SIZE=256 \
    DAILY_JOB_HOUR="00 00 02" \
    DAILY_BACKUP_FULL_DAY=0 \
    DAILY_BACKUP_MAX_WEEK=5 \
    DAILY_BACKUP_PREFIX=backup \
    DAILY_OS_REGION_NAME=GRA3 \
    MONTHLY_BACKUP_DAY=1 \
    MONTHLY_BACKUP_PREFIX=archive \
    MONTHLY_BACKUP_MAX_MONTH=12 \
    MONTHLY_OS_REGION_NAME=SBG3 \
    SFTP_MODULE=pexpect+sftp

##    PASSPHRASE=YourSuperPassPhrase \
##    DAILY_BACKUP_MAX_FULL_WITH_INCR=0 \
##    DAILY_BACKUP_MAX_FULL=0 \
##    MONTHLY_BACKUP_MAX_FULL_WITH_INCR=0 \
##    MONTHLY_BACKUP_MAX_FULL=0 \
##    DAILY_FILESYSTEM_CONTAINER="/backup" \
##    DAILY_SWIFT_CONTAINER="my-object-storage-gra3" \
##    MONTHLY_FILESYSTEM_CONTAINER="/backup" \
##    MONTHLY_SWIFT_CONTAINER="my-archive-storage-gra3"


# Metadata
VOLUME [ "${DATA_FOLDER}" ]


# Entrypoint and CMD
ENTRYPOINT ["/tini", "--", "bash", "/bin/entrypoint.sh" ]
CMD ["--help"]

