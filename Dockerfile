FROM    phusion/baseimage
LABEL   maintainer="Justin Payne <justin.payne@fda.hhs.gov"



ARG     KRAKEN_DB_URL=https://ccb.jhu.edu/software/kraken/dl/minikraken.tgz

ENV     KRAKEN_DB_PATH=/minikraken

RUN     useradd --system -s /sbin/nologin nullarbor
WORKDIR /home/nullarbor

RUN     apt-get -y update && apt-get -y install                               \
            linuxbrew-wrapper                                                 \
            curl                                                              \
            perl                                                              \
            git                                                               \
            build-essential                                                 &&\
        apt-get purge --auto-remove -q -y                                   &&\
        chown nullarbor /home/nullarbor

USER    nullarbor
ENV     PATH="/home/nullarbor/.linuxbrew/bin:$PATH"

RUN     cpan -i                                                               \
            Bio::Perl                                                         \
            Moo                                                               \
            YAML::Tiny                                                        \
            SVG                                                               \
            JSON                                                              \
            XML::Simple                                                       \
            List::MoreUtils                                                   \
            File::Slurp                                                     &&\
        brew doctor                                                         &&\
        echo $(brew update || brew update)                                  &&\
        brew tap homebrew/science                                           &&\
        brew tap tseemann/bioinformatics-linux                              &&\
        brew install nullarbor --HEAD

RUN     curl -fsSL KRAKEN_DB_URL | tar xzvf $KRAKEN_DB_PATH

ENTRYPOINT [ "nullarbor.pl" ]