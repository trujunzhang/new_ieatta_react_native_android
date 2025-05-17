FROM ubuntu:22.04

LABEL Description="This image provides a base Android development environment for React Native, and may be used to run tests."

ENV DEBIAN_FRONTEND=noninteractive




# RVM version to install
ARG RVM_VERSION=3.3.4
ENV RVM_VERSION=${RVM_VERSION}

# RMV user to create
# Optional: child images can change to this user, or add 'rvm' group to other user
ARG RVM_USER=rvm
ENV RVM_USER=${RVM_USER}

# Install RVM dependencies
RUN sed -i 's/^mesg n/tty -s \&\& mesg n/g' ~/.profile \
 && sed -i 's~http://archive\(\.ubuntu\.com\)/ubuntu/~mirror://mirrors\1/mirrors.txt~g' /etc/apt/sources.list \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends \
       ca-certificates \
 && apt-get install -qy --no-install-recommends \
       curl \
       dirmngr \
       git \
       gnupg2 \
 && rm -rf /var/lib/apt/lists/*

# Install + verify RVM with gpg (https://rvm.io/rvm/security)
RUN mkdir ~/.gnupg \
 && chmod 700 ~/.gnupg \
 && echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf \
 && gpg2 --quiet --no-tty --keyserver hkp://pool.sks-keyservers.net \
         --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
                     7D2BAF1CF37B13E2069D6956105BD0E739499BDB \
 && ( echo 409B6B1796C275462A1703113804BB82D39DC0E3:6: | gpg2 --import-ownertrust ) \
 && ( echo 7D2BAF1CF37B13E2069D6956105BD0E739499BDB:6: | gpg2 --import-ownertrust ) \
 && curl -sSL https://raw.githubusercontent.com/rvm/rvm/${RVM_VERSION}/binscripts/rvm-installer -o rvm-installer \
 && curl -sSL https://raw.githubusercontent.com/rvm/rvm/${RVM_VERSION}/binscripts/rvm-installer.asc -o rvm-installer.asc \
 && gpg2 --verify rvm-installer.asc rvm-installer \
 && bash rvm-installer \
 && rm rvm-installer \
 && echo "rvm_autoupdate_flag=2" >> /etc/rvmrc \
 && echo "rvm_silence_path_mismatch_check_flag=1" >> /etc/rvmrc \
 && echo "install: --no-document" > /etc/gemrc \
 && useradd -m --no-log-init -r -g rvm ${RVM_USER}

# Switch to a bash login shell to allow simple 'rvm' in RUN commands
SHELL ["/bin/bash", "-l", "-c"]

# Optional: child images can set Ruby versions to install (whitespace-separated)
ONBUILD ARG RVM_RUBY_VERSIONS

# Optional: child images can set default Ruby version (default is first version)
ONBUILD ARG RVM_RUBY_DEFAULT

# Child image runs this only if RVM_RUBY_VERSIONS is defined as ARG before the FROM line
ONBUILD RUN if [ ! -z "${RVM_RUBY_VERSIONS}" ]; then \
              for v in $( echo ${RVM_RUBY_VERSIONS} | sed -E 's/[[:space:]]+/\n/g' ); do \
                echo "== docker-rvm: Installing ${v} ==" \
                && rvm install ${v}; \
              done \
              && echo "== docker-rvm: Setting default ${RVM_RUBY_DEFAULT} ==" \
              && rvm use --default ${RVM_RUBY_DEFAULT:-${RVM_RUBY_VERSIONS/[[:space:]]*/}} \
              && rvm cleanup all \
              && rm -rf /var/lib/apt/lists/*; \
            fi







# set default build arguments
# https://developer.android.com/studio#command-tools
ARG SDK_VERSION=commandlinetools-linux-11076708_latest.zip
ARG ANDROID_BUILD_VERSION=35
ARG ANDROID_TOOLS_VERSION=35.0.0
ARG NDK_VERSION=27.1.12297006
ARG NODE_VERSION=20.18.1
ARG WATCHMAN_VERSION=4.9.0
ARG CMAKE_VERSION=3.30.5

# set default environment variables, please don't remove old env for compatibilty issue
ENV ADB_INSTALL_TIMEOUT=10
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/$NDK_VERSION

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV CMAKE_BIN_PATH=${ANDROID_HOME}/cmake/$CMAKE_VERSION/bin

ENV PATH=${CMAKE_BIN_PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${PATH}

# Install system dependencies
RUN apt update -qq && apt install -qq -y --no-install-recommends \
        apt-transport-https \
        curl \
        file \
        gcc \
        git \
        g++ \
        gnupg2 \
        libc++1-11 \
        libgl1 \
        libtcmalloc-minimal4 \
        make \
        openjdk-17-jdk-headless \
        openssh-client \
        patch \
        python3 \
        python3-distutils \
        rsync \
        # ruby \
        # ruby-dev \
        tzdata \
        unzip \
        sudo \
        ninja-build \
        zip \
        ccache \
        # Dev libraries requested by Hermes
        libicu-dev \
        # Dev dependencies required by linters
        jq \
        shellcheck \
    # && gem install bundler \
    && rm -rf /var/lib/apt/lists/*;

# install nodejs using n
RUN curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n \
    && bash n $NODE_VERSION \
    && rm n \
    && npm install -g n \
    && npm install -g yarn

# Full reference at https://dl.google.com/android/repository/repository2-1.xml
# download and unpack android
RUN curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o /tmp/sdk.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && unzip -q -d ${ANDROID_HOME}/cmdline-tools /tmp/sdk.zip \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/sdk.zip \
    && yes | sdkmanager --licenses \
    && yes | sdkmanager "platform-tools" \
        "platforms;android-$ANDROID_BUILD_VERSION" \
        "build-tools;$ANDROID_TOOLS_VERSION" \
        "cmake;$CMAKE_VERSION" \
        "ndk;$NDK_VERSION" \
    && rm -rf ${ANDROID_HOME}/.android \
    && chmod 777 -R /opt/android

# Disable git safe directory check as this is causing GHA to fail on GH Runners
RUN git config --global --add safe.directory '*'

ENV DEBIAN_FRONTEND=noninteractive

# set default build arguments
# https://developer.android.com/studio#command-tools
ARG SDK_VERSION=commandlinetools-linux-11076708_latest.zip
ARG ANDROID_BUILD_VERSION=35
ARG ANDROID_TOOLS_VERSION=35.0.0
ARG NDK_VERSION=27.1.12297006
ARG NODE_VERSION=20.18.1
ARG WATCHMAN_VERSION=4.9.0
ARG CMAKE_VERSION=3.30.5

# set default environment variables, please don't remove old env for compatibilty issue
ENV ADB_INSTALL_TIMEOUT=10
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/$NDK_VERSION

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV CMAKE_BIN_PATH=${ANDROID_HOME}/cmake/$CMAKE_VERSION/bin

ENV PATH=${CMAKE_BIN_PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${PATH}

# Install system dependencies
RUN apt update -qq && apt install -qq -y --no-install-recommends \
        apt-transport-https \
        curl \
        file \
        gcc \
        git \
        g++ \
        gnupg2 \
        libc++1-11 \
        libgl1 \
        libtcmalloc-minimal4 \
        make \
        openjdk-17-jdk-headless \
        openssh-client \
        patch \
        python3 \
        python3-distutils \
        rsync \
        tzdata \
        unzip \
        sudo \
        ninja-build \
        zip \
        ccache \
        # Dev libraries requested by Hermes
        libicu-dev \
        # Dev dependencies required by linters
        jq \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*;

# install nodejs using n
RUN curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n \
    && bash n $NODE_VERSION \
    && rm n \
    && npm install -g n \
    && npm install -g yarn

# Full reference at https://dl.google.com/android/repository/repository2-1.xml
# download and unpack android
RUN curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o /tmp/sdk.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && unzip -q -d ${ANDROID_HOME}/cmdline-tools /tmp/sdk.zip \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/sdk.zip \
    && yes | sdkmanager --licenses \
    && yes | sdkmanager "platform-tools" \
        "platforms;android-$ANDROID_BUILD_VERSION" \
        "build-tools;$ANDROID_TOOLS_VERSION" \
        "cmake;$CMAKE_VERSION" \
        "ndk;$NDK_VERSION" \
    && rm -rf ${ANDROID_HOME}/.android \
    && chmod 777 -R /opt/android

# Disable git safe directory check as this is causing GHA to fail on GH Runners
RUN git config --global --add safe.directory '*'



CMD ["/bin/bash", "-l"]
