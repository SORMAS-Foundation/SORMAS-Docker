FROM hzibraunschweig/sormas-payara:5.2022.5
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
  && apt install -y gpg-agent 

RUN apt update -qq \
  && apt install -y --no-install-recommends software-properties-common dirmngr \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
  && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
  && add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install r-base libpq-dev gcc build-essential gfortran libblas-dev liblapack-dev libxml2-dev libglpk-dev --no-install-recommends\
  && apt-get clean

RUN R -e "install.packages('epicontacts', version='1.1.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('outbreaks', version='1.5.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('RPostgreSQL', version='0.6-2', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('GGally', version='1.5.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('network', version='1.16.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('sna', version='2.5', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('visNetwork', version='2.0.9', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('dplyr', version='0.8.5', repos='http://cran.rstudio.com/')"
