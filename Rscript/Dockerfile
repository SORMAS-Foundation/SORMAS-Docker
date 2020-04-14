FROM hzibraunschweig/sormas-payara:5.192
ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update \
  && apt-get install -y software-properties-common \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
  && add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install r-base libpq-dev gcc build-essential gfortran libblas-dev liblapack-dev --no-install-recommends\
  && apt-get clean

RUN Rscript -e 'install.packages(c("epicontacts", "outbreaks", "RPostgreSQL", "GGally", "network", "sna", "visNetwork", "dplyr"))'
