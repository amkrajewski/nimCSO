FROM continuumio/miniconda3

RUN apt-get update \
    && apt-get install -y gcc \
    && conda install -y -c conda-forge nim \
    && conda install -y python=3.11 liblapack jupyter numpy plotly \
    && nimble install -y arraymancer yaml