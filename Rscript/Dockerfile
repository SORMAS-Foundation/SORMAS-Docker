FROM hzibraunschweig/sormas-payara:5.2021.10
ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update \
  && apt-get install -y software-properties-common \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
  && add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install r-base libpq-dev gcc build-essential gfortran libblas-dev liblapack-dev --no-install-recommends\
  && apt-get clean

RUN R -e "install.packages('epicontacts', version='1.1.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('outbreaks', version='1.5.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('RPostgreSQL', version='0.6-2', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('GGally', version='1.5.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('network', version='1.16.0', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('sna', version='2.5', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('visNetwork', version='2.0.9', repos='http://cran.rstudio.com/')"
RUN R -e "install.packages('dplyr', version='0.8.5', repos='http://cran.rstudio.com/')"
