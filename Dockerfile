FROM homebrew/brew
LABEL maintainer="Qiang Wang <wang-q@outlook.com>"

# Build
# docker build -t wangq/fasops .

# Run
# docker run --rm wangq/fasops fasops help

# Github actions
# https://docs.docker.com/ci-cd/github-actions/

RUN true \
 && sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends \
        muscle \
        samtools \
        poa

RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install perl \
 && curl -L https://cpanmin.us | perl - App::cpanminus \
 && rm -fr $(brew --cache)/* \
 && rm -fr $HOME/.cpan \
 && rm -fr $HOME/.gem \
 && rm -fr $HOME/.cpanm

# Change this when Perl updated
ENV PATH=/home/linuxbrew/.linuxbrew/Cellar/perl/5.34.0/bin:$PATH

WORKDIR /home/linuxbrew/App-Fasops
ADD . .

RUN true \
 && cpanm -nq --installdeps --with-develop . \
 && perl Build.PL \
 && ./Build build \
 && ./Build test \
 && ./Build install \
 && ./Build clean \
 && rm -fr $HOME/.cpanm
