FROM python:3.7-stretch AS build

WORKDIR /opt/overviewer/

# Install Python headers
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Install numpy
RUN pip install numpy

# Install pillow
ARG PILLOW_VERSION=6.1.0
RUN pip install pillow==${PILLOW_VERSION}

# Download pillow headers
ADD https://github.com/python-pillow/Pillow/archive/${PILLOW_VERSION}.zip pillow.zip
RUN unzip pillow.zip && \
    rm pillow.zip && \
    mv Pillow* pillow

# Download overviewer sources
ADD https://github.com/irath96/Minecraft-Overviewer/zipball/block-model overviewer.zip
RUN unzip overviewer.zip && \
    rm overviewer.zip && \
    mv *erviewer* build

# Copy pillow headers
RUN mv pillow/src/libImaging/Imaging.h build/ && \
    mv pillow/src/libImaging/ImagingUtils.h build/ && \
    mv pillow/src/libImaging/ImPlatform.h build/

# Run build
RUN PIL_INCLUDE_DIR="pillow/libImaging" python build/setup.py build


##############################################################################

FROM dwdraju/alpine-curl-jq AS minecraft

RUN VERSION=$(curl --silent --fail https://launchermeta.mojang.com/mc/game/version_manifest.json | jq --raw-output '.latest.release') && \
    MANIFEST_URL=$(curl --silent --fail https://launchermeta.mojang.com/mc/game/version_manifest.json | jq --raw-output '.latest.release as $version | .versions | map(select(.id == $version))[0].url') && \
    CLIENT_URL=$(curl --silent --fail "$MANIFEST_URL" | jq --raw-output .downloads.client.url) && \
    mkdir -p "/.minecraft/$VERSION" && \
    curl --silent --fail --output "/.minecraft/$VERSION/$VERSION.jar" "$CLIENT_URL"


##############################################################################


FROM python:3.7-stretch

LABEL maintainer="simon@marti.email"

WORKDIR /var/lib/overviewer

ARG PILLOW_VERSION=6.1.0
RUN pip install pillow==${PILLOW_VERSION} numpy

COPY --from=build ["/opt/overviewer/build/overviewer_core", "/opt/overviewer/overviewer_core/"]
COPY --from=build ["/opt/overviewer/build/overviewer.py", "/opt/overviewer/"]

COPY --chown=daemon:daemon --from=minecraft ["/.minecraft", "/usr/sbin/.minecraft/versions"]

USER daemon
ENTRYPOINT ["/opt/overviewer/overviewer.py"]

