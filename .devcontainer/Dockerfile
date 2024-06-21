FROM continuumio/miniconda3

RUN conda install -y -c conda-forge nim python=3.11 liblapack jupyter numpy plotly \
    && nimble install -y arraymancer yaml
