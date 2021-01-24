FROM linuxbrew/brew
LABEL maintainer="Qiang Wang <wang-q@outlook.com>"

# Build
# docker build -t fasops .

# Run
# docker run --rm fasops fasops help

# Github actions
# https://docs.docker.com/ci-cd/github-actions/

RUN true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        muscle \
        samtools \
        poa

RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install perl \
 && rm -fr $(brew --cache)/* \
 && curl -L https://cpanmin.us | perl - App::cpanminus \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew

# Change this when Perl updated
ENV PATH=/home/linuxbrew/.linuxbrew/Cellar/perl/5.32.0/bin:$PATH

WORKDIR /home/linuxbrew/App-Fasops
ADD . .

RUN true \
 && cpanm -nq --installdeps --with-develop . \
 && perl Build.PL \
 && ./Build build \
 && ./Build test \
 && ./Build install \
 && ./Build clean

WORKDIR /root

RUN true \
 && rm -fr /home/linuxbrew/App-Fasops
