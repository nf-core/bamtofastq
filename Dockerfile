FROM nfcore/base:1.7
LABEL authors="Friederike Hanssen" \
      description="Docker image containing all requirements for qbic-pipelines/bamtofastq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/qbic-pipelines-bamtofastq-1.0.0/bin:$PATH
