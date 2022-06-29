# docker build . --build-arg VULTR_API_KEY=xxx -t ubuntu-sme
ARG VULTR_API_KEY=xxx

FROM ubuntu

ENV VULTR_API_KEY="${VULTR_API_KEY}"
RUN apt -y update && apt -y install jq 
#RUN ./install_infra_vultr.sh "CONSOLE01"
COPY config/* ~/.ssh/
