# Use the official Python 3.11 slim image with Bullseye as the base image
FROM python:3.11-slim-bullseye

# Remove CUDA stubs to avoid potential conflicts or issues
RUN rm -rf /usr/local/cuda/lib64/stubs

# Copy the requirements.txt file into the root directory of the container
COPY requirements.txt /

# Install the Python dependencies specified in requirements.txt with an extra index URL for PyTorch wheels
RUN pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu118

# Set the working directory to /home/huggingface
WORKDIR /home/huggingface

# Set an environment variable to indicate the use of PyTorch
ENV USE_TORCH=1

# Create necessary directories for Huggingface cache, input, and output
RUN mkdir -p /home/huggingface/.cache/huggingface \
  && mkdir -p /home/huggingface/input \
  && mkdir -p /home/huggingface/output

# Copy the docker-entrypoint.py script to /usr/local/bin
COPY docker-entrypoint.py /usr/local/bin

# Copy the token.txt file to the working directory
COPY token.txt /home/huggingface

# Keep the container running by tailing /dev/null
ENTRYPOINT ["tail", "-f", "/dev/null"]
