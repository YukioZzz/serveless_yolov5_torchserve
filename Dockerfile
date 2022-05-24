## https://github.com/pytorch/serve/tree/master/docker
FROM pytorch/torchserve:latest-gpu
USER root
RUN apt-get update
RUN apt-get install -y libgl1-mesa-glx libglib2.0-0 python3-distutils curl git vim
RUN echo "Pulling watchdog binary from Github." \
    && curl -sSLf https://github.com/openfaas-incubator/of-watchdog/releases/download/0.4.6/of-watchdog > /usr/bin/fwatchdog \
    && chmod +x /usr/bin/fwatchdog
COPY ./ressources/ /home/model-server/ressources/
RUN chmod -R a+rw /home/model-server/
USER model-server
RUN pip3 install --upgrade pip
RUN pip install torch-model-archiver opencv-python && pip install -r /home/model-server/ressources/yolov5/requirements.txt
ENV PYTHONPATH "${PYTHONPATH}:/home/model-server/ressources/yolov5/"

RUN cd /home/model-server && git clone https://github.com/ultralytics/yolov5  && cd yolov5 && python /home/model-server/yolov5/export.py --device cpu --weights /home/model-server/ressources/weights.pt --img 640 --batch 1
COPY torchserve_handler.py /home/model-server/ressources/torchserve_handler.py
RUN torch-model-archiver --model-name yolov5 \
--version 1.0 --serialized-file /home/model-server/ressources/weights.torchscript \
--handler /home/model-server/ressources/torchserve_handler.py \
--extra-files /home/model-server/ressources/index_to_name.json,/home/model-server/ressources/torchserve_handler.py
RUN mv yolov5.mar model-store/yolov5.mar
COPY config.properties config.properties

#CMD [ "torchserve", "--start", "--model-store", "model-store", "--models", "yolov5=yolov5.mar" ]
ENV fprocess="torchserve --start --model-store model-store --models yolov5=yolov5.mar"
ENV write_debug="true"
ENV cgi_headers="true"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:9090"

#RUN touch /tmp/.lock
HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1
ENTRYPOINT []
CMD [ "fwatchdog" ]
