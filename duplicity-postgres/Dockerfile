FROM konvergence/duplicity:3.0.7-r1


# mandatory args
ARG ARG_PG_RELEASE \
    ARG_RELEASE_TAG \
    ARG_RELEASE_FULL_TAG \
    ARG_KSHUTTLE_COPYRIGHT


RUN printenv ARG_PG_RELEASE \
  && printenv ARG_RELEASE_TAG \
  && printenv ARG_RELEASE_FULL_TAG \
  && printenv ARG_KSHUTTLE_COPYRIGHT 


ARG PG_VERSION=${ARG_PG_RELEASE}

RUN [ -n "${PG_VERSION}" ]

RUN echo "#### install postgresql-client" \
    && apt-get update \
    && apt-get install -y ca-certificates gnupg wget \
    && echo "deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && (wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null) \  
    && apt-get update \
    && apt-get install -y  postgresql-client-${PG_VERSION} \
&& echo "#### clean " \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/* \
     && rm -rf /tmp/*


# metadata: see https://github.com/opencontainers/image-spec
# add labels according OCI specification
LABEL org.opencontainers.image.title="duplicity postgres" \
      org.opencontainers.image.description= description="volume backup postgres export with duplicity using  swift, sftp, s3 or filesystem volume" \
      org.opencontainers.image.version="${ARG_RELEASE_FULL_TAG}" \
      org.opencontainers.image.authors="kShuttle" \
      org.opencontainers.image.licenses="${ARG_KSHUTTLE_COPYRIGHT}"