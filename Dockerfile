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
ADD https://github.com/overviewer/Minecraft-Overviewer/zipball/master overviewer.zip
RUN unzip overviewer.zip && \
    rm overviewer.zip && \
    mv overviewer* build

# Copy pillow headers
RUN mv pillow/src/libImaging/Imaging.h build/ && \
    mv pillow/src/libImaging/ImagingUtils.h build/ && \
    mv pillow/src/libImaging/ImPlatform.h build/

# Run build
RUN PIL_INCLUDE_DIR="pillow/libImaging" python build/setup.py build

##############################################################################


FROM python:3.7-stretch

LABEL maintainer="simon@marti.email"

WORKDIR /var/lib/overviewer

ARG PILLOW_VERSION=6.1.0
RUN pip install pillow==${PILLOW_VERSION} numpy

COPY --from=build ["/opt/overviewer/build/overviewer_core", "/opt/overviewer/overviewer_core/"]
COPY --from=build ["/opt/overviewer/build/overviewer.py", "/opt/overviewer/"]

ARG MINECRAFT_CLIENT_URL=https://launcher.mojang.com/v1/objects/7b07fd09d1e3aae1bc7a1304fedc73bfe5d81800/client.jar
ARG MINECRAFT_CLIENT_VERSION=1.15
ADD --chown=daemon:daemon ${MINECRAFT_CLIENT_URL} /usr/sbin/.minecraft/versions/${MINECRAFT_CLIENT_VERSION}/${MINECRAFT_CLIENT_VERSION}.jar

USER daemon
ENTRYPOINT ["/opt/overviewer/overviewer.py"]
